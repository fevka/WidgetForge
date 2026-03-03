-- =========================================================================
--  WidgetForge - Crowd Control (CC) Party Sync Module
--  [WoW 12 Compliant - Midnight API] - Persistent Bars Edition
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
if not _G.WidgetForge.CCSync then _G.WidgetForge.CCSync = {} end

local CCSync = _G.WidgetForge.CCSync
addonTable.CCSync = CCSync

CCSync.Instances = {}
CCSync.commPrefix = "WF_CC_SYNC"
CCSync.knownSpells = {}      -- knownSpells["PlayerName"] = {853, 119381, ...}
CCSync.ccIDLookup = {}
CCSync.lastPartySize = 0
CCSync.hasBroadcasted = false
-- ============================================================================
-- 1. CC DATA (Dynamic CD Detection)
-- ============================================================================
local CC_DATA = {
    WARRIOR = { DEFAULT = {ids = {107570, 5246, 132168}, spellName = "Storm Bolt / Intimidating Shout / Shockwave", names = {"Storm Bolt", "Intimidating Shout", "Shockwave"}} },
    ROGUE   = { DEFAULT = {ids = {408, 2094, 1833, 1776, 207736}, spellName = "Kidney Shot / Blind / Cheap Shot / Gouge", names = {"Kidney Shot", "Blind", "Cheap Shot", "Gouge", "Shadowstrike"}} },
    MAGE    = { DEFAULT = {ids = {122, 118, 31661, 157997, 113724}, spellName = "Frost Nova / Polymorph / Dragon's Breath / Ice Nova / Ring of Frost", names = {"Frost Nova", "Polymorph", "Dragon's Breath", "Ice Nova", "Ring of Frost"}} },
    DEATHKNIGHT = { DEFAULT = {ids = {221562, 108194, 207167, 108199}, spellName = "Asphyxiate / Blinding Sleet / Gorefiend's Grasp", names = {"Asphyxiate", "Blinding Sleet", "Gorefiend's Grasp"}} },
    PALADIN = { DEFAULT = {ids = {853, 20066, 115750}, spellName = "Hammer of Justice / Repentance / Blinding Light", names = {"Hammer of Justice", "Repentance", "Blinding Light"}} },
    MONK    = { DEFAULT = {ids = {119381, 115078, 116844, 122470}, spellName = "Leg Sweep / Paralysis / Ring of Peace / Touch of Karma", names = {"Leg Sweep", "Paralysis", "Ring of Peace", "Touch of Karma"}} },
    DEMONHUNTER = { DEFAULT = {ids = {179057, 211881, 207684, 218352}, spellName = "Chaos Nova / Fel Eruption / Sigil of Misery / Imprison", names = {"Chaos Nova", "Fel Eruption", "Sigil of Misery", "Imprison"}} },
    EVOKER  = { DEFAULT = {ids = {372048, 357214, 360806, 358385}, spellName = "Oppressing Roar / Deep Breath / Sleep Walk / Landslide", names = {"Oppressing Roar", "Deep Breath", "Sleep Walk", "Landslide"}} },
    WARLOCK = { DEFAULT = {ids = {30283, 89766, 6789, 5484, 118699, 710}, spellName = "Shadowfury / Axe Toss / Mortal Coil / Howl of Terror / Fear / Banish", names = {"Shadowfury", "Axe Toss", "Mortal Coil", "Howl of Terror", "Fear", "Banish"}} },
    SHAMAN  = { DEFAULT = {ids = {51514, 192058, 605, 51490, 51485, 360936}, spellName = "Hex / Capacitor Totem / Mind Control / Thunderstorm / Earthgrab / Lasso", names = {"Hex", "Capacitor Totem", "Mind Control", "Thunderstorm", "Earthgrab Totem", "Lightning Lasso"}} },
    PRIEST  = { DEFAULT = {ids = {8122, 64044, 205369, 88625, 9484, 115163, 605}, spellName = "Psychic Scream / Psychic Horror / Mind Bomb / Chastise / Shackle / Mind Control", names = {"Psychic Scream", "Psychic Horror", "Mind Bomb", "Chastise", "Shackle Undead", "Mind Control"}} },
    HUNTER  = { DEFAULT = {ids = {3355, 24394, 109248, 19577, 202933, 162480, 213691}, spellName = "Freezing Trap / Intimidation / Binding Shot", names = {"Freezing Trap", "Intimidation", "Binding Shot", "Spider Sting", "Steel Trap", "Scatter Shot"}} },
    DRUID   = { DEFAULT = {ids = {5211, 33786, 102359, 339, 99, 102793}, spellName = "Mighty Bash / Cyclone / Mass Entanglement / Roots / Roar / Vortex", names = {"Mighty Bash", "Cyclone", "Mass Entanglement", "Entangling Roots", "Incapacitating Roar", "Ursol's Vortex"}} },
}

local function AddUniqueID(dest, seen, id)
    id = tonumber(id)
    if not id or id <= 0 or seen[id] then return end
    seen[id] = true
    table.insert(dest, id)
end

-- Normalize hardcoded IDs by resolving the paired spell name when possible.
-- This self-heals stale IDs (e.g. spellID changes between expansions/patches).
local function NormalizeCCDataSpellIDs()
    if not C_Spell or not C_Spell.GetSpellInfo then return end
    for _, classData in pairs(CC_DATA) do
        for _, specData in pairs(classData) do
            if type(specData) == "table" and type(specData.ids) == "table" then
                local normalized = {}
                local seen = {}
                local names = type(specData.names) == "table" and specData.names or nil

                for index, id in ipairs(specData.ids) do
                    local resolvedID = nil
                    if names and names[index] then
                        local info = C_Spell.GetSpellInfo(names[index])
                        if info and info.spellID then
                            resolvedID = info.spellID
                        end
                    end
                    -- Keep the hardcoded ID and also add the resolved runtime ID.
                    -- Some spells can surface alternate IDs in cast events depending on spec/override.
                    AddUniqueID(normalized, seen, id)
                    AddUniqueID(normalized, seen, resolvedID)
                end

                if names then
                    for _, spellName in ipairs(names) do
                        local info = C_Spell.GetSpellInfo(spellName)
                        if info and info.spellID then
                            AddUniqueID(normalized, seen, info.spellID)
                        end
                    end
                end

                if #normalized > 0 then
                    specData.ids = normalized
                end
            end
        end
    end
end

NormalizeCCDataSpellIDs()

-- Player's CC spell IDs (filtered by IsPlayerSpell)
CCSync.ccIDs = {}

function CCSync:LoadClassCC()
    local class = select(2, UnitClass("player"))
    local data = CC_DATA[class]
    if not data then self.ccIDs = {}; return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex] or data.DEFAULT
    self.ccIDs = {}
    
    if specData and specData.ids then
        -- Pass 1: Try all hardcoded IDs
        for _, id in ipairs(specData.ids) do
            local known = false
            if IsPlayerSpell and IsPlayerSpell(id) then known = true end
            if not known and IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then known = true end
            if not known and IsSpellKnown and IsSpellKnown(id) then known = true end
            
            -- Fallback for talented spells that might not trigger IsPlayerSpell correctly in all states
            if not known and FindSpellBookSlotBySpellID then
                local slot = FindSpellBookSlotBySpellID(id)
                if slot and slot > 0 then known = true end
            end
            
            if known then
                table.insert(self.ccIDs, id)
            end
        end
        
        -- Pass 2: If we didn't find all expected spells, try name-based lookup for missing ones
        if specData.names then
            for _, spellName in ipairs(specData.names) do
                local info = C_Spell.GetSpellInfo(spellName)
                if info and info.spellID then
                    local id = info.spellID
                    
                    -- Check if we already found this ID in Pass 1
                    local alreadyFound = false
                    for _, existingID in ipairs(self.ccIDs) do
                        if existingID == id then alreadyFound = true break end
                    end
                    
                    if not alreadyFound then
                        local known = false
                        if IsPlayerSpell and IsPlayerSpell(id) then known = true end
                        if not known and IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then known = true end
                        if not known and IsSpellKnown and IsSpellKnown(id) then known = true end
                        
                        if not known and FindSpellBookSlotBySpellID then
                            local slot = FindSpellBookSlotBySpellID(id)
                            if slot and slot > 0 then known = true end
                        end
                        
                        if known then
                            table.insert(self.ccIDs, id)
                        end
                    end
                end
            end
        end
    end
    
    -- Store own spells in knownSpells table
    local myName = UnitName("player")
    if myName then
        self.knownSpells[myName] = self.ccIDs
    end

    self.ccIDLookup = {}
    for _, id in ipairs(self.ccIDs) do
        self.ccIDLookup[id] = true
    end
end

CCSync:LoadClassCC()

local specTrackerFrame = CreateFrame("Frame")
specTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
specTrackerFrame:SetScript("OnEvent", function(_, event)
    CCSync:LoadClassCC()
    CCSync:ApplyRuntimeCooldownOverrides()
    CCSync:RefreshPlayerCCCooldownCache()
    -- Re-broadcast on spec change or entering world (dungeon entry)
    if IsInGroup() then
        C_Timer.After(1, function() CCSync:BroadcastSpells() end)
    end
end)

-- ============================================================================
-- SPELL BROADCAST & HANDSHAKE
-- ============================================================================
function CCSync:BroadcastSpells()
    if not IsInGroup() then return end
    if #self.ccIDs == 0 then return end
    
    local spellList = {}
    for _, id in ipairs(self.ccIDs) do
        table.insert(spellList, tostring(id))
    end
    local msg = "SPELLS:" .. table.concat(spellList, ":")
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end

function CCSync:SendHello()
    if not IsInGroup() then return end
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, "HELLO", channel)
end

function CCSync:GetPartySize()
    if not IsInGroup() then return 0 end
    if IsInRaid() then return GetNumGroupMembers() end
    return GetNumGroupMembers() -- includes player in party
end

local DEFAULT_CC_COOLDOWN = 60
local GCD_SPELL_ID = 61304
local GCD_EPSILON = 0.15
local QUICK_RESAMPLE_DELAY = 0.12
local MIN_VALID_CC_COOLDOWN = 1.0

-- Targeted safety fallbacks for spells that are often misread as GCD in the same frame as cast.
local CC_COOLDOWN_FALLBACK = {
    [221562] = 45, -- Asphyxiate
    [108194] = 45, -- Asphyxiate (alternate/legacy ID used by some specs/overrides)
    [51514] = 30,  -- Hex
    [192058] = 60, -- Capacitor Totem
}
local CC_NAME_COOLDOWN_FALLBACK = {}

local function RegisterNameFallbackFromID(id, duration)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        CC_NAME_COOLDOWN_FALLBACK[info.name] = duration
    end
end

for spellID, duration in pairs(CC_COOLDOWN_FALLBACK) do
    RegisterNameFallbackFromID(spellID, duration)
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

local function ExtractBaseCooldownSeconds(baseCooldownInfo)
    local n = SafeNumber(baseCooldownInfo)
    if n and n > 0 then
        return n / 1000
    end
    if type(baseCooldownInfo) == "table" then
        local ms = SafeNumber(baseCooldownInfo.baseCooldownMS)
            or SafeNumber(baseCooldownInfo.cooldownMS)
            or SafeNumber(baseCooldownInfo.baseCooldown)
            or SafeNumber(baseCooldownInfo.cooldown)
            or SafeNumber(baseCooldownInfo.durationMS)
            or SafeNumber(baseCooldownInfo.duration)
        if ms and ms > 0 then
            -- API variants may already be seconds; normalize only when value looks like ms.
            if ms > 100 then
                return ms / 1000
            end
            return ms
        end
    end
    return nil
end

local function DebugLog(self, msg)
    if self and self.DebugMode then
        print("[WF_CC_SYNC DEBUG] " .. tostring(msg))
    end
end

function CCSync:EnsureRuntimeCooldownDB()
    if type(_G.WidgetForgeDB) ~= "table" then _G.WidgetForgeDB = {} end
    if type(_G.WidgetForgeDB.runtimeCCCooldowns) ~= "table" then
        _G.WidgetForgeDB.runtimeCCCooldowns = {}
    end
    return _G.WidgetForgeDB.runtimeCCCooldowns
end

function CCSync:ApplyRuntimeCooldownOverrides()
    local db = self:EnsureRuntimeCooldownDB()
    local applied = 0
    for spellIDStr, duration in pairs(db) do
        local sid = tonumber(spellIDStr)
        local dur = RoundTo2(duration)
        if sid and dur and dur >= MIN_VALID_CC_COOLDOWN then
            CC_COOLDOWN_FALLBACK[sid] = dur
            RegisterNameFallbackFromID(sid, dur)
            applied = applied + 1
        end
    end
    DebugLog(self, string.format("Runtime CC overrides applied: %d", applied))
end

function CCSync:RememberObservedCooldown(spellID, duration, source)
    if not spellID then return end
    if source ~= "live" and source ~= "charges" and source ~= "base" then return end

    local dur = RoundTo2(duration)
    if not dur or dur < MIN_VALID_CC_COOLDOWN then return end

    local sid = tonumber(spellID)
    if not sid then return end

    local prev = CC_COOLDOWN_FALLBACK[sid]
    local db = self:EnsureRuntimeCooldownDB()
    local existingPersisted = SafeNumber(db[tostring(sid)])
    if prev and math.abs(prev - dur) < 0.01 then
        -- Persist baseline once so next sessions can confirm runtime overrides were loaded.
        if not existingPersisted then
            db[tostring(sid)] = dur
            DebugLog(self, string.format("Persisted baseline CC cooldown spell=%d value=%.2f source=%s", sid, dur, tostring(source)))
        else
            DebugLog(self, string.format("CC cooldown unchanged spell=%d value=%.2f source=%s", sid, dur, tostring(source)))
        end
        return
    end

    CC_COOLDOWN_FALLBACK[sid] = dur
    RegisterNameFallbackFromID(sid, dur)

    db[tostring(sid)] = dur
    DebugLog(self, string.format("Learned CC cooldown spell=%d old=%s new=%.2f source=%s (saved to WidgetForgeDB.runtimeCCCooldowns)", sid, tostring(prev), dur, tostring(source)))
end

function CCSync:ResolveCooldownDuration(spellID)
    if not spellID then return DEFAULT_CC_COOLDOWN, "fallback" end

    -- Preferred: read the live cooldown state right after SPELLCAST_SUCCEEDED.
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

    -- Charge-based spells: use charge cooldown when a charge is consumed.
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

    -- Fallback: use static spell base cooldown (milliseconds -> seconds).
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local baseCooldownInfo = C_Spell.GetSpellBaseCooldown(spellID)
        local baseSec = ExtractBaseCooldownSeconds(baseCooldownInfo)
        if baseSec and SafeGreaterThan(baseSec, 0) then
            local gcd = self:GetCurrentGCD()
            if SafeGreaterThan(baseSec, gcd + GCD_EPSILON) then
                return baseSec, "base"
            end
        end
    end

    if CC_COOLDOWN_FALLBACK[spellID] then
        return CC_COOLDOWN_FALLBACK[spellID], "spell_fallback"
    end

    -- Final fallback by localized spell name to catch alternate runtime spellIDs.
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        local byName = info and info.name and CC_NAME_COOLDOWN_FALLBACK[info.name]
        if byName then
            return byName, "name_fallback"
        end
    end
    
    return DEFAULT_CC_COOLDOWN, "fallback"
end

function CCSync:GetCurrentGCD()
    local gcd = 1.5
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
            gcd = SafeNumber(cdInfo.duration) or gcd
        end
    end
    return gcd
end

local function BuildBarKey(playerName, spellID)
    return tostring(playerName or "?") .. ":" .. tostring(spellID or 0)
end

local function ShouldHideOwnBar(elem, playerName)
    if not elem or not elem.hideOwnCC then return false end
    local myName = UnitName("player")
    return myName and playerName and playerName == myName
end

local function GetSpellListFor(classToken, knownList)
    local data = classToken and CC_DATA[classToken]
    local defaults = (data and data.DEFAULT and type(data.DEFAULT.ids) == "table") and data.DEFAULT.ids or {}

    local merged = {}
    local seen = {}
    
    -- If knownList is explicitly passed as a table (even empty), it means we successfully scanned their talents.
    -- If they have no known CCs, we return empty so the UI hides the bar.
    if type(knownList) == "table" then
        if #knownList > 0 then
            for _, id in ipairs(knownList) do
                if id and not seen[id] then
                    table.insert(merged, id)
                    seen[id] = true
                end
            end
        end
        return merged
    end
    
    -- Otherwise (e.g. data hasn't loaded or isn't available for this member), fallback to the most common default spell
    if defaults and #defaults > 0 then
        table.insert(merged, defaults[1])
    end
    
    return merged
end

-- ============================================================================
-- INSTANCE & GROUP VALIDATION
-- ============================================================================

function CCSync:IsValidContext()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or (instanceType ~= "party" and instanceType ~= "scenario") then
        return false
    end
    if IsInRaid() then return false end
    return true
end

-- ============================================================================
-- 2. EVENT HANDLING
-- ============================================================================
function CCSync:UpdateGroupTracking()
    -- Detect if our spells changed during this update
    local myName = UnitName("player")
    local oldSpellsHash = ""
    if myName and self.knownSpells[myName] then
        oldSpellsHash = table.concat(self.knownSpells[myName], ",")
    end
    
    -- Always refresh our own spell data first
    self:LoadClassCC()
    self:ApplyRuntimeCooldownOverrides()
    self:RefreshPlayerCCCooldownCache()
    
    local newSpellsHash = ""
    if myName and self.knownSpells[myName] then
        newSpellsHash = table.concat(self.knownSpells[myName], ",")
    end
    
    -- If we are in a group and our talents/cc spells actually changed, broadcast them
    if oldSpellsHash ~= "" and oldSpellsHash ~= newSpellsHash and IsInGroup() then
        C_Timer.After(0.5, function() CCSync:BroadcastSpells() end)
    end
    
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    self.eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    
    self.cachedIsValidContext = self:IsValidContext()
    self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

    for _, container in ipairs(self.Instances) do
        self:InitializeGroupBars(container)
    end
    
    -- Check party size changes for broadcast triggers
    local currentSize = self:GetPartySize()
    if IsInGroup() then
        -- New player joined → say hello + share our spells
        if currentSize > self.lastPartySize then
            C_Timer.After(0.5, function()
                CCSync:SendHello()
                CCSync:BroadcastSpells()
            end)
        end
        -- Party reached 5 → broadcast again
        if currentSize >= 5 and self.lastPartySize < 5 then
            C_Timer.After(1, function() CCSync:BroadcastSpells() end)
        end
    else
        -- Left group → clear known spells from others
        local myName = UnitName("player")
        for name, _ in pairs(self.knownSpells) do
            if name ~= myName then
                self.knownSpells[name] = nil
            end
        end
    end
    self.lastPartySize = currentSize
end

function CCSync:RefreshPlayerCCCooldownCache()
    if #self.ccIDs == 0 then return end
    local gcd = self:GetCurrentGCD()
    DebugLog(self, string.format("Refresh CC cache: spells=%d gcd=%.2f", #self.ccIDs, gcd))
    for _, spellID in ipairs(self.ccIDs) do
        local duration, source = self:ResolveCooldownDuration(spellID)
        DebugLog(self, string.format("Cache probe spell=%d duration=%s source=%s", spellID, tostring(duration), tostring(source)))
        if duration and duration > (gcd + GCD_EPSILON) then
            self:RememberObservedCooldown(spellID, duration, source)
        end
    end
end

function CCSync:InitializeGroupBars(container)
    local activeKeys = {}
    
    -- Self: one row per known/default CC spell
    local myName = UnitName("player")
    if myName and not ShouldHideOwnBar(container and container.elem, myName) then
        local myClass = select(2, UnitClass("player"))
        local mySpells = GetSpellListFor(myClass, self.knownSpells[myName])
        for _, sid in ipairs(mySpells) do
            self:EnsureBarIsReady(container, myName, myClass, sid)
            activeKeys[BuildBarKey(myName, sid)] = true
        end
    end
    
    -- Party members: one row per shared CC spell
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and 40 or 4
        for i=1, num do
            local unit = prefix..i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    local unitClass = select(2, UnitClass(unit))
                    local unitSpells = GetSpellListFor(unitClass, self.knownSpells[name])
                    for _, sid in ipairs(unitSpells) do
                        self:EnsureBarIsReady(container, name, unitClass, sid)
                        activeKeys[BuildBarKey(name, sid)] = true
                    end
                end
            end
        end
    end

    -- Remove bars that are no longer active
    if container.bars then
        for key, bar in pairs(container.bars) do
            if not activeKeys[key] then
                bar:Hide()
                container.bars[key] = nil
            end
        end
    end

    -- No hard fallback: if the player doesn't have any CC spells talented, the widget should be empty/hidden.

    self:RefreshBars(container)
end

function CCSync:EnsureBarIsReady(container, name, class, spellID)
    if not name or not class then return end
    
    -- Use provided spell if available
    local resolvedSpellID = tonumber(spellID) or 0
    
    -- If no valid spell is provided, fallback to default (ONLY if we literally have NOT provided a spellID to track)
    if resolvedSpellID <= 0 then
        if self.knownSpells[name] and #self.knownSpells[name] > 0 then
            resolvedSpellID = self.knownSpells[name][1]
        elseif CC_DATA[class] then
            local specData = CC_DATA[class].DEFAULT or {}
            resolvedSpellID = specData.ids and specData.ids[1] or 0
        end
    end

    local key = BuildBarKey(name, resolvedSpellID)
    
    if not container.bars[key] then
        local row = self:CreateBar(container, name)
        row.ccSpellID = resolvedSpellID
        container.bars[key] = row
        self:SetBarReady(container, row, resolvedSpellID)
    end
    
    -- Restore active cooldown from memory to survive zone/loading screens without API taint
    self.activeCooldowns = self.activeCooldowns or {}
    local mem = self.activeCooldowns[key]
    if mem and mem.endTime and mem.endTime > GetTime() then
        local bar = container.bars[key]
        -- if it's currently showing ready (no OnUpdate), restore the cooldown visually
        if bar and not bar:GetScript("OnUpdate") then
            bar.endTime = mem.endTime
            bar.duration = mem.duration
            bar.currentSpellID = mem.spellID
            
            local spellInfo = C_Spell.GetSpellInfo(mem.spellID)
            bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
            bar.icon:SetDesaturated(true)
            
            if spellInfo and spellInfo.name then
                bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
            else
                bar.nameText:SetText(bar.playerName or "Unknown")
            end
            
            local c = container.elem.colorOnCD or {1.0, 0.5, 0.0, 1}
            bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
            
            bar:Show()
            if bar.cooldown then
                if container.elem.attachToParty then
                    bar.cooldown:SetCooldown(mem.endTime - mem.duration, mem.duration)
                    bar.cooldown:Show()
                else
                    bar.cooldown:Hide()
                end
            end
            
            bar:SetScript("OnUpdate", function(f)
                local rem = f.endTime - GetTime()
                if rem <= 0 then
                    CCSync:SetBarReady(container, f, f.currentSpellID)
                else
                    f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
                    if f.iconTimerText then
                        if container.elem.attachToParty then
                            f.iconTimerText:SetText(string.format("%.0f", rem))
                        else
                            f.iconTimerText:SetText("")
                        end
                    end
                end
            end)
        end
    end
end

if not CCSync.eventFrame then
    CCSync.eventFrame = CreateFrame("Frame")
    C_ChatInfo.RegisterAddonMessagePrefix(CCSync.commPrefix)
    
    CCSync.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            CCSync:OnCommReceived(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            CCSync:OnSpellcast(...)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" or event == "ACTIVE_COMBAT_CONFIG_CHANGED" then
            CCSync.cachedIsValidContext = CCSync:IsValidContext()
            CCSync:UpdateGroupTracking()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            CCSync.cachedIsValidContext = CCSync:IsValidContext()
            CCSync:UpdateGroupTracking()
            -- Dungeon/zone entry → broadcast spells
            if IsInGroup() then
                C_Timer.After(2, function()
                    CCSync:BroadcastSpells()
                end)
            end
        end
    end)
    CCSync:UpdateGroupTracking()
end

function CCSync:OnSpellcast(unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not self.ccIDLookup[spellID] then return end
    
    local name = UnitName(unit)
    if not name then return end
    
    local duration, source = self:ResolveCooldownDuration(spellID)
    if not duration or duration <= 0 then
        duration = DEFAULT_CC_COOLDOWN
    end
    DebugLog(self, string.format("OnSpellcast(player) spell=%d duration=%.2f source=%s", spellID, duration, tostring(source)))
    self:RememberObservedCooldown(spellID, duration, source)
    
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, name, spellID, duration)
    end
    
    self:SendSync(spellID, duration)
    self:AnnounceCC(spellID, duration)
    
    -- Some spells report only GCD/zero in the cast frame; resample shortly after and correct if needed.
    if source == "fallback" or source == "spell_fallback" then
        C_Timer.After(QUICK_RESAMPLE_DELAY, function()
            local refinedDuration, refinedSource = self:ResolveCooldownDuration(spellID)
            if not refinedDuration or refinedDuration <= 0 then return end
            if refinedSource == "fallback" or refinedSource == "spell_fallback" then return end
            if math.abs(refinedDuration - duration) < 0.5 then return end
            DebugLog(self, string.format("Resample refined spell=%d from=%.2f to=%.2f source=%s", spellID, duration, refinedDuration, tostring(refinedSource)))
            self:RememberObservedCooldown(spellID, refinedDuration, refinedSource)
            
            for _, container in ipairs(self.Instances) do
                self:UpdateBar(container, name, spellID, refinedDuration)
            end
            self:SendSync(spellID, refinedDuration)
        end)
    end
end

function CCSync:SendSync(spellID, duration, timestamp)
    if not IsInGroup() then return end
    if not duration or duration <= 0 then return end
    
    local ts = timestamp or GetServerTime()
    local msg = string.format("CC:%d:%.2f:%d", spellID, duration, ts)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    DebugLog(self, string.format("Sending sync: %s to %s", msg, channel))
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end

function CCSync:GetAnnouncementElement()
    return self.Instances[1] and self.Instances[1].elem
end

function CCSync:IsPartySyncEnabled()
    local elem = self:GetAnnouncementElement()
    if not elem then return true end
    if elem.partySync == nil then return true end
    return elem.partySync == true
end

function CCSync:GetAnnouncementChannel(elem)
    local channel = (elem and elem.announceChannel) or "PARTY"
    if channel == "INSTANCE" then channel = "INSTANCE_CHAT" end
    if channel == "PARTY" and not IsInGroup() then
        return nil
    end
    if channel == "INSTANCE_CHAT" and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if IsInGroup() then
            channel = "PARTY"
        else
            return nil
        end
    end
    return channel
end

function CCSync:FormatCCAnnouncement(spellID, duration, includeDuration)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = (spellInfo and spellInfo.name) or "CC"
    if includeDuration and duration and duration > 0 then
        return string.format("Used %s (CD: %ds)", spellName, math.floor(duration + 0.5))
    end
    return string.format("Used %s", spellName)
end

function CCSync:RenderLocalAnnouncement(senderName, spellID, duration, channel, includeDuration)
    local msg = self:FormatCCAnnouncement(spellID, duration, includeDuration)
    local channelName = (channel == "INSTANCE_CHAT") and "Instance" or "Party"
    local color = (channel == "INSTANCE_CHAT") and "|cffFF7F00" or "|cffAAAAFF"
    local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. (senderName or "Unknown") .. ": |r"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
    else
        print(msg)
    end
end

function CCSync:SendAnnouncementSync(spellID, duration, channel, includeDuration)
    if not IsInGroup() then return end
    local ts = GetServerTime()
    local c = channel or "PARTY"
    local d = duration or 0
    local inc = includeDuration and 1 or 0
    local msg = string.format("CCANN:%d:%.2f:%d:%s:%d", spellID, d, ts, c, inc)
    local syncChannel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, syncChannel)
end

function CCSync:AnnounceCC(spellID, duration)
    local elem = self:GetAnnouncementElement()
    if not elem or not elem.announceCCs then return end
    if not IsInGroup() then return end

    local channel = self:GetAnnouncementChannel(elem)
    if not channel then return end

    local senderName = UnitName("player") or "Unknown"
    -- Always virtual: render locally + sync to party so everyone renders client-side.
    self:RenderLocalAnnouncement(senderName, spellID, duration, channel, true)
    self:SendAnnouncementSync(spellID, duration, channel, true)
end

function CCSync:RenderSyncedCCAnnouncement(sender, spellID, duration, channel, includeDuration)
    local elem = self:GetAnnouncementElement()
    if not elem or not elem.announceCCs then return end
    if not IsInGroup() then return end
    self:RenderLocalAnnouncement(sender, spellID, duration, channel, includeDuration)
end

function CCSync:OnCommReceived(prefix, text, channel, sender)
    if prefix ~= self.commPrefix then return end
    if not self:IsPartySyncEnabled() then return end
    sender = Ambiguate(sender, "none")
    
    if sender == UnitName("player") then return end
    DebugLog(self, string.format("Received addon msg from %s via %s: %s", tostring(sender), tostring(channel), tostring(text)))
    
    local parts = {strsplit(":", text)}
    local cmd = parts[1]
    
    if cmd == "HELLO" then
        -- Someone said hello → respond with our spells
        C_Timer.After(0.3, function() CCSync:BroadcastSpells() end)
        
    elseif cmd == "SPELLS" then
        -- Someone shared their spell list
        local spells = {}
        for i = 2, #parts do
            local id = tonumber(parts[i])
            if id then table.insert(spells, id) end
        end
        self.knownSpells[sender] = spells
        -- Rebuild bars to show this player
        for _, container in ipairs(self.Instances) do
            self:InitializeGroupBars(container)
        end
        
    elseif cmd == "CC" then
        local spellID = tonumber(parts[2])
        local incDuration = tonumber(parts[3])
        local timestamp = tonumber(parts[4])
        
        if spellID then
            local duration = incDuration or 60
            local lag = math.max(0, GetServerTime() - (timestamp or 0))
            local adjDur = duration - lag
            DebugLog(self, string.format("Incoming CC sync sender=%s spell=%d duration=%.2f lag=%.2f adjusted=%.2f", tostring(sender), spellID, duration, lag, adjDur))
            
            if adjDur > 0 then
                for _, container in ipairs(self.Instances) do
                    self:UpdateBar(container, sender, spellID, adjDur)
                end
            end
        end
    elseif cmd == "CCANN" then
        local spellID = tonumber(parts[2])
        local incDuration = tonumber(parts[3]) or 0
        local ch = parts[5] or "PARTY"
        local includeDuration = tonumber(parts[6]) == 1
        if spellID then
            self:RenderSyncedCCAnnouncement(sender, spellID, incDuration, ch, includeDuration)
        end
    end
end

function CCSync:BroadcastActiveCCCooldowns()
    if not IsInGroup() then return end
    if #self.ccIDs == 0 then return end

    local now = GetTime()
    for _, spellID in ipairs(self.ccIDs) do
        local duration, source = self:ResolveCooldownDuration(spellID)
        if duration and duration >= MIN_VALID_CC_COOLDOWN then
            self:RememberObservedCooldown(spellID, duration, source)
        end
        if C_Spell and C_Spell.GetSpellCooldown then
            local cdInfo = C_Spell.GetSpellCooldown(spellID)
            if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
                local startTime = SafeNumber(cdInfo.startTime) or 0
                local duration = SafeNumber(cdInfo.duration) or 0
                local remaining = (startTime + duration) - now
                if duration > 0 and remaining > 0.15 then
                    DebugLog(self, string.format("Broadcast active CC spell=%d duration=%.2f remaining=%.2f source=%s", spellID, duration, remaining, tostring(source)))
                    self:SendSync(spellID, duration, GetServerTime())
                end
            end
        end
    end
end

function CCSync:QueueWarmupSync()
    self._warmupSerial = (self._warmupSerial or 0) + 1
    local serial = self._warmupSerial
    local function RunIfLatest()
        if serial ~= self._warmupSerial then return end
        CCSync:LoadClassCC()
        CCSync:ApplyRuntimeCooldownOverrides()
        CCSync:RefreshPlayerCCCooldownCache()
        CCSync:BroadcastSpells()
        CCSync:BroadcastActiveCCCooldowns()
    end
    C_Timer.After(0.05, RunIfLatest)
    C_Timer.After(0.60, RunIfLatest)
end

-- ============================================================================
-- 3. VISUALS & WIDGETFORGE INTEGRATION
-- ============================================================================

function CCSync:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.bars = {}
    
    container:SetScript("OnUpdate", function(self, elapsed)
         local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
         local isValidContext = CCSync.cachedIsValidContext
         
         if not isValidContext and not isUnlocked and not CCSync.ForceTest then
             self:Hide()
         else
             self:Show()
         end
         
         if self.bars then
             for _, bar in pairs(self.bars) do
                 if bar:GetParent() ~= self then
                     bar:SetAlpha((isValidContext or isUnlocked or CCSync.ForceTest) and 1 or 0)
                 else
                     bar:SetAlpha(1)
                 end
             end
         end
         
         if CCSync.ForceTest then
             self.testTimer = (self.testTimer or 0) - elapsed
             if self.testTimer <= 0 then
                 CCSync:Test(self, true)
                 self.testTimer = 10 
             end
             self.testActive = true
         else
             if self.testActive then
                 CCSync:Test(self, false)
                 self.testActive = false
                 self.testTimer = 0
             end
         end
    end)
    
    container:Show()
    table.insert(CCSync.Instances, container)
    self:InitializeGroupBars(container)
    
    -- Scan immediately when widget is added/enabled so it doesn't depend on opening settings.
    CCSync:QueueWarmupSync()
    
    container:SetScript("OnHide", function(self)
        for i, inst in ipairs(CCSync.Instances) do
            if inst == self then table.remove(CCSync.Instances, i); break end
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

function CCSync:CreateBar(container, name)
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
        row.info:SetPoint("LEFT", 4, 0)
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
    
    -- Icon overlay timer (for when attachToParty hides the main bar)
    row.iconTimerText = row.iconBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.iconTimerText:SetPoint("CENTER", row.iconBox, "CENTER", 0, 0)
    row.iconTimerText:SetFont(fontPath, fontSize * 1.2, "OUTLINE")
    row.iconTimerText:SetTextColor(1, 1, 1, 1)

    -- Icon overlay cooldown swipe
    row.cooldown = CreateFrame("Cooldown", nil, row.iconBox, "CooldownFrameTemplate")
    row.cooldown:SetAllPoints(row.iconBox)
    row.cooldown:SetDrawEdge(false)
    row.cooldown:SetDrawBling(false)
    row.cooldown:SetHideCountdownNumbers(true)
    row.cooldown:SetReverse(false)
    
    return row
end

function CCSync:SetBarReady(container, bar, spellID)
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116) -- Default to a generic CC icon
    bar.icon:SetDesaturated(false) -- Siyah beyazlığı kaldır
    
    if spellInfo and spellInfo.name then
        bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or "Unknown")
    end
    
    local c = elem.colorReady or {0.2, 0.8, 1.0, 1} -- Default Light Blue/Cyan for CC Ready
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    bar.timerBar:SetMinMaxValues(0, 1); bar.timerBar:SetValue(1)
    bar.timerText:SetText("READY")
    if bar.iconTimerText then bar.iconTimerText:SetText("") end
    if bar.cooldown then
        bar.cooldown:Clear()
        bar.cooldown:Hide()
    end
    
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

function CCSync:UpdateBar(container, senderName, spellID, duration)
    if ShouldHideOwnBar(container and container.elem, senderName) then return end

    local key = BuildBarKey(senderName, spellID)
    if not container.bars[key] then 
        local unitClass = nil
        if senderName == "StunBoi" then unitClass = "PALADIN"
        elseif senderName == "FreezeGal" then unitClass = "MAGE"
        elseif senderName == "SweepMaster" then unitClass = "MONK"
        elseif senderName == UnitName("player") then unitClass = select(2, UnitClass("player"))
        elseif IsInGroup() then
            for i=1, 40 do
                local u = (i <= 4) and "party"..i or "raid"..i
                if UnitName(u) == senderName then unitClass = select(2, UnitClass(u)) break end
            end
        end
        if unitClass then self:EnsureBarIsReady(container, senderName, unitClass, spellID) end
    end
    
    local bar = container.bars[key]
    if not bar then return end
    
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
    bar.icon:SetDesaturated(true) -- Bekleme süresindeyken siyah beyaz (gri) yap
    
    if spellInfo and spellInfo.name then
        bar.nameText:SetText((bar.playerName or "Unknown") .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or "Unknown")
    end
    
    local c = elem.colorOnCD or {1.0, 0.5, 0.0, 1} -- Default Orange for CC on cooldown
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    
    bar.endTime = GetTime() + duration
    bar.duration = duration
    bar.currentSpellID = spellID
    bar.ccSpellID = spellID
    
    self.activeCooldowns = self.activeCooldowns or {}
    self.activeCooldowns[key] = { spellID = spellID, endTime = bar.endTime, duration = duration }
    
    bar:Show()
    if bar.cooldown then
        if container.elem.attachToParty then
            bar.cooldown:SetCooldown(GetTime(), duration)
            bar.cooldown:Show()
        else
            bar.cooldown:Hide()
        end
    end
    
    bar:SetScript("OnUpdate", function(f)
        local rem = f.endTime - GetTime()
        if rem <= 0 then
            CCSync:SetBarReady(container, f, f.currentSpellID)
        else
            f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
            if f.iconTimerText then
                if container.elem.attachToParty then
                    f.iconTimerText:SetText(string.format("%.0f", rem))
                else
                    f.iconTimerText:SetText("")
                end
            end
        end
    end)
    self:LayoutBars(container)
end

local function FrameMatchesUnit(frame, unitId)
    if not frame or not unitId then return false end
    local unit = frame.unit
    if not unit and frame.GetAttribute then
        unit = frame:GetAttribute("unit")
    end
    local displayed = frame.displayedUnit
    return unit == unitId or displayed == unitId
end

local function FindDescendantFrameByUnit(root, unitId, requireVisible)
    if not root then return nil end
    local queue = {root}
    local index = 1
    local scanned = 0
    while queue[index] and scanned < 800 do
        local frame = queue[index]
        index = index + 1
        scanned = scanned + 1

        local visibleOK = (not requireVisible) or (frame.IsVisible and frame:IsVisible())
        if visibleOK and FrameMatchesUnit(frame, unitId) then
            return frame
        end

        if frame.GetChildren then
            local children = {frame:GetChildren()}
            for i = 1, #children do
                queue[#queue + 1] = children[i]
            end
        end
    end
    return nil
end

function CCSync:GetUnitFrame(unitName)
    if not unitName then return nil end
    local isPlayer = (unitName == UnitName("player"))

    -- Find which unitId corresponds to this name
    local unitId = nil
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local maxUnits = IsInRaid() and 40 or 4
        for i = 1, maxUnits do
            local u = prefix .. i
            if UnitName(u) == unitName then
                unitId = u
                break
            end
        end
    end

    if not unitId and isPlayer then
        unitId = "player"
    end
    
    if not unitId then return nil end
    
    -- ElvUI Party/Raid Frames
    if _G.ElvUF then
        -- Default group is PartyGroup1UnitButton1 etc
        for g = 1, 8 do
            for b = 1, 5 do
                local f = _G["ElvUF_PartyGroup"..g.."UnitButton"..b]
                if f and f:IsVisible() and f.unit == unitId then return f end
                
                f = _G["ElvUF_RaidGroup"..g.."UnitButton"..b]
                if f and f:IsVisible() and f.unit == unitId then return f end
                
                f = _G["ElvUF_Raid1Group"..g.."UnitButton"..b]
                if f and f:IsVisible() and f.unit == unitId then return f end
                
                f = _G["ElvUF_Raid2Group"..g.."UnitButton"..b]
                if f and f:IsVisible() and f.unit == unitId then return f end
                
                f = _G["ElvUF_Raid3Group"..g.."UnitButton"..b]
                if f and f:IsVisible() and f.unit == unitId then return f end
            end
        end
    end
    
    -- Blizzard Compact Party/Raid Frames
    for i = 1, 40 do
        local f = _G["CompactPartyFrameMember"..i]
        if f and f:IsVisible() and (f.unit == unitId or f.displayedUnit == unitId) then return f end
        
        f = _G["CompactRaidFrame"..i]
        if f and f:IsVisible() and (f.unit == unitId or f.displayedUnit == unitId) then return f end
    end
    
    -- Classic Blizzard Party Frames
    for i = 1, 4 do
        local f = _G["PartyMemberFrame"..i]
        if f and f:IsVisible() and f.unit == unitId then return f end
    end

    -- Dynamic Blizzard fallback: retail layouts can nest/rename party member frames.
    local roots = {
        _G.CompactPartyFrame,
        _G.CompactRaidFrameContainer,
        _G.CompactRaidGroup1,
        _G.PartyFrame,
    }
    for i = 1, #roots do
        local f = FindDescendantFrameByUnit(roots[i], unitId, true)
        if f then return f end
    end

    -- Fallback for player when no party/raid unit frame matched.
    if isPlayer then
        if ElvUF_Player and ElvUF_Player:IsVisible() then return ElvUF_Player end
        if PlayerFrame and PlayerFrame:IsVisible() then return PlayerFrame end
        if self.ForceTest then
            return PlayerFrame or UIParent
        end
    end
    
    return nil
end

function CCSync:LayoutBars(container)
    local elem = container.elem
    local prev = nil
    local spacing = elem.spacing or 5
    local sortedKeys = {}
    local attachMode = elem.attachToParty == true
    local ownerStackIndex = {}
    
    for key, _ in pairs(container.bars) do table.insert(sortedKeys, key) end
    table.sort(sortedKeys)
    
    local yOffset = 0
    
    for _, key in ipairs(sortedKeys) do
        local bar = container.bars[key]
        if ShouldHideOwnBar(elem, bar.playerName) then
            bar:Hide()
        else
            if not bar:IsShown() then
                bar:Show()
            end

            bar:ClearAllPoints()
             
            if attachMode then
                    -- Find party frame
                    local ownerName = bar.playerName
                    local targetFrame = self:GetUnitFrame(ownerName)
                    
                    -- If testing and frame not found, fallback to anchoring to UIParent center or stack locally
                    if not targetFrame and self.ForceTest then
                        if ownerName == UnitName("player") then
                            targetFrame = PlayerFrame or UIParent
                        else
                            -- For dummy test targets, just stack them temporarily so they are visible
                            bar:SetParent(container)
                            bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                            bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                            if not prev then 
                                bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                            else 
                                bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) 
                            end
                            prev = bar
                        end
                    end
                    
                    if targetFrame and not (self.ForceTest and not targetFrame and ownerName ~= UnitName("player")) then
                        if bar:GetParent() ~= targetFrame then
                            bar:SetParent(targetFrame)
                        end
                        bar:SetFrameStrata(targetFrame:GetFrameStrata() or "MEDIUM")
                        bar:SetFrameLevel((targetFrame:GetFrameLevel() or 1) + 10)
                        
                    local offX = elem.partyOffsetX or 5
                    local offY = elem.partyOffsetY or 0
                    local side = elem.partyAttachSide or "RIGHT"      -- RIGHT / LEFT / TOP / BOTTOM
                    local grow = elem.partyGrowDirection or "HORIZONTAL" -- HORIZONTAL / VERTICAL
                    local stack = ownerStackIndex[ownerName] or 0

                    local point, relPoint = "LEFT", "RIGHT"
                    local dirX, dirY = 1, 0
                    if side == "LEFT" then
                        point, relPoint = "RIGHT", "LEFT"
                        dirX, dirY = -1, 0
                    elseif side == "TOP" then
                        point, relPoint = "BOTTOM", "TOP"
                        dirX, dirY = 1, 0
                    elseif side == "BOTTOM" then
                        point, relPoint = "TOP", "BOTTOM"
                        dirX, dirY = 1, 0
                    end

                    if grow == "VERTICAL" then
                        dirX = 0
                        if side == "TOP" then
                            dirY = 1
                        else
                            dirY = -1
                        end
                    else
                        dirY = 0
                    end

                    local step = ((grow == "VERTICAL") and (bar:GetHeight() or (elem.iconSize or 24)) or (bar:GetWidth() or (elem.iconSize or 24))) + spacing
                    bar:SetPoint(point, targetFrame, relPoint, offX + (stack * step * dirX), offY + (stack * step * dirY))
                    ownerStackIndex[ownerName] = stack + 1
                else
                        -- If frame is not currently resolvable, keep icon visible in container stack
                        -- instead of disappearing completely.
                        if bar:GetParent() ~= container then
                            bar:SetParent(container)
                        end
                        bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                        bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                        if not prev then
                            bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                        else
                            bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
                        end
                        prev = bar
                    end
                    
                    -- Disable clicks so it doesn't block party frame interaction
                    bar:EnableMouse(false)
            else
                -- Classic Bar Stack layout
                if bar:GetParent() ~= container then
                    bar:SetParent(container)
                end
                bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                bar:EnableMouse(true)
                if not prev then 
                    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                else 
                    bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) 
                end
                prev = bar
            end
        end
    end
    
    if attachMode then
        container:SetSize(1, 1) -- Hide virtual container
    else
        if prev then
            local height = select(4, prev:GetPoint())
            container:SetHeight(math.abs(height) + prev:GetHeight() + spacing)
        else
            container:SetHeight(1)
        end
    end
end

function CCSync:Test(container, on)
    if on then
        self:UpdateBar(container, "StunBoi", 853, 60) -- HoJ
        self:UpdateBar(container, "FreezeGal", 122, 30) -- Frost Nova
        self:UpdateBar(container, "SweepMaster", 119381, 60) -- Leg Sweep
    else
        for key, bar in pairs(container.bars) do
            if bar.playerName == "StunBoi" or bar.playerName == "FreezeGal" or bar.playerName == "SweepMaster" then
                bar:Hide()
                container.bars[key] = nil
            end
        end
        self:InitializeGroupBars(container)
    end
end

function CCSync:RefreshBars(container)
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
        local attachMode = elem.attachToParty == true
        
        if attachMode then
            local iconPad = showIconBorder and iconBSize or 0
            row:SetSize(iconSize + (iconPad*2), iconSize + (iconPad*2))
            row.info:Hide()
            row.classStrip:Hide()
            if showIcon then row.iconBox:Show() else row.iconBox:Hide() end
        else
            row.info:Show()
            row.classStrip:Show()
            local rowHeight = math.max(height, showIcon and iconSize or 0)
            row:SetSize(width, rowHeight)
            
            if showIcon then
                row.info:SetPoint("LEFT", row.iconBox, "RIGHT", iconSpacing, 0)
                row.classStrip:ClearAllPoints()
                row.classStrip:SetPoint("TOPRIGHT", row.iconBox, "TOPLEFT", -1, 0)
                row.classStrip:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMLEFT", -1, 0)
            else
                row.info:SetPoint("LEFT", 4, 0)
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
        end
        
        row.iconBox:SetSize(iconSize, iconSize)
        row.iconBox:ClearAllPoints()
        row.iconBox:SetPoint("LEFT", attachMode and 0 or 4, 0)
        
        local Skin = _G.ForgeSkin
        if Skin then Skin:ApplyBackdrop(row.iconBox) end
        row.iconBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
        row.iconBox:SetBackdropColor(0.1, 0.1, 0.1, attachMode and 1 or barBgAlpha)
        if showIconBorder then
            row.iconBox:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
        else
            row.iconBox:SetBackdropBorderColor(0, 0, 0, 0)
        end
        
        local iconPad = showIconBorder and iconBSize or 0
        local iconMargin = iconPad + 1
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", iconMargin, -iconMargin)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -iconMargin, iconMargin)
        row.icon:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)
        
        if row:GetScript("OnUpdate") then
             local c = elem.colorOnCD or {1.0, 0.5, 0.0, 1}
             row.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
             if row.cooldown then
                 if attachMode then
                     local startTime = row.endTime - row.duration
                     row.cooldown:SetCooldown(startTime, row.duration)
                     row.cooldown:Show()
                 else
                     row.cooldown:Hide()
                 end
             end
        else
             local c = elem.colorReady or {0.2, 0.8, 1.0, 1}
             row.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
             if row.cooldown then row.cooldown:Hide() end
        end
        count = count + 1
    end
    
    local maxH = math.max(height, showIcon and iconSize or 0)
    local spacing = elem.spacing or 5
    if not elem.attachToParty then
        container:SetSize(width, math.max(1, (count * maxH) + (math.max(0, count - 1) * spacing)))
    end
    self:LayoutBars(container)
end

function CCSync:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local Skin = _G.ForgeSkin
    
    parentFrame.isTestingGlobal_CCSync = parentFrame.isTestingGlobal_CCSync or false
    
    local function RefreshLive()
        for _, inst in ipairs(CCSync.Instances) do
             if inst.elem == elem then
                 CCSync:InitializeGroupBars(inst)
                 local bars = WidgetForge:GetBarFrames()
                 for index, bar in pairs(bars) do
                     if bar.customWidgets then
                         for _, cw in ipairs(bar.customWidgets) do
                              if cw.elem == elem then
                                 if WidgetForge.UpdateBarValues then WidgetForge:UpdateBarValues(index) end
                              end
                         end
                     end
                 end
             end
        end
    end

    if not _G.WidgetForgeUtils or not _G.WidgetForgeUtils.CreateSettingsBuilder then return end
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb

    -- Entering widget settings is a safe point to refresh and sync current CC cooldown state.
    CCSync:QueueWarmupSync()
    
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
    sb:AddColor("colorReady", "Available Color (Ready)", {0.2, 0.8, 1.0, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", "Cooldown Color (Busy)", {1.0, 0.5, 0.0, 1}, elem, RefreshLive)


    if not parentFrame.testBtnCCSync then
        local btnTest = Skin:CreateButton(f.content, "Test Mode: OFF", 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnCCSync = btnTest
        
        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal_CCSync then 
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
            if parentFrame.isTestingGlobal_CCSync then btnTest:SetBackdropColor(0, 1, 0, 1) 
            else btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
        end)
        btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
        
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal_CCSync = not parentFrame.isTestingGlobal_CCSync
            UpdateTestButtonVisuals()
            CCSync.ForceTest = parentFrame.isTestingGlobal_CCSync
            RefreshLive()
        end)
        
        parentFrame.onCloseWidgetSpecific = function() 
            parentFrame.isTestingGlobal_CCSync = false
            CCSync.ForceTest = false
        end
    else
        if parentFrame.testBtnCCSync then
            parentFrame.testBtnCCSync:Show()
        end
    end

    sb:AddHeader("Party Frame Integration")
    sb:AddSwitch("attachToParty", "Attach Icons to Party Frames\n(Disables standalone bar layout)", false, elem, RefreshLive)
    sb:AddDropdown("partyAttachSide", "Attach Side", {
        {text = "Right", value = "RIGHT"},
        {text = "Left", value = "LEFT"},
        {text = "Top", value = "TOP"},
        {text = "Bottom", value = "BOTTOM"},
    }, "RIGHT", elem, RefreshLive)
    sb:AddDropdown("partyGrowDirection", "Icon Flow Direction", {
        {text = "Horizontal", value = "HORIZONTAL"},
        {text = "Vertical", value = "VERTICAL"},
    }, "HORIZONTAL", elem, RefreshLive)
    sb:AddSlider("partyOffsetX", "X Offset", -100, 100, 1, 5, elem, RefreshLive)
    sb:AddSlider("partyOffsetY", "Y Offset", -100, 100, 1, 0, elem, RefreshLive)

    sb:AddHeader("Announcements")
    sb:AddSwitch("announceCCs", "Announce my CC casts", false, elem, RefreshLive)
    sb:AddDropdown("announceChannel", "Announce Channel", {
        {text = "Party", value = "PARTY"},
        {text = "Instance", value = "INSTANCE_CHAT"}
    }, "PARTY", elem, RefreshLive)

    sb:AddHeader("Party Sync")
    sb:AddSwitch("hideOwnCC", "Hide My Own CC Bars", false, elem, RefreshLive)
    sb:AddSwitch("partySync", "Listen to party CC abilities", true, elem, RefreshLive)
    
    local txtHelp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtHelp:SetWordWrap(true)
    txtHelp:SetWidth(600)
    txtHelp:SetJustifyH("LEFT")
    txtHelp:SetTextColor(1, 0.82, 0)
    txtHelp:SetText("Note: For the Party Sync to function correctly and track your group members' CC abilities, all players in the party MUST have the WidgetForge addon installed.")
    
    sb.y = sb.y - 0
    txtHelp:SetPoint("TOPLEFT", sb.canvas, "TOPLEFT", 12, sb.y)
    
    sb.y = sb.y - 0
    
    sb:Finish()
end

function CCSync:TogglePreview(state)
    CCSync.ForceTest = state
end

-- ============================================================================
-- 4. REGISTER WIDGET WITH CORE
-- ============================================================================
local fLoad = CreateFrame("Frame")
fLoad:RegisterEvent("ADDON_LOADED")
fLoad:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        if _G.WidgetForge and _G.WidgetForge.RegisterWidgetType then
            _G.WidgetForge:RegisterWidgetType({
                typeID = "ccsync",
                name = "Crowd Control Sync (Group CCs)",
                description = "Automatically tracks and syncs Party Crowd Control abilities just like the interrupt tracker.",
                Load = function(_, parent, elem) return CCSync:Load(parent, elem) end,
                CreateSettings = function(_, parentFrame) CCSync:CreateSettings(parentFrame) end,
                TogglePreview = function(_, state) CCSync:TogglePreview(state) end,
                defaultConfig = {
                    barWidth = 200,
                    barHeight = 24,
                    iconSize = 24,
                    spacing = 2,
                    showIcon = true,
                    colorReady = {0.2, 0.8, 1.0, 1},
                    colorOnCD = {1.0, 0.5, 0.0, 1},
                    attachToParty = false,
                    partyAttachSide = "RIGHT",
                    partyGrowDirection = "HORIZONTAL",
                    announceCCs = false,
                    announceChannel = "PARTY",
                    hideOwnCC = false,
                    partyOffsetX = 5,
                    partyOffsetY = 0,
                }
            })
        end
    end
end)
