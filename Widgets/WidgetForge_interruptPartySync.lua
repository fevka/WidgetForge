-- =========================================================================
--  WidgetForge - Interrupt Party Sync Module
--  [WoW 12 Compliant - Midnight API] - Persistent Bars Edition
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
if not _G.WidgetForge.InterruptSync then _G.WidgetForge.InterruptSync = {} end

local InterruptSync = _G.WidgetForge.InterruptSync
addonTable.InterruptSync = InterruptSync

InterruptSync.Instances = {}
InterruptSync.commPrefix = "WF_INT_SYNC"
InterruptSync.DebugMode = false
local DEFAULT_INTERRUPT_COOLDOWN = 15
local GCD_SPELL_ID = 61304
local GCD_EPSILON = 0.15
local QUICK_RESAMPLE_DELAY = 0.12
local MIN_VALID_INTERRUPT_COOLDOWN = 1.0
local SUCCESS_CDR_WINDOW = 2.0
local SUCCESS_MATCH_WINDOW = 1.0
local BASE_DISPATCH_DELAY = 0.22
local DK_MIND_FREEZE_SPELL_ID = 47528
local DK_SUCCESS_CDR_SECONDS = 3
local DK_COLDTHIRST_TALENT_NAME = "Coldthirst"
local DK_COLDTHIRST_TALENT_ID = 378848

-- ============================================================================
-- 1. INTERRUPT DATA (Dynamic CD Detection - Synced with TargetCastbar.lua)
-- ============================================================================
local INTERRUPT_DATA = {
    WARRIOR = { DEFAULT = {ids = {6552}, spellName = "Pummel", names = {"Pummel"}} },
    ROGUE   = { DEFAULT = {ids = {1766}, spellName = "Kick", names = {"Kick"}} },
    MAGE    = { DEFAULT = {ids = {2139}, spellName = "Counterspell", names = {"Counterspell"}} },
    DEATHKNIGHT = { DEFAULT = {ids = {47528}, spellName = "Mind Freeze", names = {"Mind Freeze"}} },
    PALADIN = { DEFAULT = {ids = {96231}, spellName = "Rebuke", names = {"Rebuke"}} },
    MONK    = { DEFAULT = {ids = {116705}, spellName = "Spear Hand Strike", names = {"Spear Hand Strike"}} },
    DEMONHUNTER = { DEFAULT = {ids = {183752}, spellName = "Consume Magic", names = {"Consume Magic"}} },
    EVOKER  = { DEFAULT = {ids = {351338}, spellName = "Quell", names = {"Quell"}} },
    WARLOCK = { DEFAULT = {ids = {119914, 132409, 19647}, spellName = "Spell Lock", names = {"Spell Lock", "Command Demon"}} },
    SHAMAN  = { DEFAULT = {ids = {57994}, spellName = "Wind Shear", names = {"Wind Shear"}} },
    PRIEST  = { DEFAULT = {ids = {0}}, [3] = {ids = {15487}, spellName = "Silence", names = {"Silence"}} },
    HUNTER  = { DEFAULT = {ids = {147362}, spellName = "Counter Shot", names = {"Counter Shot", "Muzzle"}}, [3] = {ids = {187707}, spellName = "Muzzle", names = {"Muzzle"}} },
    DRUID   = { DEFAULT = {ids = {106839}, spellName = "Skull Bash", names = {"Skull Bash"}}, [1] = {ids = {78675}, spellName = "Solar Beam", names = {"Solar Beam"}} },
}

-- Seeded from SpellDatabase.txt (type="INTERRUPT") and kept as static fallback.
local INTERRUPT_COOLDOWN_FALLBACK = {
    [6552] = 15,    -- Pummel
    [1766] = 15,    -- Kick
    [2139] = 24,    -- Counterspell
    [47528] = 15,   -- Mind Freeze
    [96231] = 15,   -- Rebuke
    [116705] = 15,  -- Spear Hand Strike
    [183752] = 15,  -- Disrupt
    [351338] = 20,  -- Quell
    [57994] = 12,   -- Wind Shear
    [15487] = 45,   -- Silence
    [147362] = 24,  -- Counter Shot
    [187707] = 15,  -- Muzzle
    [106839] = 15,  -- Skull Bash
    [78675] = 60,   -- Solar Beam
    [119914] = 24,  -- Spell Lock
    [132409] = 24,  -- Spell Lock (Observer)
    [19647] = 24,   -- Spell Lock (Felhunter)
}

local STATIC_INTERRUPT_COOLDOWN_FALLBACK = {}
for sid, dur in pairs(INTERRUPT_COOLDOWN_FALLBACK) do
    STATIC_INTERRUPT_COOLDOWN_FALLBACK[sid] = dur
end

local INTERRUPT_NAME_COOLDOWN_FALLBACK = {}

local function RegisterInterruptNameFallbackFromID(id, duration)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        INTERRUPT_NAME_COOLDOWN_FALLBACK[info.name] = duration
    end
end

for spellID, duration in pairs(INTERRUPT_COOLDOWN_FALLBACK) do
    RegisterInterruptNameFallbackFromID(spellID, duration)
end

local function SafeNumber(value)
    local ok, num = pcall(function() return tonumber(value) end)
    if ok and type(num) == "number" then return num end
    return nil
end

local function SafeGreaterThan(value, threshold)
    local left = SafeNumber(value)
    if not left then return false end
    local right = SafeNumber(threshold) or 0
    local ok, result = pcall(function() return left > right end)
    return ok and result or false
end

local function RoundTo2(value)
    local n = SafeNumber(value)
    if not n then return nil end
    return math.floor(n * 100 + 0.5) / 100
end

local function DebugLog(self, msg)
    return
end

function InterruptSync:HasColdthirstTalent()
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then return false end

    local now = GetTime()
    self._coldthirstCacheAt = self._coldthirstCacheAt or 0
    self._coldthirstCacheValue = self._coldthirstCacheValue or false
    if (now - self._coldthirstCacheAt) < 0.2 then
        DebugLog(self, string.format("Coldthirst cache hit: %s age=%.3f", tostring(self._coldthirstCacheValue), now - self._coldthirstCacheAt))
        return self._coldthirstCacheValue
    end

    local known = false
    if DK_COLDTHIRST_TALENT_ID then
        if IsPlayerSpell and IsPlayerSpell(DK_COLDTHIRST_TALENT_ID) then known = true end
        if not known and IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(DK_COLDTHIRST_TALENT_ID) then known = true end
        if not known and IsSpellKnown and IsSpellKnown(DK_COLDTHIRST_TALENT_ID) then known = true end
    end

    self._coldthirstCacheAt = now
    self._coldthirstCacheValue = known
    DebugLog(self, string.format("Coldthirst check: spellID=%s active=%s", tostring(DK_COLDTHIRST_TALENT_ID), tostring(known)))
    return known
end

function InterruptSync:GetLiveRemainingCooldown(spellID)
    if not C_Spell then return nil end

    -- Preferred API for remaining cooldown in modern clients.
    if C_Spell.GetSpellCooldownDuration then
        local rem = SafeNumber(C_Spell.GetSpellCooldownDuration(spellID))
        if rem and rem > 0 then
            return rem
        end
    end

    -- Fallback for clients/builds where remaining duration API is unavailable.
    if not C_Spell.GetSpellCooldown then return nil end
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    if not cdInfo or not SafeGreaterThan(cdInfo.duration, 0) then return 0 end
    local startTime = SafeNumber(cdInfo.startTime) or 0
    local duration = SafeNumber(cdInfo.duration) or 0
    local remaining = (startTime + duration) - GetTime()
    if remaining < 0 then remaining = 0 end
    return remaining
end

function InterruptSync:EnsureRuntimeCooldownDB()
    if type(_G.WidgetForgeDB) ~= "table" then _G.WidgetForgeDB = {} end
    if type(_G.WidgetForgeDB.runtimeInterruptCooldowns) ~= "table" then
        _G.WidgetForgeDB.runtimeInterruptCooldowns = {}
    end
    return _G.WidgetForgeDB.runtimeInterruptCooldowns
end

function InterruptSync:ApplyRuntimeCooldownOverrides()
    local db = self:EnsureRuntimeCooldownDB()
    local applied = 0
    for spellIDStr, duration in pairs(db) do
        local sid = tonumber(spellIDStr)
        local dur = RoundTo2(duration)
        if sid and dur and dur >= MIN_VALID_INTERRUPT_COOLDOWN then
            local allow = true
            -- Guard against stale "remaining cooldown" samples polluting base cooldown memory.
            if sid == DK_MIND_FREEZE_SPELL_ID then
                local staticBase = STATIC_INTERRUPT_COOLDOWN_FALLBACK[sid] or 15
                if dur + 0.01 < staticBase then
                    db[spellIDStr] = nil
                    DebugLog(self, string.format("Removed invalid runtime override spell=%d duration=%.2f static=%.2f", sid, dur, staticBase))
                    allow = false
                end
            end
            if allow then
                INTERRUPT_COOLDOWN_FALLBACK[sid] = dur
                RegisterInterruptNameFallbackFromID(sid, dur)
                applied = applied + 1
            end
        end
    end
    DebugLog(self, string.format("Runtime overrides applied: %d", applied))
end

function InterruptSync:RememberObservedCooldown(spellID, duration, source)
    if not spellID then return end
    if source ~= "live" and source ~= "charges" and source ~= "base" then return end

    local dur = RoundTo2(duration)
    if not dur or dur < MIN_VALID_INTERRUPT_COOLDOWN then return end

    local sid = tonumber(spellID)
    if not sid then return end

    local prev = INTERRUPT_COOLDOWN_FALLBACK[sid]
    if prev and math.abs(prev - dur) < 0.01 then return end

    INTERRUPT_COOLDOWN_FALLBACK[sid] = dur
    RegisterInterruptNameFallbackFromID(sid, dur)

    local db = self:EnsureRuntimeCooldownDB()
    db[tostring(sid)] = dur
    DebugLog(self, string.format("Learned cooldown spell=%d old=%s new=%.2f source=%s (saved to WidgetForgeDB.runtimeInterruptCooldowns)", sid, tostring(prev), dur, tostring(source)))
end

function InterruptSync:GetCurrentGCD()
    local gcd = 1.5
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
            gcd = SafeNumber(cdInfo.duration) or gcd
        end
    end
    return gcd
end

function InterruptSync:ResolveInterruptCooldownDuration(spellID)
    if not spellID then return DEFAULT_INTERRUPT_COOLDOWN, "fallback" end

    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
            local liveDuration = SafeNumber(cdInfo.duration)
            local gcd = self:GetCurrentGCD()
            if liveDuration and SafeGreaterThan(liveDuration, gcd + GCD_EPSILON) then
                return liveDuration, "live"
            end
        end
    end

    if C_Spell and C_Spell.GetSpellCharges then
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        if chargeInfo then
            local chargeDur = chargeInfo.cooldownDuration or chargeInfo.chargeCooldownDuration
            local current = chargeInfo.currentCharges
            local maxc = chargeInfo.maxCharges
            local chargeDurNum = SafeNumber(chargeDur)
            local currentNum = SafeNumber(current)
            local maxNum = SafeNumber(maxc)
            if chargeDurNum and SafeGreaterThan(chargeDurNum, 0) then
                local ok, less = pcall(function() return currentNum and maxNum and currentNum < maxNum end)
                if ok and less then
                    return chargeDurNum, "charges"
                end
            end
        end
    end

    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local baseCooldownInfo = C_Spell.GetSpellBaseCooldown(spellID)
        local baseMs = SafeNumber(baseCooldownInfo)
        if baseMs and SafeGreaterThan(baseMs, 0) then
            local baseSec = baseMs / 1000
            local gcd = self:GetCurrentGCD()
            if SafeGreaterThan(baseSec, gcd + GCD_EPSILON) then
                return baseSec, "base"
            end
        end
    end

    local fallback = INTERRUPT_COOLDOWN_FALLBACK[spellID]
    if fallback then
        return fallback, "spell_fallback"
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        local byName = info and info.name and INTERRUPT_NAME_COOLDOWN_FALLBACK[info.name]
        if byName then
            return byName, "name_fallback"
        end
    end

    return DEFAULT_INTERRUPT_COOLDOWN, "fallback"
end

function InterruptSync:IsPartySyncEnabled()
    local elem = self.Instances[1] and self.Instances[1].elem
    return elem and elem.partySync
end

-- Player's interrupt spell IDs (loaded from player class/spec)
InterruptSync.interruptIDs = {}

function InterruptSync:LoadClassInterrupt()
    local class = select(2, UnitClass("player"))
    local data = INTERRUPT_DATA[class]
    if not data then self.interruptIDs = {}; return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex] or data.DEFAULT
    self.interruptIDs = {}
    
    if specData and specData.ids then
        -- Pass 1: Try all hardcoded IDs
        for _, id in ipairs(specData.ids) do
            if id > 0 then
                local known = IsPlayerSpell(id)
                if not known and IsSpellKnown then known = IsSpellKnown(id) end
                if not known and IsSpellKnownOrOverridesKnown then known = IsSpellKnownOrOverridesKnown(id) end
                
                if known then
                    table.insert(self.interruptIDs, id)
                end
            end
        end
        
        -- Pass 2: If we didn't find all expected spells, try name-based lookup for missing ones
        if #self.interruptIDs < #specData.ids and specData.names then
            for _, spellName in ipairs(specData.names) do
                local info = C_Spell.GetSpellInfo(spellName)
                if info and info.spellID then
                    local id = info.spellID
                    
                    -- Check if we already found this ID in Pass 1
                    local alreadyFound = false
                    for _, existingID in ipairs(self.interruptIDs) do
                        if existingID == id then alreadyFound = true break end
                    end
                    
                    if not alreadyFound then
                        local known = IsPlayerSpell(id)
                        if not known and IsSpellKnown then known = IsSpellKnown(id) end
                        if not known and IsSpellKnownOrOverridesKnown then known = IsSpellKnownOrOverridesKnown(id) end
                        
                        if known then
                            table.insert(self.interruptIDs, id)
                        end
                    end
                end
            end
        end
    end
end

InterruptSync:LoadClassInterrupt()
InterruptSync:ApplyRuntimeCooldownOverrides()

local specTrackerFrame = CreateFrame("Frame")
specTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
specTrackerFrame:SetScript("OnEvent", function(_, event)
    DebugLog(InterruptSync, "Spec tracker event: " .. tostring(event))
    InterruptSync:RefreshColdthirstState(event)
    InterruptSync:LoadClassInterrupt()
    InterruptSync:ApplyRuntimeCooldownOverrides()
    InterruptSync:RefreshPlayerInterruptCooldownCache()
end)

-- Flatten for spell ID lookup
local INTERRUPT_SPELL_DATA = {}
for class, data in pairs(INTERRUPT_DATA) do
    for specIdx, specData in pairs(data) do
        for _, id in ipairs(specData.ids) do
            INTERRUPT_SPELL_DATA[id] = specData.spellName or "Interrupt"
        end
    end
end

-- Track player's last successful interrupt for detection
InterruptSync.lastInterruptSpellID = nil
InterruptSync.lastInterruptTime = 0
InterruptSync.coldthirstEnabled = false

-- ============================================================================
-- INSTANCE & GROUP VALIDATION
-- ============================================================================

function InterruptSync:IsValidContext()
    -- Check if in instance (dungeon/mythic+ only, not raid)
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or (instanceType ~= "party" and instanceType ~= "scenario") then
        return false
    end
    
    -- Check if NOT in raid (dungeon parties only)
    if IsInRaid() then
        return false
    end
    
    return true
end

function InterruptSync:RefreshColdthirstState(reason)
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then
        self.coldthirstEnabled = false
        DebugLog(self, string.format("Coldthirst cache refresh (%s): false (not DK)", tostring(reason)))
        return
    end
    self._coldthirstCacheAt = 0
    self._coldthirstCacheValue = false
    self.coldthirstEnabled = self:HasColdthirstTalent() and true or false
    DebugLog(self, string.format("Coldthirst cache refresh (%s): %s", tostring(reason), tostring(self.coldthirstEnabled)))
end

-- ============================================================================
-- 2. EVENT HANDLING (WoW 12 COMPLIANT)
-- ============================================================================
function InterruptSync:UpdateGroupTracking()
    -- Always refresh our own spell data first
    self._coldthirstCacheAt = 0
    self._coldthirstCacheValue = false
    self:RefreshColdthirstState("UpdateGroupTracking")
    self:LoadClassInterrupt()
    self:ApplyRuntimeCooldownOverrides()
    self:RefreshPlayerInterruptCooldownCache()
    
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    self.eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    
    self.cachedIsValidContext = self:IsValidContext()
    
    self.eventFrame:RegisterEvent("CHAT_MSG_PARTY")
    self.eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    
    self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

    -- Persistent Bars: Initialize "Ready" state for all members
    for _, container in ipairs(self.Instances) do
        self:InitializeGroupBars(container)
    end
end

function InterruptSync:RefreshPlayerInterruptCooldownCache()
    if #self.interruptIDs == 0 then return end
    local gcd = self:GetCurrentGCD()
    DebugLog(self, string.format("Refresh cache: interrupts=%d gcd=%.2f", #self.interruptIDs, gcd))
    for _, spellID in ipairs(self.interruptIDs) do
        local duration, source = self:ResolveInterruptCooldownDuration(spellID)
        if duration and duration > (gcd + GCD_EPSILON) then
            DebugLog(self, string.format("Observed cooldown spell=%d duration=%.2f source=%s", spellID, duration, tostring(source)))
            self:RememberObservedCooldown(spellID, duration, source)
        end
    end
end

function InterruptSync:InitializeTargetInterruptWatcher()
    if self.targetInterruptWatcher then return end

    local f = CreateFrame("Frame")
    f.owner = self
    f.isInterrupted = false
    f.interruptTime = 0

    f:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")

    local function UpdateCastInfo(frame, event, unit)
        if unit and unit ~= "target" then return end
        local sync = frame.owner
        if not sync then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            frame.isInterrupted = false
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            frame.isInterrupted = true
            frame.interruptTime = GetTime()
            DebugLog(sync, "Target watcher detected successful interrupt event")
            sync:ReportInterruptSuccess("target", sync.lastInterruptSpellID, sync.lastInterruptCastToken)
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            -- Mirror TargetCastbar behavior: keep interrupted success state until next cast start.
            if not frame.isInterrupted then
                frame.interruptTime = 0
            end
        end
    end

    f:SetScript("OnEvent", function(frame, event, unit)
        UpdateCastInfo(frame, event, unit)
    end)

    self.targetInterruptWatcher = f
end

function InterruptSync:InitializeGroupBars(container)
    local activeNames = {}
    
    local function ShouldTrack(unit)
        local role = UnitGroupRolesAssigned(unit)
        local _, classToken = UnitClass(unit)
        if role == "HEALER" and classToken ~= "SHAMAN" then
            return false
        end
        return true
    end

    -- Add Player (only if they have an interrupt spell)
    if ShouldTrack("player") and #self.interruptIDs > 0 then
        local name = UnitName("player")
        if name then
            self:EnsureBarIsReady(container, name, select(2, UnitClass("player")))
            activeNames[name] = true
        end
    end
    
    -- Add Group
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and 40 or 4
        for i=1, num do
            local unit = prefix..i
            if UnitExists(unit) and ShouldTrack(unit) then
                local name = UnitName(unit)
                if name then
                    self:EnsureBarIsReady(container, name, select(2, UnitClass(unit)))
                    activeNames[name] = true
                end
            end
        end
    end

    -- Cleanup inactive or invalid members
    if container.bars then
        for name, bar in pairs(container.bars) do
            if not activeNames[name] then
                bar:Hide()
                container.bars[name] = nil
            end
        end
    end

    self:LayoutBars(container)
end

function InterruptSync:EnsureBarIsReady(container, name, class)
    if not name or not class then return end
    if not INTERRUPT_DATA[class] then return end
    
    if not container.bars[name] then
        local row = self:CreateBar(container, name)
        container.bars[name] = row
        -- Initial state is READY - use DEFAULT spec
        local specData = INTERRUPT_DATA[class].DEFAULT or {}
        local spellID = specData.ids and specData.ids[1] or 0
        self:SetBarReady(container, row, spellID)
    end
    
    -- Restore active cooldown from memory to survive zone/loading screens without API taint
    self.activeCooldowns = self.activeCooldowns or {}
    local mem = self.activeCooldowns[name]
    if mem and mem.endTime and mem.endTime > GetTime() then
        local bar = container.bars[name]
        -- if it's currently showing ready (no OnUpdate), restore the cooldown visually
        if bar and not bar:GetScript("OnUpdate") then
            bar.endTime = mem.endTime
            bar.duration = mem.duration
            bar.currentSpellID = mem.spellID
            
            local spellInfo = C_Spell.GetSpellInfo(mem.spellID)
            bar.icon:SetTexture(spellInfo and spellInfo.iconID or 134400)
            bar.icon:SetDesaturated(true)
            
            if spellInfo and spellInfo.name then
                bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
            else
                bar.nameText:SetText(bar.playerName or "Unknown")
            end
            
            local c = container.elem.colorOnCD or {1.0, 0.2, 0.2, 1}
            bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
            
            bar:Show()
            bar:SetScript("OnUpdate", function(f)
                local rem = f.endTime - GetTime()
                if rem <= 0 then
                    InterruptSync:SetBarReady(container, f, f.currentSpellID)
                else
                    f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
                end
            end)
        end
    end
end

if not InterruptSync.eventFrame then
    InterruptSync.eventFrame = CreateFrame("Frame")
    -- print("[WF_INT_SYNC] EventFrame created")
    C_ChatInfo.RegisterAddonMessagePrefix(InterruptSync.commPrefix)
    
    InterruptSync.eventFrame:SetScript("OnEvent", function(_, event, ...)
        -- print("[WF_INT_SYNC] Event fired: " .. event)
        if event == "CHAT_MSG_ADDON" then
            -- print("[WF_INT_SYNC] CHAT_MSG_ADDON triggered")
            InterruptSync:OnCommReceived(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- print("[WF_INT_SYNC] UNIT_SPELLCAST_SUCCEEDED triggered")
            InterruptSync:OnSpellcast(...)
        elseif event == "PLAYER_REGEN_DISABLED" then
            InterruptSync:RefreshColdthirstState("PLAYER_REGEN_DISABLED")
        elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
            -- print("[WF_INT_SYNC] CHAT_MSG_PARTY triggered")
            InterruptSync:OnPartyChat(...)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" or event == "ACTIVE_COMBAT_CONFIG_CHANGED" then
            InterruptSync.cachedIsValidContext = InterruptSync:IsValidContext()
            InterruptSync:UpdateGroupTracking()
        end
    end)
    -- print("[WF_INT_SYNC] Calling initial UpdateGroupTracking")
    InterruptSync:UpdateGroupTracking()
    InterruptSync:InitializeTargetInterruptWatcher()
    -- print("[WF_INT_SYNC] Initialization complete")
end

function InterruptSync:OnSpellcast(unit, castGUID, spellID)
    -- Only process player interrupts - party member data is protected
    -- print("[WF_INT_SYNC] OnSpellcast called: unit=" .. tostring(unit) .. ", spellID=" .. tostring(spellID))
    if unit ~= "player" then 
        -- print("[WF_INT_SYNC] Ignoring - not player unit")
        return 
    end
    DebugLog(self, string.format("OnSpellcast(player) spellID=%s", tostring(spellID)))
    
    -- Check if this is actually an interrupt spell
    if not INTERRUPT_SPELL_DATA[spellID] then 
        -- print("[WF_INT_SYNC] Not an interrupt spell")
        return 
    end
    
    -- print("[WF_INT_SYNC] Processing player interrupt")
    if spellID == DK_MIND_FREEZE_SPELL_ID then
        self:RefreshColdthirstState("OnSpellcast_MindFreeze")
    end
    
    local duration, source = self:ResolveInterruptCooldownDuration(spellID)
    if not duration or duration <= 0 then duration = DEFAULT_INTERRUPT_COOLDOWN end
    self:RememberObservedCooldown(spellID, duration, source)
    
    local name = UnitName(unit)
    if not name then 
        -- print("[WF_INT_SYNC] Could not get player name")
        return 
    end
    
    -- print("[WF_INT_SYNC] You cast interrupt (ID: " .. spellID .. ", Real CD: " .. duration .. "s)")
    
    -- Track this interrupt for success detection (TargetCastbar integration)
    self.lastInterruptSpellID = spellID
    self.lastInterruptTime = GetTime()
    self.lastInterruptCastToken = (self.lastInterruptCastToken or 0) + 1
    self.lastInterruptCastTokenSpellID = spellID
    self.lastInterruptCastDuration = duration
    self.pendingSuccessToken = self.lastInterruptCastToken
    self.pendingSuccessSpellID = spellID
    self.pendingSuccessExpire = GetTime() + SUCCESS_MATCH_WINDOW
    self.pendingSuccessConsumed = false
    self._cdrDispatchToken = nil
    
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, name, spellID, duration)
    end

    if self:ShouldDelayInitialDispatchForMindFreeze(spellID) then
        DebugLog(self, string.format("Initial dispatch delayed for Mind Freeze token=%s duration=%.2f", tostring(self.lastInterruptCastToken), duration))
        self:ScheduleDelayedInterruptDispatch(spellID, duration, self.lastInterruptCastToken)
    else
        -- Always sync via addon channel (works in combat)
        self:SendSync(spellID, duration)

        -- Always call announce path; it handles combat-safe local render internally.
        self:AnnounceInterrupt(spellID, duration)
    end

    -- Talent/success based CDR can apply after cast; detect by comparing live cooldown to predicted cooldown.
    self:SchedulePostCastCooldownAdjustChecks(spellID, self.lastInterruptCastToken)

    if source == "fallback" or source == "spell_fallback" then
        C_Timer.After(QUICK_RESAMPLE_DELAY, function()
            local refinedDuration, refinedSource = self:ResolveInterruptCooldownDuration(spellID)
            if not refinedDuration or refinedDuration <= 0 then return end
            if refinedSource == "fallback" or refinedSource == "spell_fallback" then return end
            if math.abs(refinedDuration - duration) < 0.5 then return end
            self:RememberObservedCooldown(spellID, refinedDuration, refinedSource)

            for _, container in ipairs(self.Instances) do
                self:UpdateBar(container, name, spellID, refinedDuration)
            end
            self:SendSync(spellID, refinedDuration)
        end)
    end
end

function InterruptSync:SchedulePostCastCooldownAdjustChecks(spellID, castToken)
    local delays = {0.08, 0.18, 0.32, 0.55, 0.90}
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            InterruptSync:DetectPostCastCooldownAdjustment(spellID, castToken)
        end)
    end
end

function InterruptSync:ShouldDelayInitialDispatchForMindFreeze(spellID)
    if spellID ~= DK_MIND_FREEZE_SPELL_ID then return false end
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then return false end
    -- Always delay initial Mind Freeze dispatch briefly so success-driven CDR
    -- can correct outgoing sync/announce before a base 15s message is emitted.
    return true
end

function InterruptSync:ScheduleDelayedInterruptDispatch(spellID, duration, castToken)
    local delay = BASE_DISPATCH_DELAY
    C_Timer.After(delay, function()
        if self._suppressBaseDispatchTokens and self._suppressBaseDispatchTokens[castToken] then
            DebugLog(self, string.format("Delayed dispatch skipped: suppressed token=%s", tostring(castToken)))
            return
        end
        if castToken ~= self.lastInterruptCastToken then
            DebugLog(self, string.format("Delayed dispatch skipped: stale token=%s current=%s", tostring(castToken), tostring(self.lastInterruptCastToken)))
            return
        end
        DebugLog(self, string.format("Delayed dispatch sending base cooldown spell=%d duration=%.2f token=%s", spellID, duration, tostring(castToken)))
        self:SendSync(spellID, duration)
        self:AnnounceInterrupt(spellID, duration)
    end)
end

function InterruptSync:DetectPostCastCooldownAdjustment(spellID, castToken)
    if castToken ~= self.lastInterruptCastToken then
        DebugLog(self, string.format("Post-cast CDR ignore: stale token=%s current=%s", tostring(castToken), tostring(self.lastInterruptCastToken)))
        return
    end
    if spellID ~= self.lastInterruptCastTokenSpellID then
        DebugLog(self, string.format("Post-cast CDR ignore: spell mismatch req=%s current=%s", tostring(spellID), tostring(self.lastInterruptCastTokenSpellID)))
        return
    end
    if not self.lastInterruptTime or not self.lastInterruptCastDuration then
        DebugLog(self, "Post-cast CDR ignore: missing cast timing memory")
        return
    end

    local elapsed = GetTime() - self.lastInterruptTime
    if elapsed < 0 then return end

    local predictedRemaining = math.max(0, self.lastInterruptCastDuration - elapsed)
    local liveRemaining = self:GetLiveRemainingCooldown(spellID)
    if not liveRemaining or liveRemaining <= 0.05 then
        DebugLog(self, string.format("Post-cast CDR ignore: no live cooldown (spell=%s live=%s predicted=%.2f)", tostring(spellID), tostring(liveRemaining), predictedRemaining))
        return
    end

    local reduction = predictedRemaining - liveRemaining
    if spellID == DK_MIND_FREEZE_SPELL_ID then
        -- For Mind Freeze, accept only real ~3s success reduction from live cooldown.
        if reduction < 2.4 or reduction > 3.6 then
            DebugLog(self, string.format("Post-cast CDR reject MF window: reduction=%.2f predicted=%.2f live=%.2f", reduction, predictedRemaining, liveRemaining))
            return
        end
    else
        -- Generic path for other spells: require meaningful reduction.
        if liveRemaining + 1.5 >= predictedRemaining then
            DebugLog(self, string.format("Post-cast CDR reject generic: reduction=%.2f predicted=%.2f live=%.2f", reduction, predictedRemaining, liveRemaining))
            return
        end
    end

    local playerName = UnitName("player")
    if not playerName then return end

    DebugLog(self, string.format("Post-cast CDR detected: spell=%d predicted=%.2f live=%.2f reduction=%.2f", spellID, predictedRemaining, liveRemaining, reduction))
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, playerName, spellID, liveRemaining)
    end
    self:SendSync(spellID, liveRemaining, GetServerTime())
    if spellID == DK_MIND_FREEZE_SPELL_ID and self._cdrDispatchToken ~= castToken then
        self._suppressBaseDispatchTokens = self._suppressBaseDispatchTokens or {}
        if castToken then
            self._suppressBaseDispatchTokens[castToken] = true
        end
        self:AnnounceInterrupt(spellID, liveRemaining)
        self._cdrDispatchToken = castToken
        DebugLog(self, string.format("Post-cast CDR announcement dispatched token=%s duration=%.2f", tostring(castToken), liveRemaining))
    end
end

function InterruptSync:OnPartyChat(text, playerName, ...)
    -- Check if Party Sync is enabled
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.partySync then return end
    
    playerName = Ambiguate(playerName, "none")
    if playerName == UnitName("player") then
        return
    end
    
    -- Parse interrupt message format: "Interrupted with X! (CD: Ys)"
    local spellName = text:match("Interrupted with ([^!]+)!")
    if not spellName then return end
    
    -- Find spell ID from spell name
    local spellID = nil
    for id, name in pairs(INTERRUPT_SPELL_DATA) do
        if name == spellName then
            spellID = id
            break
        end
    end
    
    if not spellID then
        return
    end
    
    local duration = self:ResolveInterruptCooldownDuration(spellID)
    
    -- Notice here we aren't fetching the real api CD.
    -- This is because party members' cooldown reductions are hidden.

    if type(duration) ~= "number" or duration <= 0 then duration = DEFAULT_INTERRUPT_COOLDOWN end
    
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, playerName, spellID, duration)
    end
end

function InterruptSync:ReportInterruptSuccess(targetUnit, interruptSpellID, castToken)
    -- Called by TargetCastbar when an interrupt is successfully detected
    -- This is the "detected interrupt" system - different from cast tracking
    local now = GetTime()
    if not interruptSpellID then
        if not self.pendingSuccessToken or self.pendingSuccessConsumed or not self.pendingSuccessExpire or now > self.pendingSuccessExpire then
            DebugLog(self, "Interrupt success ignored: no valid pending cast token")
            return
        end
        interruptSpellID = self.pendingSuccessSpellID or self.lastInterruptSpellID
        castToken = self.pendingSuccessToken
    end

    if castToken then
        if self.pendingSuccessConsumed and self.lastConfirmedSuccessToken == castToken then
            DebugLog(self, string.format("Interrupt success deduped by token: %d", castToken))
            return
        end
        if self.pendingSuccessToken ~= castToken then
            DebugLog(self, string.format("Interrupt success ignored: stale token %s current=%s", tostring(castToken), tostring(self.pendingSuccessToken)))
            return
        end
        if self.pendingSuccessExpire and now > self.pendingSuccessExpire then
            DebugLog(self, string.format("Interrupt success ignored: token expired %d", castToken))
            return
        end
    end

    if not interruptSpellID then
        local age = GetTime() - (self.lastInterruptTime or 0)
        if self.lastInterruptSpellID and age <= SUCCESS_CDR_WINDOW then
            interruptSpellID = self.lastInterruptSpellID
            DebugLog(self, string.format("Interrupt success inferred from recent cast: spell=%d age=%.2f", interruptSpellID, age))
        else
            DebugLog(self, "Interrupt success received without spell ID and no recent cast to match")
            return
        end
    end
    if castToken then
        self.pendingSuccessConsumed = true
        self.lastConfirmedSuccessToken = castToken
    end

    -- Apply success-based CDR regardless of announcement settings.
    self:ApplySuccessfulInterruptCDR(interruptSpellID, castToken)
    
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.announceInterruptSuccess then return end
    
    self:AnnounceInterruptSuccess(interruptSpellID)
end

function InterruptSync:ApplySuccessfulInterruptCDR(interruptSpellID, castToken)
    if interruptSpellID ~= DK_MIND_FREEZE_SPELL_ID then return end
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then return end
    self:RefreshColdthirstState("ApplySuccessfulInterruptCDR")
    DebugLog(self, string.format("Success CDR entry: spell=%s token=%s coldthirstCache=%s", tostring(interruptSpellID), tostring(castToken), tostring(self.coldthirstEnabled)))
    if not self.coldthirstEnabled then
        DebugLog(self, "Success CDR skipped: Coldthirst cache=false")
        return
    end

    local playerName = UnitName("player")
    if not playerName then
        DebugLog(self, "Success CDR skipped: playerName unavailable")
        return
    end

    local now = GetTime()
    self.activeCooldowns = self.activeCooldowns or {}
    local mem = self.activeCooldowns[playerName]

    local remaining = nil
    if mem and mem.spellID == interruptSpellID and mem.endTime then
        remaining = math.max(0, mem.endTime - now)
        DebugLog(self, string.format("Success CDR base remaining from memory: %.2f", remaining))
    elseif castToken and castToken == self.lastInterruptCastToken and self.lastInterruptCastDuration and self.lastInterruptTime then
        remaining = math.max(0, self.lastInterruptCastDuration - (now - self.lastInterruptTime))
        DebugLog(self, string.format("Success CDR base remaining from cast state: %.2f", remaining))
    end

    if not remaining or remaining <= 0.05 then
        DebugLog(self, "Success CDR skipped: no active remaining cooldown to reduce")
        return
    end

    local newRemaining = math.max(0, remaining - DK_SUCCESS_CDR_SECONDS)
    local reducedBy = remaining - newRemaining
    if reducedBy <= 0 then
        DebugLog(self, "Success CDR skipped: reducedBy <= 0")
        return
    end

    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, playerName, interruptSpellID, newRemaining)
    end

    DebugLog(self, string.format("Success CDR applied: spell=%d reduced=%.2fs remaining=%.2fs", interruptSpellID, reducedBy, newRemaining))
    if newRemaining > 0.05 then
        local dispatchDuration = math.max(0, (self.lastInterruptCastDuration or DEFAULT_INTERRUPT_COOLDOWN) - DK_SUCCESS_CDR_SECONDS)
        self._suppressBaseDispatchTokens = self._suppressBaseDispatchTokens or {}
        local dispatchToken = castToken or self.lastInterruptCastToken
        if dispatchToken then
            self._suppressBaseDispatchTokens[dispatchToken] = true
        end
        self:SendSync(interruptSpellID, dispatchDuration, GetServerTime())
        self:AnnounceInterrupt(interruptSpellID, dispatchDuration)
        self._cdrDispatchToken = dispatchToken
        DebugLog(self, string.format("Success CDR dispatch duration sent=%.2f (base=%.2f)", dispatchDuration, (self.lastInterruptCastDuration or DEFAULT_INTERRUPT_COOLDOWN)))
    end
end

function InterruptSync:AnnounceInterruptSuccess(interruptSpellID)
    -- Announce successful interrupt with target info
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.announceInterruptSuccess then return end
    
    local spellInfo = C_Spell.GetSpellInfo(interruptSpellID)
    local spellName = spellInfo and spellInfo.name or "Interrupt"
    local targetName = UnitName("target") or "Unknown"
    local msg = string.format("Successfully interrupted %s with %s!", targetName, spellName)
    
    local channel = elem.announceChannel or "PARTY"
    if channel == "PARTY" and not IsInGroup() then return end
    if (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then 
        if IsInGroup() then channel = "PARTY" else return end
    end
    
    if InCombatLockdown() then
        -- VIRTUAL CHAT (Render locally to bypass Blizzard restrictions)
        local channelName = (channel == "INSTANCE_CHAT") and "Instance" or "Party"
        local color = (channel == "INSTANCE_CHAT") and "|cffFF7F00" or "|cffAAAAFF" 
        local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. UnitName("player") .. ": |r"
        DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
    else
        SendChatMessage(msg, channel)
    end
end

function InterruptSync:AnnounceInterrupt(spellID, duration)
    -- Find the element config (use the first instance's elem as a safe bet for global-ish settings)
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.announceInterrupts then return end
    if not IsInGroup() then return end
    
    if not duration or duration <= 0 then duration = 15 end
    
    local channel = elem.announceChannel or "PARTY"
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = spellInfo and spellInfo.name or "Interrupt"
    local msg = string.format("Interrupted with %s! (CD: %ds)", spellName, duration)
    
    -- Resolve target channel for sending (out of combat). Local render can still work without a valid channel.
    local canSend = true
    if channel == "PARTY" and not IsInGroup() then
        canSend = false
    end
    if (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if IsInGroup() then
            channel = "PARTY"
        else
            canSend = false
        end
    end
    if InCombatLockdown() then
        -- VIRTUAL CHAT (Render locally to bypass Blizzard restrictions)
        local channelName = (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and "Instance" or "Party"
        if not canSend then channelName = "Local" end
        local color = (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and "|cffFF7F00" or "|cffAAAAFF"
        local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. UnitName("player") .. ": |r"
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
        else
            print(msg)
        end
    else
        if not canSend then
            -- Outside combat we only send real chat messages to valid channels.
            return
        end
        SendChatMessage(msg, channel)
    end
end

function InterruptSync:RenderSyncedInterrupt(sender, spellID, duration)
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.announceInterrupts then return end
    if not IsInGroup() then return end

    local channel = elem.announceChannel or "PARTY"
    local channelName = (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and "Instance" or "Party"
    local color = (channel == "INSTANCE_CHAT" or channel == "INSTANCE") and "|cffFF7F00" or "|cffAAAAFF"

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = spellInfo and spellInfo.name or "Interrupt"
    local msg = string.format("Interrupted with %s! (CD: %ds)", spellName, duration or 15)
    local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. (sender or "Unknown") .. ": |r"

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
    else
        print(msg)
    end
end

function InterruptSync:SendSync(spellID, duration, timestamp)
    if not IsInGroup() then return end
    
    if not duration or duration <= 0 then return end
    
    local ts = timestamp or GetServerTime()
    local msg = string.format("INT:%d:%.2f:%d", spellID, duration, ts)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end

function InterruptSync:OnCommReceived(prefix, text, channel, sender)
    if prefix ~= self.commPrefix then return end
    if not self:IsPartySyncEnabled() then return end
    sender = Ambiguate(sender, "none")

    if sender == UnitName("player") then 
        return 
    end
    
    local cmd, spellID, incDuration, timestamp = strsplit(":", text)
    spellID = tonumber(spellID)
    incDuration = tonumber(incDuration)
    timestamp = tonumber(timestamp)
    
    if cmd == "INT" and spellID then 
        local duration = incDuration or self:ResolveInterruptCooldownDuration(spellID)
        if type(duration) ~= "number" or duration <= 0 then duration = DEFAULT_INTERRUPT_COOLDOWN end
        
        local lag = math.max(0, GetServerTime() - (timestamp or 0))
        local adjDur = duration - lag
        if adjDur > 0 then
            for _, container in ipairs(self.Instances) do
                self:UpdateBar(container, sender, spellID, adjDur)
            end
            self:RenderSyncedInterrupt(sender, spellID, duration)
        end
    end
end

function InterruptSync:BroadcastActiveInterruptCooldown()
    if not IsInGroup() then return end
    if #self.interruptIDs == 0 then return end

    local now = GetTime()
    for _, spellID in ipairs(self.interruptIDs) do
        local duration, source = self:ResolveInterruptCooldownDuration(spellID)
        if duration and duration >= MIN_VALID_INTERRUPT_COOLDOWN then
            self:RememberObservedCooldown(spellID, duration, source)
        end
        if C_Spell and C_Spell.GetSpellCooldown then
            local cdInfo = C_Spell.GetSpellCooldown(spellID)
            if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
                local startTime = SafeNumber(cdInfo.startTime) or 0
                local duration = SafeNumber(cdInfo.duration) or 0
                local remaining = (startTime + duration) - now
                if duration > 0 and remaining > 0.15 then
                    self:SendSync(spellID, duration, GetServerTime())
                end
            end
        end
    end
end

-- ============================================================================
-- 3. VISUALS & WIDGETFORGE INTEGRATION
-- ============================================================================

function InterruptSync:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.bars = {}
    
    container:SetScript("OnUpdate", function(self, elapsed)
         local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
         
         -- Check instance and group validation (cached for performance)
         local isValidContext = InterruptSync.cachedIsValidContext
         
         if not isValidContext and not isUnlocked and not InterruptSync.ForceTest then
             self:Hide()
             return
         else
             self:Show()
         end
         
         if InterruptSync.ForceTest then
             self.testTimer = (self.testTimer or 0) - elapsed
             if self.testTimer <= 0 then
                 InterruptSync:Test(self, true)
                 self.testTimer = 10 
             end
             self.testActive = true
         else
             if self.testActive then
                 InterruptSync:Test(self, false)
                 self.testActive = false
                 self.testTimer = 0
             end
         end
    end)
    
    container:Show()
    table.insert(InterruptSync.Instances, container)
    self:InitializeGroupBars(container)
    
    -- Scan immediately when widget is added/enabled so it doesn't depend on opening settings.
    C_Timer.After(0.05, function()
        if not container or not container:IsShown() then return end
        InterruptSync:LoadClassInterrupt()
        InterruptSync:ApplyRuntimeCooldownOverrides()
        InterruptSync:RefreshPlayerInterruptCooldownCache()
        InterruptSync:BroadcastActiveInterruptCooldown()
        DebugLog(InterruptSync, "Initial scan completed on widget load")
    end)
    
    container:SetScript("OnHide", function(self)
        for i, inst in ipairs(InterruptSync.Instances) do
            if inst == self then table.remove(InterruptSync.Instances, i); break end
        end
    end)
    
    function container:Unload()
        if self.bars then
            for name, bar in pairs(self.bars) do
                bar:Hide()
                if bar:GetParent() == self then
                    bar:SetParent(nil)
                end
            end
            self.bars = {}
        end
        self:Hide()
        self:SetScript("OnUpdate", nil)
    end
    
    return container
end

function InterruptSync:CreateBar(container, name)
    local elem = container.elem
    local h = elem.barHeight or 30
    local w = elem.barWidth or 220
    local iSz = elem.iconSize or h
    local out = elem.fontOutline or "OUTLINE"
    local showIcon = (elem.showIcon == nil) and true or elem.showIcon
    local iconSpacing = elem.iconSpacing or 5
    local barBgAlpha = (elem.barBgAlpha or 80) / 100
    local barBSize = elem.barBorderSize or 1
    if barBSize < 0 then barBSize = 0 end
    local showBarBorder = (barBSize > 0)
    
    local rowHeight = math.max(h, showIcon and iSz or 0)
    local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
    row:SetSize(w, rowHeight)
    
    row.iconBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconBox:SetSize(iSz, iSz)
    row.iconBox:SetPoint("LEFT", 4, 0)
    
    local iconBSize = elem.iconBorderSize or 1
    if iconBSize < 0 then iconBSize = 0 end
    local showIconBorder = (iconBSize > 0)
    
    local Skin = _G.ForgeSkin
    if Skin then Skin:ApplyBackdrop(row.iconBox) end
    row.iconBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
    row.iconBox:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
    if showIconBorder then
        row.iconBox:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        row.iconBox:SetBackdropBorderColor(0, 0, 0, 0)
    end
    
    if not showIcon then row.iconBox:Hide() end
    
    local iconPad = showIconBorder and iconBSize or 0
    local iconMargin = iconPad + 1
    row.icon = row.iconBox:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", iconMargin, -iconMargin); row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -iconMargin, iconMargin)
    
    local z = elem.iconZoom or 0.08
    row.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    
    row.info = CreateFrame("Frame", nil, row); 
    if showIcon then
        row.info:SetPoint("LEFT", row.iconBox, "RIGHT", iconSpacing, 0)
    else
        row.info:SetPoint("LEFT", 4, 0) -- 4 pixels logic for class strip width
    end
    row.info:SetPoint("RIGHT", 0, 0); row.info:SetHeight(h)
    
    row.classStrip = row:CreateTexture(nil, "BORDER"); row.classStrip:SetWidth(4)
    if showIcon then
        row.classStrip:SetPoint("TOPRIGHT", row.iconBox, "TOPLEFT", -1, 0)
        row.classStrip:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMLEFT", -1, 0)
    else
        row.classStrip:SetPoint("TOPRIGHT", row.info, "TOPLEFT", -1, 0)
        row.classStrip:SetPoint("BOTTOMRIGHT", row.info, "BOTTOMLEFT", -1, 0)
    end
    row.classStrip:SetColorTexture(1, 1, 1, 1)
    
    local splitH = h / 2
    row.nameBar = CreateFrame("Frame", nil, row.info); row.nameBar:SetPoint("TOPLEFT", 0, 0); row.nameBar:SetPoint("TOPRIGHT", 0, 0); row.nameBar:SetHeight(splitH)
    
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts and elem.font then fontPath = _G.ForgeSkin.Media.Fonts[elem.font] or fontPath end
    local textColor = elem.textColor or {1, 1, 1, 1}
    local fontSize = elem.fontSize or 12
    
    row.timerBarBg = CreateFrame("Frame", nil, row.info, "BackdropTemplate"); row.timerBarBg:SetPoint("TOPLEFT", row.nameBar, "BOTTOMLEFT", 0, 0); row.timerBarBg:SetPoint("BOTTOMRIGHT", 0, 0); row.timerBarBg:SetHeight(splitH)
    
    local Skin = _G.ForgeSkin
    if Skin then Skin:ApplyBackdrop(row.timerBarBg) end
    row.timerBarBg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showBarBorder and barBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
    row.timerBarBg:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
    if showBarBorder then
        row.timerBarBg:SetBackdropBorderColor(unpack(elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        row.timerBarBg:SetBackdropBorderColor(0, 0, 0, 0)
    end
    
    row.timerBar = CreateFrame("StatusBar", nil, row.timerBarBg)
    local barPad = showBarBorder and barBSize or 0
    local barMargin = barPad + 1
    row.timerBar:SetPoint("TOPLEFT", row.timerBarBg, "TOPLEFT", barMargin, -barMargin)
    row.timerBar:SetPoint("BOTTOMRIGHT", row.timerBarBg, "BOTTOMRIGHT", -barMargin, barMargin)
    
    local tex = "Interface\\TargetingFrame\\UI-StatusBar"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures then tex = _G.ForgeSkin.Media.Textures[elem.texture] or tex end
    row.timerBar:SetStatusBarTexture(tex)
    
    local c = elem.colorOnCD or {1.0, 0.2, 0.2, 1}
    row.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    row.timerBar:SetMinMaxValues(0, 1); row.timerBar:SetValue(1)
    
    row.textFrame = CreateFrame("Frame", nil, row.info)
    row.textFrame:SetAllPoints(row.info)
    row.textFrame:SetFrameLevel(row.timerBar:GetFrameLevel() + 5)
    
    row.nameText = row.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row.nameBar, "LEFT", 2, 0); row.nameText:SetText(name); row.nameText:SetTextColor(unpack(textColor))
    row.nameText:SetFont(fontPath, fontSize, out)
    row.playerName = name
    
    row.timerText = row.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timerText:SetPoint("RIGHT", row.timerBarBg, "RIGHT", -2, 0); row.timerText:SetFont(fontPath, fontSize, out)
    row.timerText:SetTextColor(unpack(textColor))
    
    row.timerBg = row.timerBar:CreateTexture(nil, "BACKGROUND"); row.timerBg:SetAllPoints(); row.timerBg:SetColorTexture(0.1, 0.1, 0.1, barBgAlpha)
    
    return row
end

function InterruptSync:SetBarReady(container, bar, spellID)
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 134400)
    bar.icon:SetDesaturated(false)
    
    if spellInfo and spellInfo.name then
        bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or "Unknown")
    end
    
    -- Sync color with TargetCastbar colorReady or default to Gold
    local c = elem.colorReady or {1.0, 0.72, 0.04, 1}
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    bar.timerBar:SetMinMaxValues(0, 1); bar.timerBar:SetValue(1)
    bar.timerText:SetText("READY")
    
    -- Update Class Strip Color
    local classColor = {r=0.5, g=0.5, b=0.5}
    local unit = nil
    local senderName = bar.playerName
    if senderName == UnitName("player") then unit = "player"
    elseif IsInGroup() then
        for i=1, 40 do
            local u = (i <= 4) and "party"..i or "raid"..i
            if UnitName(u) == senderName then unit = u break end
        end
    end
    if unit then
        local _, cls = UnitClass(unit)
        if cls and RAID_CLASS_COLORS[cls] then classColor = RAID_CLASS_COLORS[cls] end
    end
    bar.classStrip:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    
    bar:SetScript("OnUpdate", nil)
    bar:Show()
end

function InterruptSync:UpdateBar(container, senderName, spellID, duration)
    if not container.bars[senderName] then 
        local unitClass = nil
        if senderName == "TankZilla" then unitClass = "WARRIOR"
        elseif senderName == "FrostyMage" then unitClass = "MAGE"
        elseif senderName == "SneakyRogue" then unitClass = "ROGUE"
        elseif senderName == "HealPriest" then unitClass = "PRIEST"
        elseif senderName == "HunterBeast" then unitClass = "HUNTER"
        elseif senderName == UnitName("player") then unitClass = select(2, UnitClass("player"))
        elseif IsInGroup() then
            for i=1, 40 do
                local u = (i <= 4) and "party"..i or "raid"..i
                if UnitName(u) == senderName then unitClass = select(2, UnitClass(u)) break end
            end
        end
        if unitClass then self:EnsureBarIsReady(container, senderName, unitClass) end
    end
    
    local bar = container.bars[senderName]
    if not bar then return end
    
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 134400)
    bar.icon:SetDesaturated(true)
    
    if spellInfo and spellInfo.name then
        bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or "Unknown")
    end
    
    -- Cooldown Color
    local c = elem.colorOnCD or {1.0, 0.2, 0.2, 1}
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    
    bar.endTime = GetTime() + duration
    bar.duration = duration
    bar.currentSpellID = spellID
    
    self.activeCooldowns = self.activeCooldowns or {}
    self.activeCooldowns[senderName] = { spellID = spellID, endTime = bar.endTime, duration = duration }
    
    bar:Show()
    
    bar:SetScript("OnUpdate", function(f)
        local rem = f.endTime - GetTime()
        if rem <= 0 then
            InterruptSync:SetBarReady(container, f, f.currentSpellID)
        else
            f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
        end
    end)
    self:LayoutBars(container)
end

function InterruptSync:LayoutBars(container)
    local elem = container.elem
    local prev = nil
    local spacing = elem.spacing or 5
    local sortedNames = {}
    for name, _ in pairs(container.bars) do table.insert(sortedNames, name) end
    table.sort(sortedNames) -- Consistent sorting
    
    for _, name in ipairs(sortedNames) do
        local bar = container.bars[name]
        if bar:IsShown() then
            bar:ClearAllPoints()
            if not prev then 
                bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            else 
                bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) 
            end
            prev = bar
        end
    end
end

function InterruptSync:Test(container, on)
    if on then
        self:UpdateBar(container, "TankZilla", 6552, 115) 
        self:UpdateBar(container, "FrostyMage", 2139, 124)
        self:UpdateBar(container, "SneakyRogue", 1766, 115)
        self:UpdateBar(container, "HealPriest", 15487, 145)
        self:UpdateBar(container, "HunterBeast", 147362, 124)
    else
        for name, bar in pairs(container.bars) do
            if name == "TankZilla" or name == "FrostyMage" or name == "SneakyRogue" or name == "HealPriest" or name == "HunterBeast" then
                bar:Hide()
                container.bars[name] = nil
            end
        end
        self:InitializeGroupBars(container)
    end
end

function InterruptSync:RefreshBars(container)
    local elem = container.elem
    local height = elem.barHeight or 30
    local width = elem.barWidth or 220
    local iconSize = elem.iconSize or height
    local outline = elem.fontOutline or "OUTLINE"
    local barBgAlpha = (elem.barBgAlpha or 80) / 100
    local barBSize = elem.barBorderSize or 1
    if barBSize < 0 then barBSize = 0 end
    local showBarBorder = (barBSize > 0)
    local iconBSize = elem.iconBorderSize or 1
    if iconBSize < 0 then iconBSize = 0 end
    local showIconBorder = (iconBSize > 0)
    local showIcon = (elem.showIcon == nil) and true or elem.showIcon
    local iconSpacing = elem.iconSpacing or 5
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts and elem.font then fontPath = _G.ForgeSkin.Media.Fonts[elem.font] or fontPath end
    local textColor = elem.textColor or {1, 1, 1, 1}
    local fontSize = elem.fontSize or 12
    local iconZoom = elem.iconZoom or 0.08
    local count = 0
    
    for _, row in pairs(container.bars) do
        local rowHeight = math.max(height, showIcon and iconSize or 0)
        row:SetSize(width, rowHeight)
        
        row.iconBox:SetSize(iconSize, iconSize)
        local Skin = _G.ForgeSkin
        if Skin then Skin:ApplyBackdrop(row.iconBox) end
        row.iconBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
        row.iconBox:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
        if showIconBorder then
            row.iconBox:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
        else
            row.iconBox:SetBackdropBorderColor(0, 0, 0, 0)
        end
        if showIcon then row.iconBox:Show() else row.iconBox:Hide() end
        
        local iconPad = showIconBorder and iconBSize or 0
        local iconMargin = iconPad + 1
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", iconMargin, -iconMargin)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -iconMargin, iconMargin)
        row.icon:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)
        if showIcon then
            row.info:SetPoint("LEFT", row.iconBox, "RIGHT", iconSpacing, 0)
            row.classStrip:ClearAllPoints()
            row.classStrip:SetPoint("TOPRIGHT", row.iconBox, "TOPLEFT", -1, 0)
            row.classStrip:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMLEFT", -1, 0)
        else
            row.info:SetPoint("LEFT", 4, 0) -- 4 pixels to make room for classStrip
            row.classStrip:ClearAllPoints()
            row.classStrip:SetPoint("TOPRIGHT", row.info, "TOPLEFT", -1, 0)
            row.classStrip:SetPoint("BOTTOMRIGHT", row.info, "BOTTOMLEFT", -1, 0)
        end
        row.info:SetHeight(height)
        local splitH = height / 2
        row.nameBar:SetHeight(splitH)
        row.timerBarBg:SetHeight(splitH)
        
        row.nameText:SetFont(fontPath, fontSize, outline)
        row.nameText:SetTextColor(unpack(textColor))
        row.timerText:SetFont(fontPath, fontSize, outline)
        row.timerText:SetTextColor(unpack(textColor))
        
        local Skin = _G.ForgeSkin
        if Skin then Skin:ApplyBackdrop(row.timerBarBg) end
        row.timerBarBg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showBarBorder and barBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
        row.timerBarBg:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
        if showBarBorder then
            row.timerBarBg:SetBackdropBorderColor(unpack(elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
        else
            row.timerBarBg:SetBackdropBorderColor(0, 0, 0, 0)
        end
        
        local barPad = showBarBorder and barBSize or 0
        local barMargin = barPad + 1
        row.timerBar:ClearAllPoints()
        row.timerBar:SetPoint("TOPLEFT", row.timerBarBg, "TOPLEFT", barMargin, -barMargin)
        row.timerBar:SetPoint("BOTTOMRIGHT", row.timerBarBg, "BOTTOMRIGHT", -barMargin, barMargin)
        
        local tex = "Interface\\TargetingFrame\\UI-StatusBar"
        if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures then 
            tex = _G.ForgeSkin.Media.Textures[elem.texture] or tex 
        end
        row.timerBar:SetStatusBarTexture(tex)
        row.timerBg:SetColorTexture(0.1, 0.1, 0.1, barBgAlpha)
        
        -- If on cooldown, update color
        if row:GetScript("OnUpdate") then
             local c = elem.colorOnCD or {1.0, 0.2, 0.2, 1}
             row.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        else
             local c = elem.colorReady or {1.0, 0.72, 0.04, 1}
             row.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        end
        count = count + 1
    end
        local maxH = math.max(height, showIcon and iconSize or 0)
        local spacing = elem.spacing or 5
        container:SetSize(width, math.max(1, (count * maxH) + (math.max(0, count - 1) * spacing)))
    self:LayoutBars(container)
end

-- =========================================================================
--  4. SETTINGS BUILDER
-- =========================================================================

function InterruptSync:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local Skin = _G.ForgeSkin
    
    parentFrame.isTestingGlobal_InterruptSync = parentFrame.isTestingGlobal_InterruptSync or false
    
    local function RefreshLive()
        local bars = WidgetForge:GetBarFrames()
        for index, bar in pairs(bars) do
            if bar.customWidgets then
                for _, cw in ipairs(bar.customWidgets) do
                     if cw.elem == elem then
                        InterruptSync:RefreshBars(cw)
                        if WidgetForge.UpdateBarValues then WidgetForge:UpdateBarValues(index) end
                     end
                end
            end
        end
    end

    if not _G.WidgetForgeUtils or not _G.WidgetForgeUtils.CreateSettingsBuilder then return end
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb

    -- Settings panel is a good safe point to refresh and broadcast current interrupt cooldown state.
    C_Timer.After(0.05, function()
        InterruptSync:LoadClassInterrupt()
        InterruptSync:ApplyRuntimeCooldownOverrides()
        InterruptSync:RefreshPlayerInterruptCooldownCache()
        InterruptSync:BroadcastActiveInterruptCooldown()
    end)
    
    local texItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then 
        for k, _ in pairs(Skin.Media.Textures) do table.insert(texItems, {text=tostring(k), value=k}) end 
    end
    if #texItems == 0 then texItems = {{text="Default", value="Smooth"}} 
    else table.sort(texItems, function(a,b) return a.text < b.text end) end

    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then 
        for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=tostring(k), value=k}) end 
    end
    if #fontItems == 0 then fontItems = {{text="Default", value="Fonts\\FRIZQT__.TTF"}} 
    else table.sort(fontItems, function(a,b) return a.text < b.text end) end

    sb:AddHeader("Bar Settings")
    sb:AddSlider("barHeight", "Bar Height", 10, 60, 1, 30, elem, RefreshLive)
    sb:AddSlider("barWidth", "Bar Width", 50, 600, 5, 220, elem, RefreshLive)
    sb:AddSlider("spacing", "Spacing Between Bars", 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("barBgAlpha", "Background Alpha (%)", 0, 100, 5, 80, elem, RefreshLive)
    sb:AddDropdown("texture", "Bar Texture", texItems, "Smooth", elem, RefreshLive)
    sb:AddColor("barBorderColor", "Bar Border Color", {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("barBorderSize", "Border Thickness (0 to Disable)", 0, 5, 1, 1, elem, RefreshLive)
    
    sb:AddHeader("Text Settings")
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 12, elem, RefreshLive)
    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)
    sb:AddColor("textColor", "Text Color", {1, 1, 1, 1}, elem, RefreshLive)

    sb:AddHeader("Icon Settings")
    sb:AddSwitch("showIcon", "Show Spell Icon", true, elem, RefreshLive)
    sb:AddSlider("iconSpacing", "Spacing from Bar", 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("iconSize", "Icon Size", 10, 100, 1, 30, elem, RefreshLive)
    sb:AddSlider("iconZoom", "Icon Zoom (Crop Border)", 0, 0.20, 0.01, 0.08, elem, RefreshLive)
    sb:AddColor("iconBorderColor", "Icon Border Color", {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("iconBorderSize", "Border Thickness (0 to Disable)", 0, 5, 1, 1, elem, RefreshLive)

    sb:AddHeader("Status Colors")
    sb:AddColor("colorReady", "Available Color (Ready)", {1.0, 0.72, 0.04, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", "Cooldown Color (Busy)", {1.0, 0.2, 0.2, 1}, elem, RefreshLive)
    sb:AddColor("colorSuccess", "Success Color", {0.1, 1.0, 0.3, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", "Shielded Color", {0.45, 0.45, 0.6, 1}, elem, RefreshLive)

    sb:AddHeader("Test Mode")
    
    if not parentFrame.testBtnInterruptSync then
        local btnTest = Skin:CreateButton(f.content, "Test Mode: OFF", 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnInterruptSync = btnTest
        
        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal_InterruptSync then 
                btnTest:SetBackdropColor(0, 0.8, 0, 1)
                btnTest.text:SetText("Test Mode: ON")
            else 
                btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                btnTest.text:SetText("Test Mode: OFF") 
            end
        end
        
        UpdateTestButtonVisuals()
        btnTest:Show()
        
        btnTest:SetScript("OnEnter", function()
            if parentFrame.isTestingGlobal_InterruptSync then btnTest:SetBackdropColor(0, 1, 0, 1) 
            else btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
        end)
        btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
        
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal_InterruptSync = not parentFrame.isTestingGlobal_InterruptSync
            UpdateTestButtonVisuals()
            InterruptSync.ForceTest = parentFrame.isTestingGlobal_InterruptSync
            RefreshLive()
        end)
        
        if not parentFrame.onCloseWidgetSpecific_InterruptSync then
             parentFrame.onCloseWidgetSpecific_InterruptSync = function() 
                 parentFrame.isTestingGlobal_InterruptSync = false
                 InterruptSync.ForceTest = false
             end
        end
    else
        if parentFrame.testBtnInterruptSync then
            parentFrame.testBtnInterruptSync:Show()
        end
    end

    sb:AddHeader("Announcements")
    sb:AddSwitch("announceInterrupts", "Announce my Interrupts", false, elem, RefreshLive)
    sb:AddSwitch("announceInterruptSuccess", "Announce Successful Interrupts", false, elem, RefreshLive)
    sb:AddDropdown("announceChannel", "Announce Channel", {
        {text = "Party", value = "PARTY"},
        {text = "Instance", value = "INSTANCE_CHAT"}
    }, "PARTY", elem, RefreshLive)
    
    sb:AddHeader("Party Sync")
    sb:AddSwitch("partySync", "Listen to party interrupts", false, elem, RefreshLive)
    
    local txtHelp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtHelp:SetWordWrap(true)
    txtHelp:SetWidth(600)
    txtHelp:SetJustifyH("LEFT")
    txtHelp:SetTextColor(1, 0.82, 0) -- Gold/Yellow color
    txtHelp:SetText("Note: For the Party Sync to function correctly and track your group members' interrupts, all players in the party MUST have the WidgetForge addon installed.")
    
    -- sb.y is currently at the bottom of the checkbox. Move down by 5-10 pixels for padding.
    sb.y = sb.y - 45
    txtHelp:SetPoint("TOPLEFT", sb.canvas, "TOPLEFT", 12, sb.y)
    
    -- Reserve space for the text block itself (approx 30-40 pixels depending on wrap)
    sb.y = sb.y - 0
    
    sb:Finish()
end
