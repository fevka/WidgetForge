local addonName, addonTable = ...
local L = WFL
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
local MIN_VALID_INTERRUPT_COOLDOWN = 1.0
local SUCCESS_CDR_WINDOW = 2.0
local SUCCESS_MATCH_WINDOW = 1.0
local BASE_DISPATCH_DELAY = 0.22
local DK_MIND_FREEZE_SPELL_ID = 47528
local DK_SUCCESS_CDR_SECONDS = 3
local DK_COLDTHIRST_TALENT_NAME = "Coldthirst"
local DK_COLDTHIRST_TALENT_ID = 378848
function InterruptSync:HasActiveInstances()
    return self.Instances and #self.Instances > 0
end
function InterruptSync:UpdateSpecTracker()
    if not self.specTrackerFrame then return end
    self.specTrackerFrame:UnregisterAllEvents()
    if not self:HasActiveInstances() then return end
    self.specTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.specTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
local function CopyArray(values)
    if type(values) ~= "table" then return nil end
    local copy = {}
    for i, value in ipairs(values) do
        copy[i] = value
    end
    return copy
end
local function CopyMap(values)
    if type(values) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(values) do
        copy[key] = value
    end
    return copy
end
local function CopyModifiers(modifiers)
    if type(modifiers) ~= "table" then return nil end
    local copy = {}
    for index, modifier in ipairs(modifiers) do
        copy[index] = {
            talent = modifier.talent,
            reduction = modifier.reduction,
            reductionBySpec = CopyMap(modifier.reductionBySpec),
            ranks = modifier.ranks and CopyArray(modifier.ranks) or nil,
        }
    end
    return copy
end
local INTERRUPT_TRACKED_SPELLS = {
    { id = 6552,   name = "Pummel",             class = "WARRIOR",      fallbackCooldown = 15 },
    { id = 1766,   name = "Kick",               class = "ROGUE",        fallbackCooldown = 15 },
    { id = 2139,   name = "Counterspell",       class = "MAGE",         fallbackCooldown = 24 },
    { id = 47528,  name = "Mind Freeze",        class = "DEATHKNIGHT",  fallbackCooldown = 15 },
    { id = 96231,  name = "Rebuke",             class = "PALADIN",      fallbackCooldown = 15 },
    { id = 116705, name = "Spear Hand Strike",  class = "MONK",         fallbackCooldown = 15 },
    { id = 183752, name = "Disrupt",            class = "DEMONHUNTER",  fallbackCooldown = 15, lookupNames = {"Disrupt", "Consume Magic"} },
    { id = 351338, name = "Quell",              class = "EVOKER",       fallbackCooldown = 20 },
    { id = 119914, name = "Command Demon",      class = "WARLOCK",      fallbackCooldown = 24, lookupNames = {"Command Demon", "Spell Lock"} },
    { id = 132409, name = "Spell Lock",         class = "WARLOCK",      fallbackCooldown = 24, lookupNames = {"Spell Lock", "Command Demon"} },
    { id = 19647,  name = "Spell Lock",         class = "WARLOCK",      fallbackCooldown = 24, lookupNames = {"Spell Lock", "Command Demon"} },
    { id = 57994,  name = "Wind Shear",         class = "SHAMAN",       fallbackCooldown = 12, cooldownBySpec = { [264] = 30 } },
    { id = 15487,  name = "Silence",            class = "PRIEST",       specIndex = 3, fallbackCooldown = 45 },
    { id = 147362, name = "Counter Shot",       class = "HUNTER",       fallbackCooldown = 24 },
    { id = 187707, name = "Muzzle",             class = "HUNTER",       specIndex = 3, fallbackCooldown = 15 },
    { id = 106839, name = "Skull Bash",         class = "DRUID",        fallbackCooldown = 15 },
    { id = 78675,  name = "Solar Beam",         class = "DRUID",        specIndex = 1, fallbackCooldown = 60 },
}
local INTERRUPT_DATA = {}
local INTERRUPT_COOLDOWN_FALLBACK = {}
local STATIC_INTERRUPT_COOLDOWN_FALLBACK = {}
local INTERRUPT_COOLDOWN_RULES = {}
local INTERRUPT_NAME_COOLDOWN_FALLBACK = {}
local INTERRUPT_SPELL_DATA = {}
local INTERRUPT_SPELL_NAME_LOOKUP = {}
for _, entry in ipairs(INTERRUPT_TRACKED_SPELLS) do
    local classData = INTERRUPT_DATA[entry.class]
    if not classData then
        classData = {}
        INTERRUPT_DATA[entry.class] = classData
    end
    local bucketKey = entry.specIndex or "DEFAULT"
    local bucket = classData[bucketKey]
    if not bucket then
        bucket = { ids = {}, names = {} }
        classData[bucketKey] = bucket
    end
    table.insert(bucket.ids, entry.id)
    table.insert(bucket.names, entry.name)
    bucket.spellName = bucket.spellName or entry.name
    INTERRUPT_SPELL_DATA[entry.id] = entry.name
    INTERRUPT_SPELL_NAME_LOOKUP[entry.name] = INTERRUPT_SPELL_NAME_LOOKUP[entry.name] or entry.id
    if type(entry.lookupNames) == "table" then
        for _, lookupName in ipairs(entry.lookupNames) do
            table.insert(bucket.names, lookupName)
            INTERRUPT_SPELL_NAME_LOOKUP[lookupName] = INTERRUPT_SPELL_NAME_LOOKUP[lookupName] or entry.id
        end
    end
    if entry.fallbackCooldown then
        INTERRUPT_COOLDOWN_FALLBACK[entry.id] = entry.fallbackCooldown
        STATIC_INTERRUPT_COOLDOWN_FALLBACK[entry.id] = entry.fallbackCooldown
    end
    if entry.cooldownBySpec or entry.cdModifiers then
        INTERRUPT_COOLDOWN_RULES[entry.id] = {
            cooldownBySpec = CopyMap(entry.cooldownBySpec),
            cdModifiers = CopyModifiers(entry.cdModifiers),
        }
    end
end
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
    if value == nil then return nil end
    local s = tostring(value)
    local n = tonumber(s)
    if type(n) == "number" then return n end
    local ok, num = pcall(function() return tonumber(value) end)
    if ok and type(num) == "number" then return tonumber(tostring(num)) end
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
        if n > 1000 then return n / 1000 end
        return n
    end
    if type(baseCooldownInfo) == "table" then
        local ms = SafeNumber(baseCooldownInfo.baseCooldownMS)
            or SafeNumber(baseCooldownInfo.cooldownMS)
            or SafeNumber(baseCooldownInfo.durationMS)
        if ms and ms > 0 then
            return ms / 1000
        end
        local sec = SafeNumber(baseCooldownInfo.baseCooldown)
            or SafeNumber(baseCooldownInfo.cooldown)
            or SafeNumber(baseCooldownInfo.duration)
        if sec and sec > 0 then
            if sec > 1000 then return sec / 1000 end
            return sec
        end
    end
    return nil
end
local function DebugLog(self, msg)
    return
end
function InterruptSync:HasTalentSpell(talentSpellID)
    if not talentSpellID then return false end
    local now = GetTime()
    self._talentCacheAt = self._talentCacheAt or {}
    self._talentCacheValue = self._talentCacheValue or {}
    local cachedAt = self._talentCacheAt[talentSpellID] or 0
    if (now - cachedAt) < 0.2 then
        return self._talentCacheValue[talentSpellID] and true or false
    end
    local known = false
    if IsPlayerSpell and IsPlayerSpell(talentSpellID) then known = true end
    if not known and IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(talentSpellID) then known = true end
    if not known and IsSpellKnown and IsSpellKnown(talentSpellID) then known = true end
    self._talentCacheAt[talentSpellID] = now
    self._talentCacheValue[talentSpellID] = known and true or false
    DebugLog(self, string.format("Talent check: spellID=%s active=%s", tostring(talentSpellID), tostring(self._talentCacheValue[talentSpellID])))
    return self._talentCacheValue[talentSpellID]
end
function InterruptSync:GetPlayerSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    return GetSpecializationInfo(specIndex)
end
function InterruptSync:HasColdthirstTalent()
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then return false end
    local known = self:HasTalentSpell(DK_COLDTHIRST_TALENT_ID) and true or false
    DebugLog(self, string.format("Coldthirst check: spellID=%s active=%s", tostring(DK_COLDTHIRST_TALENT_ID), tostring(known)))
    return known
end
function InterruptSync:GetBaseCooldownDuration(spellID)
    if not spellID then return nil end
    local function ProbeBaseCooldown(fetcher)
        if type(fetcher) ~= "function" then return nil end
        local ok, raw = pcall(fetcher, spellID)
        if not ok then return nil end
        local seconds = ExtractBaseCooldownSeconds(raw)
        if seconds and SafeGreaterThan(seconds, self:GetCurrentGCD() + GCD_EPSILON) then
            return RoundTo2(seconds) or seconds
        end
        return nil
    end
    local base = ProbeBaseCooldown(GetSpellBaseCooldown)
    if base then return base end
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        base = ProbeBaseCooldown(C_Spell.GetSpellBaseCooldown)
        if base then return base end
    end
    return nil
end
function InterruptSync:GetAdjustedInterruptBaseCooldownDuration(spellID)
    local base = self:GetBaseCooldownDuration(spellID)
    if not base then return nil, nil, nil end
    local adjusted = base
    local source = "base"
    local rule = INTERRUPT_COOLDOWN_RULES[spellID]
    local specID = self:GetPlayerSpecID()
    if rule and rule.cooldownBySpec and specID and rule.cooldownBySpec[specID] then
        adjusted = SafeNumber(rule.cooldownBySpec[specID]) or adjusted
        source = "base_spec"
    end
    if rule and type(rule.cdModifiers) == "table" then
        for _, modifier in ipairs(rule.cdModifiers) do
            local reduction = nil
            if modifier.talent and self:HasTalentSpell(modifier.talent) then
                reduction = (modifier.reductionBySpec and specID and modifier.reductionBySpec[specID]) or modifier.reduction
            elseif type(modifier.ranks) == "table" then
                for _, rank in ipairs(modifier.ranks) do
                    if rank.talent and self:HasTalentSpell(rank.talent) then
                        reduction = rank.reduction
                        break
                    end
                end
            end
            reduction = SafeNumber(reduction)
            if reduction and reduction > 0 then
                adjusted = math.max(MIN_VALID_INTERRUPT_COOLDOWN, adjusted - reduction)
                source = (source == "base_spec") and "base_spec_talent" or "base_talent"
            end
        end
    end
    adjusted = RoundTo2(adjusted) or adjusted
    if adjusted and SafeGreaterThan(adjusted, self:GetCurrentGCD() + GCD_EPSILON) then
        return adjusted, source, base
    end
    return nil, nil, base
end
local function ClearInterruptNameFallbackFromID(id)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        INTERRUPT_NAME_COOLDOWN_FALLBACK[info.name] = nil
    end
end
function InterruptSync:GetLiveRemainingCooldown(spellID)
    if not C_Spell then return nil end
    if C_Spell.GetSpellCooldownDuration then
        local rem = SafeNumber(C_Spell.GetSpellCooldownDuration(spellID))
        if rem and rem > 0 then
            return rem
        end
    end
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
            local trustedBase = select(1, self:GetAdjustedInterruptBaseCooldownDuration(sid))
            if trustedBase and math.abs(dur - trustedBase) > 0.01 then
                db[spellIDStr] = nil
                INTERRUPT_COOLDOWN_FALLBACK[sid] = nil
                ClearInterruptNameFallbackFromID(sid)
                DebugLog(self, string.format("Removed stale runtime override spell=%d duration=%.2f trusted=%.2f", sid, dur, trustedBase))
                allow = false
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
    if source ~= "base" and source ~= "base_spec" and source ~= "base_talent" and source ~= "base_spec_talent" then return end
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
    local adjustedBase, adjustedSource = self:GetAdjustedInterruptBaseCooldownDuration(spellID)
    if adjustedBase then
        return adjustedBase, adjustedSource
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
function InterruptSync:GetCachedInterruptCooldownDuration(spellID)
    if not spellID then return DEFAULT_INTERRUPT_COOLDOWN, "fallback" end
    local cached = SafeNumber(INTERRUPT_COOLDOWN_FALLBACK[spellID])
    if cached and cached >= MIN_VALID_INTERRUPT_COOLDOWN then
        return cached, "spell_fallback"
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        local byName = info and info.name and SafeNumber(INTERRUPT_NAME_COOLDOWN_FALLBACK[info.name])
        if byName and byName >= MIN_VALID_INTERRUPT_COOLDOWN then
            return byName, "name_fallback"
        end
    end
    local staticBase = SafeNumber(STATIC_INTERRUPT_COOLDOWN_FALLBACK[spellID])
    if staticBase and staticBase >= MIN_VALID_INTERRUPT_COOLDOWN then
        return staticBase, "static_fallback"
    end
    return DEFAULT_INTERRUPT_COOLDOWN, "fallback"
end
function InterruptSync:IsPartySyncEnabled()
    local elem = self.Instances[1] and self.Instances[1].elem
    return elem and elem.partySync
end
InterruptSync.interruptIDs = {}
function InterruptSync:LoadClassInterrupt()
    local class = select(2, UnitClass("player"))
    local data = INTERRUPT_DATA[class]
    if not data then self.interruptIDs = {}; return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex] or data.DEFAULT
    self.interruptIDs = {}
    if specData and specData.ids then
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
        if #self.interruptIDs < #specData.ids and specData.names then
            for _, spellName in ipairs(specData.names) do
                local info = C_Spell.GetSpellInfo(spellName)
                if info and info.spellID then
                    local id = info.spellID
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
InterruptSync.specTrackerFrame = specTrackerFrame
specTrackerFrame:SetScript("OnEvent", function(_, event)
    if not InterruptSync:HasActiveInstances() then return end
    DebugLog(InterruptSync, "Spec tracker event: " .. tostring(event))
    InterruptSync:RunLearnScan()
end)
InterruptSync:UpdateSpecTracker()
InterruptSync.lastInterruptSpellID = nil
InterruptSync.lastInterruptTime = 0
InterruptSync.coldthirstEnabled = false
function InterruptSync:IsValidContext()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or (instanceType ~= "party" and instanceType ~= "scenario") then
        return false
    end
    if IsInRaid() then
        return false
    end
    return true
end
function InterruptSync:RefreshColdthirstState(reason)
    local _, classToken = UnitClass("player")
    self._talentCacheAt = {}
    self._talentCacheValue = {}
    if classToken ~= "DEATHKNIGHT" then
        self.coldthirstEnabled = false
        DebugLog(self, string.format("Coldthirst cache refresh (%s): false (not DK)", tostring(reason)))
        return
    end
    self.coldthirstEnabled = self:HasColdthirstTalent() and true or false
    DebugLog(self, string.format("Coldthirst cache refresh (%s): %s", tostring(reason), tostring(self.coldthirstEnabled)))
end
function InterruptSync:UpdateGroupTracking()
    self.eventFrame:UnregisterAllEvents()
    if not self:HasActiveInstances() then
        self.cachedIsValidContext = false
        return
    end
    self:LoadClassInterrupt()
    self:ApplyRuntimeCooldownOverrides()
    self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    self.cachedIsValidContext = self:IsValidContext()
    self.eventFrame:RegisterEvent("CHAT_MSG_PARTY")
    self.eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, container in ipairs(self.Instances) do
        self:InitializeGroupBars(container)
    end
end
function InterruptSync:RefreshPlayerInterruptCooldownCache()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if #self.interruptIDs == 0 then return end
    local gcd = self:GetCurrentGCD()
    DebugLog(self, string.format("Refresh cache: interrupts=%d gcd=%.2f", #self.interruptIDs, gcd))
    for _, spellID in ipairs(self.interruptIDs) do
        local duration, source = self:GetAdjustedInterruptBaseCooldownDuration(spellID)
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
function InterruptSync:UpdateTargetInterruptWatcher()
    self:InitializeTargetInterruptWatcher()
    local f = self.targetInterruptWatcher
    if not f then return end
    f:UnregisterAllEvents()
    if not self:HasActiveInstances() then
        f.isInterrupted = false
        f.interruptTime = 0
        return
    end
    f:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "target")
    f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
end
function InterruptSync:RefreshRuntimeState()
    self:UpdateSpecTracker()
    self:UpdateTargetInterruptWatcher()
    self:UpdateGroupTracking()
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
    if ShouldTrack("player") and #self.interruptIDs > 0 then
        local name = UnitName("player")
        if name then
            self:EnsureBarIsReady(container, name, select(2, UnitClass("player")))
            activeNames[name] = true
        end
    end
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
        local specData = INTERRUPT_DATA[class].DEFAULT or {}
        local spellID = specData.ids and specData.ids[1] or 0
        self:SetBarReady(container, row, spellID)
    end
    self.activeCooldowns = self.activeCooldowns or {}
    local mem = self.activeCooldowns[name]
    if mem and mem.endTime and mem.endTime > GetTime() then
        local bar = container.bars[name]
        if bar and not bar:GetScript("OnUpdate") then
            bar.endTime = mem.endTime
            bar.duration = mem.duration
            bar.currentSpellID = mem.spellID
            local spellInfo = C_Spell.GetSpellInfo(mem.spellID)
            bar.icon:SetTexture(spellInfo and spellInfo.iconID or 134400)
            bar.icon:SetDesaturated(true)
            if spellInfo and spellInfo.name then
                bar.nameText:SetText((bar.playerName or L("LABEL_UNKNOWN")) .. " - " .. spellInfo.name)
            else
                bar.nameText:SetText(bar.playerName or L("LABEL_UNKNOWN"))
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
    C_ChatInfo.RegisterAddonMessagePrefix(InterruptSync.commPrefix)
    InterruptSync.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            InterruptSync:OnCommReceived(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            InterruptSync:OnSpellcast(...)
        elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
            InterruptSync:OnPartyChat(...)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
            InterruptSync.cachedIsValidContext = InterruptSync:IsValidContext()
            InterruptSync:UpdateGroupTracking()
            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
                InterruptSync:RunLearnScan()
            end
        end
    end)
    InterruptSync:RefreshRuntimeState()
end
function InterruptSync:OnSpellcast(unit, castGUID, spellID)
    if unit ~= "player" then 
        return 
    end
    DebugLog(self, string.format("OnSpellcast(player) spellID=%s", tostring(spellID)))
    if not INTERRUPT_SPELL_DATA[spellID] then 
        return 
    end
    local duration, source = self:GetCachedInterruptCooldownDuration(spellID)
    if not duration or duration <= 0 then duration = DEFAULT_INTERRUPT_COOLDOWN end
    local name = UnitName(unit)
    if not name then 
        return 
    end
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
        self:SendSync(spellID, duration)
        self:AnnounceInterrupt(spellID, duration)
    end
end
function InterruptSync:ShouldDelayInitialDispatchForMindFreeze(spellID)
    if spellID ~= DK_MIND_FREEZE_SPELL_ID then return false end
    local _, classToken = UnitClass("player")
    if classToken ~= "DEATHKNIGHT" then return false end
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
function InterruptSync:OnPartyChat(text, playerName, ...)
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.partySync then return end
    playerName = Ambiguate(playerName, "none")
    if playerName == UnitName("player") then
        return
    end
    local spellName = text:match("Interrupted with ([^!]+)!")
    if not spellName then return end
    local spellID = INTERRUPT_SPELL_NAME_LOOKUP[spellName]
    if not spellID then
        return
    end
    local duration = self:GetCachedInterruptCooldownDuration(spellID)
    if type(duration) ~= "number" or duration <= 0 then duration = DEFAULT_INTERRUPT_COOLDOWN end
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, playerName, spellID, duration)
    end
end
function InterruptSync:ReportInterruptSuccess(targetUnit, interruptSpellID, castToken)
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
        local channelName = (channel == "INSTANCE_CHAT") and "Instance" or "Party"
        local color = (channel == "INSTANCE_CHAT") and "|cffFF7F00" or "|cffAAAAFF" 
        local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. UnitName("player") .. ": |r"
        DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
    else
        SendChatMessage(msg, channel)
    end
end
function InterruptSync:AnnounceInterrupt(spellID, duration)
    local elem = self.Instances[1] and self.Instances[1].elem
    if not elem or not elem.announceInterrupts then return end
    if not IsInGroup() then return end
    if not duration or duration <= 0 then duration = 15 end
    local channel = elem.announceChannel or "PARTY"
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = spellInfo and spellInfo.name or "Interrupt"
    local msg = string.format("Interrupted with %s! (CD: %ds)", spellName, duration)
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
    if not self:HasActiveInstances() then return end
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
        local duration = incDuration or self:GetCachedInterruptCooldownDuration(spellID)
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
    if not self:HasActiveInstances() then return end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not IsInGroup() then return end
    if #self.interruptIDs == 0 then return end
    local now = GetTime()
    local playerName = UnitName("player")
    if not playerName then return end
    for _, spellID in ipairs(self.interruptIDs) do
        local duration, source = self:GetAdjustedInterruptBaseCooldownDuration(spellID)
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
                    for _, container in ipairs(self.Instances) do
                        self:UpdateBar(container, playerName, spellID, remaining)
                    end
                    self:SendSync(spellID, remaining, GetServerTime())
                end
            end
        end
    end
end
function InterruptSync:RunLearnScan()
    if not self:HasActiveInstances() then return end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    self:RefreshColdthirstState("RunLearnScan")
    self:LoadClassInterrupt()
    self:ApplyRuntimeCooldownOverrides()
    self:RefreshPlayerInterruptCooldownCache()
    self:BroadcastActiveInterruptCooldown()
end
function InterruptSync:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.bars = {}
    container:SetScript("OnUpdate", function(self, elapsed)
         local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
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
    self:RefreshRuntimeState()
    C_Timer.After(0.05, function()
        if not container or not container:IsShown() then return end
        InterruptSync:RunLearnScan()
        DebugLog(InterruptSync, "Initial scan completed on widget load")
    end)
    container:SetScript("OnHide", function(self)
        for i, inst in ipairs(InterruptSync.Instances) do
            if inst == self then table.remove(InterruptSync.Instances, i); break end
        end
        InterruptSync:RefreshRuntimeState()
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
    return row
end
function InterruptSync:SetBarReady(container, bar, spellID)
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 134400)
    bar.icon:SetDesaturated(false)
    if spellInfo and spellInfo.name then
        bar.nameText:SetText((bar.playerName or L("LABEL_UNKNOWN")) .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or L("LABEL_UNKNOWN"))
    end
    local c = elem.colorReady or {1.0, 0.72, 0.04, 1}
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    bar.timerBar:SetMinMaxValues(0, 1); bar.timerBar:SetValue(1)
    bar.timerText:SetText(L("LABEL_READY"))
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
        bar.nameText:SetText((bar.playerName or L("LABEL_UNKNOWN")) .. " - " .. spellInfo.name)
    else
        bar.nameText:SetText(bar.playerName or L("LABEL_UNKNOWN"))
    end
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
    table.sort(sortedNames) 
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
    C_Timer.After(0.05, function()
        InterruptSync:RunLearnScan()
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
    if #fontItems == 0 then fontItems = {{text=L("DEFAULT_OPTION"), value="Fonts\\FRIZQT__.TTF"}} 
    else table.sort(fontItems, function(a,b) return a.text < b.text end) end
    sb:AddHeader(L("HEADER_BAR_SETTINGS"))
    sb:AddSlider("barHeight", L("LABEL_BAR_HEIGHT"), 10, 60, 1, 30, elem, RefreshLive)
    sb:AddSlider("barWidth", L("LABEL_BAR_WIDTH"), 50, 600, 5, 220, elem, RefreshLive)
    sb:AddSlider("spacing", L("LABEL_SPACING_BETWEEN_BARS"), 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("barBgAlpha", L("LABEL_BACKGROUND_ALPHA"), 0, 100, 5, 80, elem, RefreshLive)
    sb:AddDropdown("texture", L("LABEL_BAR_TEXTURE"), texItems, "Smooth", elem, RefreshLive)
    sb:AddColor("barBorderColor", L("LABEL_BAR_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("barBorderSize", L("LABEL_BORDER_THICKNESS_DISABLE"), 0, 5, 1, 1, elem, RefreshLive)
    sb:AddHeader(L("HEADER_TEXT_SETTINGS"))
    sb:AddSlider("fontSize", L("LABEL_FONT_SIZE"), 8, 36, 1, 12, elem, RefreshLive)
    sb:AddDropdown("font", L("LABEL_FONT_STYLE"), fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddDropdown("fontOutline", L("LABEL_FONT_OUTLINE"), { {text=L("OUTLINE_NONE"), value=""}, {text=L("OUTLINE_OUTLINE"), value="OUTLINE"}, {text=L("OUTLINE_THICK_OUTLINE"), value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)
    sb:AddColor("textColor", L("LABEL_TEXT_COLOR"), {1, 1, 1, 1}, elem, RefreshLive)
    sb:AddHeader(L("HEADER_ICON_SETTINGS"))
    sb:AddSwitch("showIcon", L("LABEL_SHOW_SPELL_ICON"), true, elem, RefreshLive)
    sb:AddSlider("iconSpacing", L("LABEL_ICON_SPACING_FROM_BAR"), 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("iconSize", L("LABEL_ICON_SIZE"), 10, 100, 1, 30, elem, RefreshLive)
    sb:AddSlider("iconZoom", L("LABEL_ICON_ZOOM_CROP"), 0, 0.20, 0.01, 0.08, elem, RefreshLive)
    sb:AddColor("iconBorderColor", L("LABEL_ICON_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("iconBorderSize", L("LABEL_BORDER_THICKNESS_DISABLE"), 0, 5, 1, 1, elem, RefreshLive)
    sb:AddHeader(L("HEADER_STATUS_COLORS"))
    sb:AddColor("colorReady", L("LABEL_COLOR_READY"), {1.0, 0.72, 0.04, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", L("LABEL_COLOR_BUSY"), {1.0, 0.2, 0.2, 1}, elem, RefreshLive)
    sb:AddColor("colorSuccess", L("LABEL_COLOR_SUCCESS"), {0.1, 1.0, 0.3, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", L("LABEL_COLOR_SHIELDED"), {0.45, 0.45, 0.6, 1}, elem, RefreshLive)
    sb:AddHeader(L("HEADER_TEST_MODE"))
    if not parentFrame.testBtnInterruptSync then
        local btnTest = Skin:CreateButton(f.content, L("LABEL_TEST_MODE_OFF"), 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnInterruptSync = btnTest
        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal_InterruptSync then 
                btnTest:SetBackdropColor(0, 0.8, 0, 1)
                btnTest.text:SetText(L("LABEL_TEST_MODE_ON"))
            else 
                btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                btnTest.text:SetText(L("LABEL_TEST_MODE_OFF")) 
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
    sb:AddHeader(L("HEADER_ANNOUNCEMENTS"))
    sb:AddSwitch("announceInterrupts", L("LABEL_ANNOUNCE_INTERRUPTS"), false, elem, RefreshLive)
    sb:AddSwitch("announceInterruptSuccess", L("LABEL_ANNOUNCE_INTERRUPT_SUCCESS"), false, elem, RefreshLive)
    sb:AddDropdown("announceChannel", L("LABEL_ANNOUNCE_CHANNEL"), {
        {text = L("OPTION_PARTY"), value = "PARTY"},
        {text = L("OPTION_INSTANCE"), value = "INSTANCE_CHAT"}
    }, "PARTY", elem, RefreshLive)
    sb:AddHeader(L("HEADER_PARTY_SYNC"))
    sb:AddSwitch("partySync", L("LABEL_PARTY_SYNC_INTERRUPTS"), false, elem, RefreshLive)
    local txtHelp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtHelp:SetWordWrap(true)
    txtHelp:SetWidth(600)
    txtHelp:SetJustifyH("LEFT")
    txtHelp:SetTextColor(1, 0.82, 0) 
    txtHelp:SetText(L("NOTE_PARTY_SYNC_INTERRUPTS"))
    sb.y = sb.y - 45
    txtHelp:SetPoint("TOPLEFT", sb.canvas, "TOPLEFT", 12, sb.y)
    sb.y = sb.y - 0
    sb:Finish()
end
