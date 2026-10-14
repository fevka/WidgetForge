local addonName, addonTable = ...
local L = WFL
if not _G.WidgetForge then _G.WidgetForge = {} end
if not _G.WidgetForge.DefUtilSync then _G.WidgetForge.DefUtilSync = {} end
local Sync = _G.WidgetForge.DefUtilSync
addonTable.DefUtilSync = Sync
Sync.Instances = {}
Sync.commPrefix = "WF_DU_SYNC"
Sync.knownSpells = {}      
Sync.spellIDLookup = {}
Sync.lastPartySize = 0
local DU_TRACKED_SPELLS = {
    { id = 47788,  name = "Guardian Spirit",       class = "PRIEST",      cat = "EXT_DEF" },
    { id = 33206,  name = "Pain Suppression",      class = "PRIEST",      cat = "EXT_DEF" },
    { id = 73325,  name = "Leap of Faith",         class = "PRIEST",      cat = "EXT_DEF" },
    { id = 62618,  name = "Power Word: Barrier",   class = "PRIEST",      cat = "PARTY_DEF" },
    { id = 64843,  name = "Divine Hymn",           class = "PRIEST",      cat = "PARTY_DEF" },
    { id = 6940,   name = "Blessing of Sacrifice", class = "PALADIN",     cat = "EXT_DEF",
      cooldownAdjustments = {
          { talent = 384820, reduction = 15, reductionBySpec = { [66] = 60 } },
      },
    },
    { id = 1022,   name = "Blessing of Protection",class = "PALADIN",     cat = "EXT_DEF" },
    { id = 204018, name = "Blessing of Spellwarding", class = "PALADIN",  cat = "EXT_DEF" },
    { id = 633,    name = "Lay on Hands",          class = "PALADIN",     cat = "EXT_DEF" },
    { id = 31821,  name = "Aura Mastery",          class = "PALADIN",     cat = "PARTY_DEF",
      cooldownAdjustments = {
          { talent = 392911, reduction = 30 },
      },
    },
    { id = 391054, name = "Intercession",          class = "PALADIN",     cat = "CR" },
    { id = 102342, name = "Ironbark",              class = "DRUID",       cat = "EXT_DEF",
      cooldownAdjustments = {
          { talent = 382552, reduction = 20 },
      },
    },
    { id = 740,    name = "Tranquility",           class = "DRUID",       cat = "PARTY_DEF" },
    { id = 20484,  name = "Rebirth",               class = "DRUID",       cat = "CR" },
    { id = 98008,  name = "Spirit Link Totem",     class = "SHAMAN",      cat = "PARTY_DEF" },
    { id = 108280, name = "Healing Tide Totem",    class = "SHAMAN",      cat = "PARTY_DEF" },
    { id = 32182,  name = "Heroism",               class = "SHAMAN",      cat = "LUST" },
    { id = 2825,   name = "Bloodlust",             class = "SHAMAN",      cat = "LUST" },
    { id = 97462,  name = "Rallying Cry",          class = "WARRIOR",     cat = "PARTY_DEF" },
    { id = 51052,  name = "Anti-Magic Zone",       class = "DEATHKNIGHT", cat = "PARTY_DEF",
      cooldownAdjustments = {
          { talent = 374383, reduction = 60 },
      },
    },
    { id = 61999,  name = "Raise Ally",            class = "DEATHKNIGHT", cat = "CR" },
    { id = 116849, name = "Life Cocoon",           class = "MONK",        cat = "EXT_DEF" },
    { id = 115310, name = "Revival",               class = "MONK",        cat = "PARTY_DEF" },
    { id = 196718, name = "Darkness",              class = "DEMONHUNTER", cat = "PARTY_DEF" },
    { id = 388615, name = "Rescue",                class = "EVOKER",      cat = "EXT_DEF" },
    { id = 374227, name = "Zephyr",                class = "EVOKER",      cat = "EXT_DEF" },
    { id = 357170, name = "Time Dilation",         class = "EVOKER",      cat = "EXT_DEF" },
    { id = 363534, name = "Rewind",                class = "EVOKER",      cat = "PARTY_DEF" },
    { id = 390386, name = "Fury of the Aspects",   class = "EVOKER",      cat = "LUST" },
    { id = 20707,  name = "Soulstone",             class = "WARLOCK",     cat = "CR" },
    { id = 80353,  name = "Time Warp",             class = "MAGE",        cat = "LUST" },
    { id = 264667, name = "Primal Rage",           class = "HUNTER",      cat = "LUST" },
}
local SPELL_DATA = {}
local DU_SPELL_BY_ID = {}
Sync.CATEGORY_INFO = {
    EXT_DEF  = { color = {0.2, 0.6, 1.0, 1} }, 
    PARTY_DEF = { color = {0.7, 0.2, 0.9, 1} },
    RAID_DEF = { color = {0.7, 0.2, 0.9, 1} }, 
    LUST     = { color = {1.0, 0.2, 0.2, 1} }, 
    CR       = { color = {0.2, 0.8, 0.4, 1} }, 
}
local LUST_DEBUFFS = { 
    [57723] = true, 
    [57724] = true, 
    [80354] = true, 
    [390435] = true, 
    [264689] = true, 
    [95809] = true, 
    [160455] = true, 
}
local LUST_BAR_LABEL = "Bloodlust"
local LUST_LABEL_BY_DEBUFF = {
    [80354] = "Time Warp",
}
Sync.globalCategoryMap = {}
for _, entry in ipairs(DU_TRACKED_SPELLS) do
    DU_SPELL_BY_ID[entry.id] = entry
    Sync.globalCategoryMap[entry.id] = entry.cat
    local classData = SPELL_DATA[entry.class]
    if not classData then
        classData = { DEFAULT = {} }
        SPELL_DATA[entry.class] = classData
    end
    local bucketKey = entry.specIndex or "DEFAULT"
    local bucket = classData[bucketKey]
    if not bucket then
        bucket = {}
        classData[bucketKey] = bucket
    end
    table.insert(bucket, { id = entry.id, cat = entry.cat })
end
local DEFAULT_COOLDOWN = 180
local GCD_SPELL_ID = 61304
local GCD_EPSILON = 0.15
local MIN_VALID_DU_COOLDOWN = 1.0
local DU_COOLDOWN_FALLBACK = {}
local DU_NAME_COOLDOWN_FALLBACK = {}
local function SafeNumber(value)
    if value == nil then return nil end
    local s = tostring(value)
    local n = tonumber(s)
    if type(n) == "number" then return n end
    local ok, num = pcall(function() return tonumber(value) end)
    if ok and type(num) == "number" then
        return tonumber(tostring(num))
    end
    return nil
end
local function SafeGreaterThan(v, t)
    local l = SafeNumber(v)
    if not l then return false end
    local r = SafeNumber(t) or 0
    local ok, result = pcall(function() return l > r end)
    return ok and result or false
end
local function ReadBool(v, defaultValue)
    if v == nil then return defaultValue end
    if v == true or v == 1 or v == "1" then return true end
    if v == false or v == 0 or v == "0" then return false end
    if type(v) == "string" then
        local s = string.lower(v)
        if s == "true" or s == "on" or s == "yes" then return true end
        if s == "false" or s == "off" or s == "no" then return false end
    end
    return v and true or false
end
local function RoundTo2(value)
    local n = SafeNumber(value)
    if not n then return nil end
    return math.floor(n * 100 + 0.5) / 100
end
local function RegisterDUNameFallbackFromID(id, duration)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        DU_NAME_COOLDOWN_FALLBACK[info.name] = duration
    end
end
local function ClearDUNameFallbackFromID(id)
    if not (C_Spell and C_Spell.GetSpellInfo) then return end
    local info = C_Spell.GetSpellInfo(id)
    if info and info.name then
        DU_NAME_COOLDOWN_FALLBACK[info.name] = nil
    end
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
function Sync:GetBaseCooldownDuration(spellID)
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
function Sync:EnsureRuntimeCooldownDB()
    if type(_G.WidgetForgeDB) ~= "table" then _G.WidgetForgeDB = {} end
    if type(_G.WidgetForgeDB.runtimeDefUtilCooldowns) ~= "table" then
        _G.WidgetForgeDB.runtimeDefUtilCooldowns = {}
    end
    return _G.WidgetForgeDB.runtimeDefUtilCooldowns
end
function Sync:GetPlayerSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    return GetSpecializationInfo(specIndex)
end
function Sync:HasTalentSpell(talentSpellID)
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
    return self._talentCacheValue[talentSpellID]
end
function Sync:ApplyTalentCooldownAdjustments(spellID, cooldown)
    local adjusted = SafeNumber(cooldown)
    if not adjusted or adjusted < MIN_VALID_DU_COOLDOWN then
        return nil
    end
    local spellEntry = DU_SPELL_BY_ID[spellID]
    local modifiers = spellEntry and spellEntry.cooldownAdjustments
    if type(modifiers) ~= "table" then
        return RoundTo2(adjusted) or adjusted, false
    end
    local modified = false
    local specID = self:GetPlayerSpecID()
    for _, modifier in ipairs(modifiers) do
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
            adjusted = math.max(MIN_VALID_DU_COOLDOWN, adjusted - reduction)
            modified = true
        end
    end
    return RoundTo2(adjusted) or adjusted, modified
end
function Sync:GetAdjustedBaseCooldownDuration(spellID)
    local base = self:GetBaseCooldownDuration(spellID)
    if not base then return nil, nil, nil end
    local adjusted, modified = self:ApplyTalentCooldownAdjustments(spellID, base)
    if not adjusted then return nil, nil, base end
    return adjusted, (modified and "base_talent" or "base"), base
end
function Sync:ApplyRuntimeCooldownOverrides()
    local db = self:EnsureRuntimeCooldownDB()
    local applied = 0
    for spellIDStr, duration in pairs(db) do
        local sid = tonumber(spellIDStr)
        local dur = RoundTo2(duration)
        if sid and dur and dur >= MIN_VALID_DU_COOLDOWN then
            local allow = true
            local trustedBase = select(1, self:GetAdjustedBaseCooldownDuration(sid))
            if trustedBase and dur > (trustedBase + 0.01) then
                db[spellIDStr] = nil
                DU_COOLDOWN_FALLBACK[sid] = nil
                ClearDUNameFallbackFromID(sid)
                allow = false
            end
            if allow then
                DU_COOLDOWN_FALLBACK[sid] = dur
                RegisterDUNameFallbackFromID(sid, dur)
                applied = applied + 1
            end
        end
    end
end
function Sync:RememberObservedCooldown(spellID, duration, source)
    if not spellID then return end
    if source ~= "live" and source ~= "charges" and source ~= "base" and source ~= "base_talent" then return end
    local dur = RoundTo2(duration)
    if not dur or dur < MIN_VALID_DU_COOLDOWN then return end
    local sid = tonumber(spellID)
    if not sid then return end
    local db = self:EnsureRuntimeCooldownDB()
    local prev = DU_COOLDOWN_FALLBACK[sid]
    local existingPersisted = SafeNumber(db[tostring(sid)])
    if prev and math.abs(prev - dur) < 0.01 then
        if not existingPersisted then
            db[tostring(sid)] = dur
        end
        return
    end
    DU_COOLDOWN_FALLBACK[sid] = dur
    RegisterDUNameFallbackFromID(sid, dur)
    if not prev or math.abs(prev - dur) >= 0.01 or not existingPersisted then
        db[tostring(sid)] = dur
    end
end
function Sync:RefreshPlayerDefUtilCooldownCache()
    if InCombatLockdown and InCombatLockdown() then return end
    if #self.mySpellIDs == 0 then return end
    local gcd = self:GetCurrentGCD()
    for _, spellID in ipairs(self.mySpellIDs) do
        local duration, source = self:GetAdjustedBaseCooldownDuration(spellID)
        if not duration then
            local chargeInfo = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
            if chargeInfo then
                local chargeDur = SafeNumber(chargeInfo.cooldownDuration) or SafeNumber(chargeInfo.chargeCooldownDuration)
                local current = SafeNumber(chargeInfo.currentCharges)
                local maxc = SafeNumber(chargeInfo.maxCharges)
                if chargeDur and SafeGreaterThan(chargeDur, 0) and current and maxc and current < maxc then
                    duration = RoundTo2(chargeDur) or chargeDur
                    source = "charges"
                end
            end
        end
        if duration and duration > (gcd + GCD_EPSILON) then
            self:RememberObservedCooldown(spellID, duration, source)
        end
    end
end
function Sync:GetLiveRemainingCooldown(spellID)
    if not spellID or not C_Spell then return nil end
    if C_Spell.GetSpellCooldownDuration then
        local rem = SafeNumber(C_Spell.GetSpellCooldownDuration(spellID))
        if rem and rem > 0 then return rem end
    end
    if C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
            local startTime = SafeNumber(cdInfo.startTime) or 0
            local duration = SafeNumber(cdInfo.duration) or 0
            local rem = (startTime + duration) - GetTime()
            if rem and rem > 0 then return rem end
        end
    end
    return nil
end
function Sync:BroadcastActiveDefUtilCooldowns()
    if InCombatLockdown and InCombatLockdown() then return end
    if #self.mySpellIDs == 0 then return end
    local playerName = UnitName("player")
    if not playerName then return end
    local timestamp = GetServerTime()
    for _, spellID in ipairs(self.mySpellIDs) do
        local duration, source = self:ResolveCooldownDuration(spellID)
        if duration and duration >= MIN_VALID_DU_COOLDOWN then
            self:RememberObservedCooldown(spellID, duration, source)
        end
        local remaining = self:GetLiveRemainingCooldown(spellID)
        if remaining and remaining > 0.15 then
            for _, container in ipairs(self.Instances) do
                self:UpdateBar(container, playerName, spellID, remaining)
            end
            self:SendSync(spellID, remaining, timestamp)
        end
    end
end
function Sync:QueueWarmupSync(reason)
    self._warmupSerial = (self._warmupSerial or 0) + 1
    local serial = self._warmupSerial
    local why = tostring(reason or "warmup")
    local function RunIfLatest()
        if serial ~= self._warmupSerial then return end
        if InCombatLockdown and InCombatLockdown() then return end
        Sync:LoadClassSpells()
        Sync:ApplyRuntimeCooldownOverrides()
        Sync:RefreshPlayerDefUtilCooldownCache()
        Sync:BroadcastActiveDefUtilCooldowns()
    end
    C_Timer.After(0.05, RunIfLatest)
    C_Timer.After(0.60, RunIfLatest)
end
Sync.mySpellIDs = {}
function Sync:LoadClassSpells()
    local class = select(2, UnitClass("player"))
    local data = SPELL_DATA[class]
    if not data then self.mySpellIDs = {}; return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex]
    local defaultData = data.DEFAULT or {}
    self.mySpellIDs = {}
    local function AddKnownSpell(item)
        if not item or not item.id then return end
        local id = item.id
        local known = false
        if IsPlayerSpell and IsPlayerSpell(id) then known = true end
        if not known and IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then known = true end
        if not known and IsSpellKnown and IsSpellKnown(id) then known = true end
        if not known and FindSpellBookSlotBySpellID then
            local slot = FindSpellBookSlotBySpellID(id)
            if slot and slot > 0 then known = true end
        end
        if known and not self.spellIDLookup[id] then
            table.insert(self.mySpellIDs, id)
            self.spellIDLookup[id] = true
        end
    end
    self.spellIDLookup = {}
    for _, item in ipairs(defaultData) do
        AddKnownSpell(item)
    end
    if specData then
        for _, item in ipairs(specData) do
            AddKnownSpell(item)
        end
    end
    local myName = UnitName("player")
    if myName then self.knownSpells[myName] = self.mySpellIDs end
end
Sync:LoadClassSpells()
function Sync:BroadcastSpells()
    if not IsInGroup() or #self.mySpellIDs == 0 then return end
    local spellList = {}
    for _, id in ipairs(self.mySpellIDs) do table.insert(spellList, tostring(id)) end
    local msg = "SP:" .. table.concat(spellList, ":")
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end
function Sync:SendHello()
    if not IsInGroup() then return end
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, "HELLO", channel)
end
function Sync:GetCurrentGCD()
    local gcd = 1.5
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then gcd = SafeNumber(cdInfo.duration) or gcd end
    end
    return gcd
end
function Sync:ResolveCooldownDuration(spellID)
    if not spellID then return DEFAULT_COOLDOWN, "fallback" end
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo and SafeGreaterThan(cdInfo.duration, 0) then
            local liveDuration = SafeNumber(cdInfo.duration)
            if liveDuration and SafeGreaterThan(liveDuration, self:GetCurrentGCD() + GCD_EPSILON) then return liveDuration, "live" end
        end
    end
    if C_Spell and C_Spell.GetSpellCharges then
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        if chargeInfo then
            local chargeDur = SafeNumber(chargeInfo.cooldownDuration) or SafeNumber(chargeInfo.chargeCooldownDuration)
            local current = SafeNumber(chargeInfo.currentCharges)
            local maxc = SafeNumber(chargeInfo.maxCharges)
            if chargeDur and SafeGreaterThan(chargeDur, 0) and current and maxc and current < maxc then return chargeDur, "charges" end
        end
    end
    local baseSec, baseSource = self:GetAdjustedBaseCooldownDuration(spellID)
    if baseSec then return baseSec, baseSource end
    if DU_COOLDOWN_FALLBACK[spellID] then return DU_COOLDOWN_FALLBACK[spellID], "spell_fallback" end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        local byName = info and info.name and DU_NAME_COOLDOWN_FALLBACK[info.name]
        if byName then return byName, "name_fallback" end
    end
    return DEFAULT_COOLDOWN, "fallback"
end
function Sync:GetCachedCooldownDuration(spellID)
    if not spellID then return DEFAULT_COOLDOWN, "fallback" end
    local cached = SafeNumber(DU_COOLDOWN_FALLBACK[spellID])
    if cached and cached >= MIN_VALID_DU_COOLDOWN then
        return cached, "spell_fallback"
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        local byName = info and info.name and SafeNumber(DU_NAME_COOLDOWN_FALLBACK[info.name])
        if byName and byName >= MIN_VALID_DU_COOLDOWN then
            return byName, "name_fallback"
        end
    end
    return DEFAULT_COOLDOWN, "fallback"
end
local function BuildBarKey(playerName, spellID) return tostring(playerName or "?") .. ":" .. tostring(spellID or 0) end
local function ShouldHideOwnBar(elem, playerName) return elem and elem.hideOwnBars and playerName == UnitName("player") end
local function GetCategoryDefaultColor(elem, cat) return (cat and Sync.CATEGORY_INFO[cat]) and Sync.CATEGORY_INFO[cat].color or {0.5, 0.5, 0.5, 1} end
local function IsDefUtilSettingsPanelOpenForElem(elem)
    local cfg = _G.ForgeConfig
    if not cfg then return false end
    local panel = cfg.SlidePanel
    if not panel or not panel.isSlideOpen then return false end
    if panel.config == elem then return true end
    if panel.header and panel.header.title and panel.header.title.GetText then
        local t = panel.header.title:GetText()
        if t == "Defensives & Utility Settings" then return true end
    end
    return false
end
local function LerpColor(a, b, t)
    local c1 = a or {1, 0.2, 0.2, 1}
    local c2 = b or {1, 0.9, 0.1, 1}
    local k = math.max(0, math.min(1, t or 0))
    return
        (c1[1] or 1) + (((c2[1] or 1) - (c1[1] or 1)) * k),
        (c1[2] or 1) + (((c2[2] or 1) - (c1[2] or 1)) * k),
        (c1[3] or 1) + (((c2[3] or 1) - (c1[3] or 1)) * k),
        (c1[4] or 1) + (((c2[4] or 1) - (c1[4] or 1)) * k)
end
local function FilterSpellsByCategory(spells, elem)
    if not elem then return spells end
    local filtered = {}
    for _, id in ipairs(spells) do
        local cat = Sync.globalCategoryMap[id]
        if cat then
            local enabled = elem["cat"..cat]
            if cat == "PARTY_DEF" and enabled == nil then
                enabled = elem.catRAID_DEF
            end
            if enabled ~= false then table.insert(filtered, id) end
        end
    end
    return filtered
end
function Sync:IsValidContext()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or (instanceType ~= "party" and instanceType ~= "scenario") then return false end
    if IsInRaid() then return false end
    return true
end
function Sync:CheckLustAura()
    local fDur, fExp, fSpell = nil, nil, nil
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for spellID in pairs(LUST_DEBUFFS) do
            local ok, auraData = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
            if ok and auraData then
                fDur = SafeNumber(auraData.duration)
                fExp = SafeNumber(auraData.expirationTime)
                fSpell = spellID
                break
            end
        end
    elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
            if not ok or not auraData then break end
            local spellID = SafeNumber(auraData.spellId)
            if spellID and LUST_DEBUFFS[spellID] then
                fDur = SafeNumber(auraData.duration)
                fExp = SafeNumber(auraData.expirationTime)
                fSpell = spellID
                break
            end
        end
    end
    for _, container in ipairs(self.Instances) do
        if SafeGreaterThan(fDur, 0) and container.elem.catLUST ~= false then
            self:ShowLustCounter(container, fSpell, fExp, fDur, false)
        elseif container._lustPreviewActive and container.elem and container.elem.catLUST ~= false and IsDefUtilSettingsPanelOpenForElem(container.elem) then
        else
            self:HideLustCounter(container)
        end
    end
end
function Sync:UpdateGroupTracking()
    self._talentCacheAt = {}
    self._talentCacheValue = {}
    local myName = UnitName("player")
    local oldSpellsHash = myName and self.knownSpells[myName] and table.concat(self.knownSpells[myName], ",") or ""
    self:LoadClassSpells()
    local newSpellsHash = myName and self.knownSpells[myName] and table.concat(self.knownSpells[myName], ",") or ""
    if oldSpellsHash ~= "" and oldSpellsHash ~= newSpellsHash and IsInGroup() then C_Timer.After(0.5, function() Sync:BroadcastSpells() end) end
    self.eventFrame:UnregisterAllEvents()
    if not self.Instances or #self.Instances == 0 then
        self.cachedIsValidContext = false
        return
    end
    self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    self.cachedIsValidContext = self:IsValidContext()
    self.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    self.eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    for _, container in ipairs(self.Instances) do self:InitializeGroupBars(container) end
    local currentSize = IsInGroup() and GetNumGroupMembers() or 0
    if IsInGroup() and self:IsPartySyncEnabled() then
        if currentSize > self.lastPartySize then C_Timer.After(0.5, function() Sync:SendHello(); Sync:BroadcastSpells() end) end
        if currentSize >= 5 and self.lastPartySize < 5 then C_Timer.After(1, function() Sync:BroadcastSpells() end) end
    else
        for name in pairs(self.knownSpells) do if name ~= myName then self.knownSpells[name] = nil end end
    end
    self.lastPartySize = currentSize
end
function Sync:OnSpellcast(unit, castGUID, spellID)
    if unit ~= "player" or not self.spellIDLookup[spellID] then return end
    local name = UnitName(unit)
    if not name then return end
    local duration, source = self:GetCachedCooldownDuration(spellID)
    if not duration or duration <= 0 then duration = DEFAULT_COOLDOWN end
    for _, container in ipairs(self.Instances) do self:UpdateBar(container, name, spellID, duration) end
    self:SendSync(spellID, duration)
    self:AnnounceDefUtil(spellID, duration)
end
function Sync:SendSync(spellID, duration, timestamp)
    if not IsInGroup() or not duration or duration <= 0 then return end
    local msg = string.format("DU:%d:%.2f:%d", spellID, duration, timestamp or GetServerTime())
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end
function Sync:GetAnnouncementElement()
    return self.Instances[1] and self.Instances[1].elem
end
function Sync:IsPartySyncEnabled()
    local elem = self:GetAnnouncementElement()
    if not elem then return true end
    if elem.partySync == nil then return true end
    return elem.partySync == true
end
function Sync:GetAnnouncementChannel(elem)
    local channel = (elem and elem.announceChannel) or "PARTY"
    if channel == "INSTANCE" then channel = "INSTANCE_CHAT" end
    if channel == "PARTY" and not IsInGroup() then return nil end
    if channel == "INSTANCE_CHAT" and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if IsInGroup() then channel = "PARTY" else return nil end
    end
    return channel
end
function Sync:FormatDUAnnouncement(spellID, duration, includeDuration)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local spellName = (spellInfo and spellInfo.name) or "Defensive"
    if includeDuration and duration and duration > 0 then
        return string.format("Used %s (CD: %ds)", spellName, math.floor(duration + 0.5))
    end
    return string.format("Used %s", spellName)
end
function Sync:RenderLocalAnnouncement(senderName, spellID, duration, channel, includeDuration)
    local msg = self:FormatDUAnnouncement(spellID, duration, includeDuration)
    local channelName = (channel == "INSTANCE_CHAT") and "Instance" or "Party"
    local color = (channel == "INSTANCE_CHAT") and "|cffFF7F00" or "|cffAAAAFF"
    local chatPrefix = color .. "[" .. channelName .. "] |r|cff69CCF0" .. (senderName or "Unknown") .. ": |r"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(chatPrefix .. msg)
    else
        print(msg)
    end
end
function Sync:SendAnnouncementSync(spellID, duration, channel, includeDuration)
    if not IsInGroup() then return end
    local ts = GetServerTime()
    local c = channel or "PARTY"
    local d = duration or 0
    local inc = includeDuration and 1 or 0
    local msg = string.format("DUANN:%d:%.2f:%d:%s:%d", spellID, d, ts, c, inc)
    local syncChannel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, syncChannel)
end
function Sync:AnnounceDefUtil(spellID, duration)
    local elem = self:GetAnnouncementElement()
    if not elem or not elem.announceDefs then return end
    if not IsInGroup() then return end
    local channel = self:GetAnnouncementChannel(elem)
    if not channel then return end
    local senderName = UnitName("player") or "Unknown"
    self:RenderLocalAnnouncement(senderName, spellID, duration, channel, true)
    self:SendAnnouncementSync(spellID, duration, channel, true)
end
function Sync:RenderSyncedDUAnnouncement(sender, spellID, duration, channel, includeDuration)
    local elem = self:GetAnnouncementElement()
    if not elem or not elem.announceDefs then return end
    if not IsInGroup() then return end
    self:RenderLocalAnnouncement(sender, spellID, duration, channel, includeDuration)
end
function Sync:OnCommReceived(prefix, text, channel, sender)
    if prefix ~= self.commPrefix then return end
    if not self:IsPartySyncEnabled() then return end
    sender = Ambiguate(sender, "none")
    if sender == UnitName("player") then return end
    local parts = {strsplit(":", text)}
    local cmd = parts[1]
    if cmd == "HELLO" then
        C_Timer.After(0.3, function() Sync:BroadcastSpells() end)
    elseif cmd == "SP" then
        local spells = {}
        for i = 2, #parts do
            local id = tonumber(parts[i])
            if id then table.insert(spells, id) end
        end
        self.knownSpells[sender] = spells
        for _, container in ipairs(self.Instances) do self:InitializeGroupBars(container) end
    elseif cmd == "DU" then
        local spellID, incDuration, timestamp = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
        if spellID then
            local duration = incDuration or 180
            local lag = math.max(0, GetServerTime() - (timestamp or 0))
            local adjDur = duration - lag
            if adjDur > 0 then
                for _, container in ipairs(self.Instances) do self:UpdateBar(container, sender, spellID, adjDur) end
            end
        end
    elseif cmd == "DUANN" then
        local spellID = tonumber(parts[2])
        local incDuration = tonumber(parts[3]) or 0
        local ch = parts[5] or "PARTY"
        local includeDuration = tonumber(parts[6]) == 1
        if spellID then
            self:RenderSyncedDUAnnouncement(sender, spellID, incDuration, ch, includeDuration)
        end
    end
end
if not Sync.eventFrame then
    Sync.eventFrame = CreateFrame("Frame")
    C_ChatInfo.RegisterAddonMessagePrefix(Sync.commPrefix)
    Sync.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then Sync:OnCommReceived(...)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then Sync:OnSpellcast(...)
        elseif event == "UNIT_AURA" then 
            local unit = ...
            if unit == "player" then Sync:CheckLustAura() end
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
            Sync.cachedIsValidContext = Sync:IsValidContext()
            if event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
                Sync:QueueWarmupSync(string.lower(event))
            end
            Sync:UpdateGroupTracking()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            Sync.cachedIsValidContext = Sync:IsValidContext()
            Sync:UpdateGroupTracking()
            Sync:CheckLustAura()
            Sync:QueueWarmupSync(string.lower(event))
            if IsInGroup() and Sync:IsPartySyncEnabled() then C_Timer.After(2, function() Sync:BroadcastSpells() end) end
        end
    end)
    Sync:UpdateGroupTracking()
end
function Sync:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.bars = {}
    container:SetScript("OnUpdate", function(self, elapsed)
         local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
         local isValidContext = Sync.cachedIsValidContext
         local showRegular = (isValidContext or isUnlocked or Sync.ForceTest)
         self:Show()
          if self.bars then
              for _, bar in pairs(self.bars) do
                  bar:SetAlpha(showRegular and 1 or 0)
              end
          end
          if self.lustBar then
              local hasLust = self.lustBar:IsShown()
              self.lustBar:SetAlpha((showRegular or hasLust) and 1 or 0)
          end
         local wantLustPreview = (not Sync.ForceTest and self.elem and self.elem.catLUST ~= false and IsDefUtilSettingsPanelOpenForElem(self.elem))
         if wantLustPreview and not self._lustPreviewActive then
             self._lustPreviewActive = true
             Sync:ShowLustCounter(self, 57724, GetTime() + 600, 600, true)
         elseif not wantLustPreview and self._lustPreviewActive then
             self._lustPreviewActive = false
             if self.lustBar and self.lustBar._wfIsPreview then
                 Sync:HideLustCounter(self)
             else
                 Sync:CheckLustAura()
             end
         end
         if Sync.ForceTest then
             if not self.testActive then
                 Sync:Test(self, true)
                 self.testActive = true
             end
         else
             if self.testActive then Sync:Test(self, false); self.testActive = false; self.testTimer = 0 end
         end
    end)
    container:Show()
    table.insert(Sync.Instances, container)
    self:QueueWarmupSync("widget_load")
    self:InitializeGroupBars(container)
    self:UpdateGroupTracking()
    container:SetScript("OnHide", function(self)
        for i, inst in ipairs(Sync.Instances) do 
            if inst == self then 
                table.remove(Sync.Instances, i)
                break 
            end 
        end
        Sync:UpdateGroupTracking()
    end)
    return container
end
function Sync:InitializeGroupBars(container)
    local activeKeys = {}
    local elem = container.elem
    local myName = UnitName("player")
    if myName and not ShouldHideOwnBar(elem, myName) then
        local myClass = select(2, UnitClass("player"))
        local mySpells = FilterSpellsByCategory(self.knownSpells[myName] or {}, elem)
        for _, sid in ipairs(mySpells) do
            self:EnsureBarIsReady(container, myName, myClass, sid)
            activeKeys[BuildBarKey(myName, sid)] = true
        end
    end
    if IsInGroup() and self:IsPartySyncEnabled() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and 40 or 4
        for i=1, num do
            local unit = prefix..i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    local unitClass = select(2, UnitClass(unit))
                    local unitSpells = FilterSpellsByCategory(self.knownSpells[name] or {}, elem)
                    for _, sid in ipairs(unitSpells) do
                         self:EnsureBarIsReady(container, name, unitClass, sid)
                         activeKeys[BuildBarKey(name, sid)] = true
                    end
                end
            end
        end
    end
    if container.bars then
        for key, bar in pairs(container.bars) do if not activeKeys[key] then bar:Hide(); container.bars[key] = nil end end
    end
    self:RefreshBars(container)
end
function Sync:ShowLustCounter(container, spellID, expirationTime, duration, isPreview)
    if not container.lustBar then
        container.lustBar = self:CreateBar(container, "BLOODLUST", true)
    end
    local bar = container.lustBar
    bar._wfIsPreview = (isPreview == true)
    local elem = container.elem or {}
    local baseH = elem.barHeight or 30
    local baseW = elem.barWidth or 220
    local lustH = elem.lustBarHeight or (baseH * 1.5)
    local lustW = elem.lustBarWidth or (baseW * 1.2)
    local lustISz = elem.lustIconSize or lustH
    local lustShowIcon = ReadBool(elem.lustShowIcon, true)
    bar:SetSize(lustW, math.max(lustH, lustShowIcon and lustISz or 0))
    if bar.iconBox then
        bar.iconBox:SetSize(lustISz, lustISz)
        bar.iconBox:ClearAllPoints()
        bar.iconBox:SetPoint("LEFT", 4, 0)
        if lustShowIcon then bar.iconBox:Show() else bar.iconBox:Hide() end
    end
    if bar.icon then
        if lustShowIcon then bar.icon:Show() else bar.icon:Hide() end
    end
    if bar.classStrip then
        if lustShowIcon then bar.classStrip:Show() else bar.classStrip:Hide() end
    end
    if bar.info then
        bar.info:ClearAllPoints()
        if lustShowIcon then
            bar.info:SetPoint("LEFT", bar.iconBox, "RIGHT", elem.iconSpacing or 5, 0)
        else
            bar.info:SetPoint("LEFT", 4, 0)
        end
        bar.info:SetPoint("RIGHT", 0, 0)
        bar.info:SetHeight(lustH)
    end
    local appTime = expirationTime - duration
    local simulatedEndTime = appTime + 40
    if GetTime() >= simulatedEndTime then
        self:HideLustCounter(container)
        return
    end
    bar.endTime = simulatedEndTime
    bar.duration = 40
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
    bar.icon:SetDesaturated(false)
    bar.nameText:SetText(LUST_LABEL_BY_DEBUFF[spellID] or LUST_BAR_LABEL)
    local startColor = container.elem.lustColorStart or {1.0, 0.2, 0.2, 1}
    bar.timerBar:SetStatusBarColor(startColor[1], startColor[2], startColor[3], startColor[4] or 1)
    bar.classStrip:SetColorTexture(1, 0.8, 0, 1) 
    bar:Show()
    bar:SetScript("OnUpdate", function(f)
        local showLustIcon = ReadBool(container.elem and container.elem.lustShowIcon, true)
        if f.iconBox then if showLustIcon then f.iconBox:Show() else f.iconBox:Hide() end end
        if f.icon then if showLustIcon then f.icon:Show() else f.icon:Hide() end end
        local rem = f.endTime - GetTime()
        if rem <= 0 then
            Sync:HideLustCounter(container)
        else
            local warnSec = container.elem.lustWarnSeconds or 8
            local t = 0
            if warnSec > 0 and rem <= warnSec then t = (warnSec - rem) / warnSec end
            local r, g, b, a = LerpColor(container.elem.lustColorStart, container.elem.lustColorEnd, t)
            f.timerBar:SetStatusBarColor(r, g, b, a)
            f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1fs", rem))
            if f.iconTimerText then f.iconTimerText:SetText(container.elem.attachToParty and string.format("%.0f", rem) or "") end
        end
    end)
    self:LayoutBars(container)
end
function Sync:HideLustCounter(container)
    if container.lustBar then
        container.lustBar._wfIsPreview = false
        container.lustBar:Hide()
        container.lustBar:SetScript("OnUpdate", nil)
        self:LayoutBars(container)
    end
end
function Sync:CreateBar(container, name, isLust)
    local elem = container.elem
    local h, w = elem.barHeight or 30, elem.barWidth or 220
    if isLust and not elem.attachToParty then
        h = elem.lustBarHeight or (h * 1.5)
        w = elem.lustBarWidth or (w * 1.2)
    end
    local iSz = isLust and (elem.lustIconSize or h) or (elem.iconSize or h)
    local showIcon = ReadBool(elem.showIcon, true)
    if isLust then
        showIcon = ReadBool(elem.lustShowIcon, true)
    end
    local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
    row:SetSize(w, math.max(h, showIcon and iSz or 0))
    row.iconBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconBox:SetSize(iSz, iSz); row.iconBox:SetPoint("LEFT", 4, 0)
    if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(row.iconBox) end
    row.iconBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    row.iconBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    row.iconBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    if not showIcon then row.iconBox:Hide() end
    row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", 1, -1)
    row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -1, 1)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.info = CreateFrame("Frame", nil, row)
    row.info:SetPoint("LEFT", showIcon and row.iconBox or row, showIcon and "RIGHT" or "LEFT", showIcon and (elem.iconSpacing or 5) or 4, 0)
    row.info:SetPoint("RIGHT", 0, 0); row.info:SetHeight(h)
    row.classStrip = row:CreateTexture(nil, "BORDER"); row.classStrip:SetWidth(4)
    row.classStrip:SetPoint("TOPRIGHT", showIcon and row.iconBox or row.info, "TOPLEFT", -1, 0)
    row.classStrip:SetPoint("BOTTOMRIGHT", showIcon and row.iconBox or row.info, "BOTTOMLEFT", -1, 0)
    row.nameBar = CreateFrame("Frame", nil, row.info)
    row.nameBar:SetPoint("TOPLEFT", 0, 0); row.nameBar:SetPoint("TOPRIGHT", 0, 0); row.nameBar:SetHeight(h / 2)
    row.timerBarBg = CreateFrame("Frame", nil, row.info, "BackdropTemplate")
    row.timerBarBg:SetPoint("TOPLEFT", row.nameBar, "BOTTOMLEFT", 0, 0); row.timerBarBg:SetPoint("BOTTOMRIGHT", 0, 0); row.timerBarBg:SetHeight(h / 2)
    if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(row.timerBarBg) end
    row.timerBarBg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    row.timerBarBg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    row.timerBarBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    row.timerBar = CreateFrame("StatusBar", nil, row.timerBarBg)
    row.timerBar:SetPoint("TOPLEFT", row.timerBarBg, "TOPLEFT", 1, -1); row.timerBar:SetPoint("BOTTOMRIGHT", row.timerBarBg, "BOTTOMRIGHT", -1, 1)
    row.timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.timerBar:SetMinMaxValues(0, 1); row.timerBar:SetValue(1)
    row.textFrame = CreateFrame("Frame", nil, row.info)
    row.textFrame:SetAllPoints(row.info)
    row.textFrame:SetFrameLevel(row.timerBar:GetFrameLevel() + 5)
    row.nameText = row.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row.nameBar, "LEFT", 2, 0); row.playerName = name
    row.timerText = row.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timerText:SetPoint("RIGHT", row.timerBarBg, "RIGHT", -2, 0)
    row.iconTimerText = row.iconBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.iconTimerText:SetPoint("CENTER", row.iconBox, "CENTER", 0, 0)
    row.cooldown = CreateFrame("Cooldown", nil, row.iconBox, "CooldownFrameTemplate")
    row.cooldown:SetAllPoints(row.iconBox); row.cooldown:SetDrawEdge(false); row.cooldown:SetDrawBling(false); row.cooldown:SetHideCountdownNumbers(true)
    return row
end
function Sync:EnsureBarIsReady(container, name, class, spellID)
    if not name or not class or not spellID then return end
    local key = BuildBarKey(name, spellID)
    if not container.bars[key] then
        local row = self:CreateBar(container, name, false)
        row.ccSpellID = spellID
        container.bars[key] = row
        self:SetBarReady(container, row, spellID)
    end
    self.activeCooldowns = self.activeCooldowns or {}
    local mem = self.activeCooldowns[key]
    if mem and mem.endTime and mem.endTime > GetTime() then
        local bar = container.bars[key]
        if bar and not bar:GetScript("OnUpdate") then
            bar.endTime = mem.endTime
            bar.duration = mem.duration
            bar.currentSpellID = mem.spellID
            local spellInfo = C_Spell.GetSpellInfo(mem.spellID)
            bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
            bar.icon:SetDesaturated(true)
            bar.nameText:SetText(spellInfo and string.format("%s - %s", bar.playerName, spellInfo.name) or bar.playerName)
            local cat = Sync.globalCategoryMap[mem.spellID]
            local c = container.elem.colorOnCD or GetCategoryDefaultColor(container.elem, cat)
            bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
            bar:Show()
            bar:SetScript("OnUpdate", function(f)
                local rem = f.endTime - GetTime()
                if rem <= 0 then Sync:SetBarReady(container, f, f.currentSpellID)
                else
                    f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
                    if f.iconTimerText then f.iconTimerText:SetText(container.elem.attachToParty and string.format("%.0f", rem) or "") end
                end
            end)
        end
    end
end
function Sync:SetBarReady(container, bar, spellID)
    local elem = container.elem
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
    bar.icon:SetDesaturated(false)
    bar.nameText:SetText(spellInfo and string.format("%s - %s", bar.playerName, spellInfo.name) or bar.playerName)
    local cat = Sync.globalCategoryMap[spellID]
    local c = elem.colorReady or GetCategoryDefaultColor(elem, cat)
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    bar.timerBar:SetMinMaxValues(0, 1); bar.timerBar:SetValue(1)
    bar.timerText:SetText(L("LABEL_READY"))
    if bar.iconTimerText then bar.iconTimerText:SetText("") end
    if bar.cooldown then bar.cooldown:Hide() end
    local classColor = {r=0.5, g=0.5, b=0.5}
    local unit = bar.playerName == UnitName("player") and "player" or nil
    if not unit and IsInGroup() then
        for i=1, 40 do local u = (i <= 4) and "party"..i or "raid"..i; if UnitName(u) == bar.playerName then unit = u break end end
    end
    if unit then
        local _, cls = UnitClass(unit)
        if cls and RAID_CLASS_COLORS[cls] then classColor = RAID_CLASS_COLORS[cls] end
    end
    bar.classStrip:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    bar:SetScript("OnUpdate", nil)
    bar:Show()
end
function Sync:UpdateBar(container, senderName, spellID, duration)
    if ShouldHideOwnBar(container.elem, senderName) then return end
    local key = BuildBarKey(senderName, spellID)
    if not container.bars[key] then 
        local unitClass = nil
        if senderName == "TankBoi" then unitClass = "PALADIN"
        elseif senderName == "HealerGirl" then unitClass = "PRIEST"
        elseif senderName == "DpsZug" then unitClass = "WARRIOR"
        elseif senderName == "LustBro" then unitClass = "SHAMAN"
        elseif senderName == UnitName("player") then unitClass = select(2, UnitClass("player")) end
        if not unitClass and IsInGroup() then
            for i=1, 40 do local u = (i <= 4) and "party"..i or "raid"..i; if UnitName(u) == senderName then unitClass = select(2, UnitClass(u)) break end end
        end
        if unitClass then self:EnsureBarIsReady(container, senderName, unitClass, spellID) end
    end
    local bar = container.bars[key]
    if not bar then return end
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    bar.icon:SetTexture(spellInfo and spellInfo.iconID or 136116)
    bar.icon:SetDesaturated(true)
    bar.nameText:SetText(spellInfo and string.format("%s - %s", bar.playerName, spellInfo.name) or bar.playerName)
    local cat = Sync.globalCategoryMap[spellID]
    local c = container.elem.colorOnCD or GetCategoryDefaultColor(container.elem, cat)
    bar.timerBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    bar.endTime = GetTime() + duration
    bar.duration = duration
    bar.currentSpellID = spellID
    self.activeCooldowns = self.activeCooldowns or {}
    self.activeCooldowns[key] = { spellID = spellID, endTime = bar.endTime, duration = duration }
    bar:Show()
    if bar.cooldown then
        if container.elem.attachToParty then bar.cooldown:SetCooldown(GetTime(), duration); bar.cooldown:Show()
        else bar.cooldown:Hide() end
    end
    bar:SetScript("OnUpdate", function(f)
        local rem = f.endTime - GetTime()
        if rem <= 0 then Sync:SetBarReady(container, f, f.currentSpellID)
        else
            f.timerBar:SetMinMaxValues(0, f.duration); f.timerBar:SetValue(rem); f.timerText:SetText(string.format("%.1f", rem))
            if f.iconTimerText then f.iconTimerText:SetText(container.elem.attachToParty and string.format("%.0f", rem) or "") end
        end
    end)
    self:LayoutBars(container)
end
local function FrameMatchesUnit(frame, unitId)
    if not frame or not unitId then return false end
    local unit = frame.unit
    if not unit and frame.GetAttribute then unit = frame:GetAttribute("unit") end
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
        if visibleOK and FrameMatchesUnit(frame, unitId) then return frame end
        if frame.GetChildren then
            local children = {frame:GetChildren()}
            for i = 1, #children do queue[#queue + 1] = children[i] end
        end
    end
    return nil
end
function Sync:GetUnitFrame(unitName)
    if not unitName then return nil end
    local isPlayer = (unitName == UnitName("player"))
    local unitId = nil
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local maxUnits = IsInRaid() and 40 or 4
        for i = 1, maxUnits do
            local u = prefix .. i
            if UnitName(u) == unitName then unitId = u; break end
        end
    end
    if not unitId and isPlayer then unitId = "player" end
    if not unitId then return nil end
    if _G.ElvUF then
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
    for i = 1, 40 do
        local f = _G["CompactPartyFrameMember"..i]
        if f and f:IsVisible() and (f.unit == unitId or f.displayedUnit == unitId) then return f end
        f = _G["CompactRaidFrame"..i]
        if f and f:IsVisible() and (f.unit == unitId or f.displayedUnit == unitId) then return f end
    end
    for i = 1, 4 do
        local f = _G["PartyMemberFrame"..i]
        if f and f:IsVisible() and f.unit == unitId then return f end
    end
    local roots = { _G.CompactPartyFrame, _G.CompactRaidFrameContainer, _G.CompactRaidGroup1, _G.PartyFrame }
    for i = 1, #roots do
        local f = FindDescendantFrameByUnit(roots[i], unitId, true)
        if f then return f end
    end
    if isPlayer then
        if ElvUF_Player and ElvUF_Player:IsVisible() then return ElvUF_Player end
        if PlayerFrame and PlayerFrame:IsVisible() then return PlayerFrame end
        if self.ForceTest then return PlayerFrame or UIParent end
    end
    return nil
end
function Sync:LayoutBars(container)
    local elem = container.elem
    local prev = nil
    local spacing = elem.spacing or 5
    local attachMode = elem.attachToParty == true
    local ownerStackIndex = {}
    if container.lustBar and container.lustBar:IsShown() then
        local lustBar = container.lustBar
        local unlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
        lustBar:SetParent(UIParent)
        lustBar:SetFrameStrata(container:GetFrameStrata() or "HIGH")
        lustBar:SetFrameLevel((container:GetFrameLevel() or 1) + 50)
        lustBar:SetMovable(true)
        lustBar:SetClampedToScreen(true)
        if not lustBar._wfDragInit then
            lustBar:RegisterForDrag("LeftButton")
            lustBar:SetScript("OnDragStart", function(self)
                local canMove = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
                if canMove then
                    self._wfDragging = true
                    self:StartMoving()
                end
            end)
            lustBar:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local cx, cy = self:GetCenter()
                local ux, uy = UIParent:GetCenter()
                if cx and cy and ux and uy then
                    container.elem.lustPosX = cx - ux
                    container.elem.lustPosY = cy - uy
                end
                self._wfDragging = false
            end)
            lustBar._wfDragInit = true
        end
        lustBar:EnableMouse(unlocked)
        if not lustBar._wfDragging then
            lustBar:ClearAllPoints()
            local ox = container.elem.lustPosX or 0
            local oy = container.elem.lustPosY or 120
            lustBar:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
        end
    end
    local sortedKeys = {}
    for key in pairs(container.bars) do table.insert(sortedKeys, key) end
    table.sort(sortedKeys)
    for _, key in ipairs(sortedKeys) do
        local bar = container.bars[key]
        if ShouldHideOwnBar(elem, bar.playerName) then
            bar:Hide()
        else
            if not bar:IsShown() then bar:Show() end
            bar:ClearAllPoints()
            if attachMode then
                local stackedInContainer = false
                local ownerName = bar.playerName
                local targetFrame = self:GetUnitFrame(ownerName)
                if not targetFrame and self.ForceTest then
                    if ownerName == UnitName("player") then
                        targetFrame = PlayerFrame or UIParent
                    else
                        bar:SetParent(container)
                        bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                        bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                        if not prev then bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                        else bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) end
                        prev = bar
                        stackedInContainer = true
                    end
                end
                if targetFrame then
                    bar:SetParent(targetFrame)
                    bar:SetFrameStrata(targetFrame:GetFrameStrata() or "MEDIUM")
                    bar:SetFrameLevel((targetFrame:GetFrameLevel() or 1) + 10)
                    local offX = elem.partyOffsetX or 5
                    local offY = elem.partyOffsetY or 0
                    local side = elem.partyAttachSide or "RIGHT"
                    local grow = elem.partyGrowDirection or "HORIZONTAL"
                    local stack = ownerStackIndex[ownerName] or 0
                    local point, relPoint = "LEFT", "RIGHT"
                    local dirX, dirY = 1, 0
                    if side == "LEFT" then
                        point, relPoint = "RIGHT", "LEFT"; dirX, dirY = -1, 0
                    elseif side == "TOP" then
                        point, relPoint = "BOTTOM", "TOP"; dirX, dirY = 1, 0
                    elseif side == "BOTTOM" then
                        point, relPoint = "TOP", "BOTTOM"; dirX, dirY = 1, 0
                    end
                    if grow == "VERTICAL" then
                        dirX = 0
                        if side == "TOP" then dirY = 1 else dirY = -1 end
                    else
                        dirY = 0
                    end
                    local step = ((grow == "VERTICAL") and (bar:GetHeight() or (elem.iconSize or 24)) or (bar:GetWidth() or (elem.iconSize or 24))) + spacing
                    bar:SetPoint(point, targetFrame, relPoint, offX + (stack * step * dirX), offY + (stack * step * dirY))
                    ownerStackIndex[ownerName] = stack + 1
                elseif not stackedInContainer then
                    bar:SetParent(container)
                    bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                    bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                    if not prev then bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                    else bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) end
                    prev = bar
                end
                bar:EnableMouse(false)
            else
                bar:SetParent(container)
                bar:SetFrameStrata(container:GetFrameStrata() or "MEDIUM")
                bar:SetFrameLevel((container:GetFrameLevel() or 1) + 1)
                bar:EnableMouse(true)
                if not prev then bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                else bar:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing) end
                prev = bar
            end
        end
    end
    if attachMode then container:SetSize(1, 1)
    else container:SetHeight(prev and (math.abs(select(4, prev:GetPoint()) or 0) + prev:GetHeight() + spacing) or 1) end
end
function Sync:Test(container, on)
    if on then
        self:UpdateBar(container, "TankBoi", 6940, 120) 
        self:UpdateBar(container, "HealerGirl", 33206, 180) 
        self:UpdateBar(container, "DpsZug", 97462, 180) 
        if container.elem.catLUST ~= false then
            self:UpdateBar(container, "LustBro", 32182, 300)
            self:ShowLustCounter(container, 57724, GetTime() + 600, 600, true)
        end
    else
        for key, bar in pairs(container.bars) do
            if bar.playerName == "TankBoi" or bar.playerName == "HealerGirl" or bar.playerName == "DpsZug" or bar.playerName == "LustBro" then
                bar:Hide(); container.bars[key] = nil
            end
        end
        self:HideLustCounter(container)
        self:InitializeGroupBars(container)
    end
end
function Sync:RefreshBars(container)
    local elem = container.elem
    local h, w = elem.barHeight or 30, elem.barWidth or 220
    local iSz = elem.iconSize or h
    local barBgAlpha = (elem.barBgAlpha or 80) / 100
    local barBSize = elem.barBorderSize or 1
    if barBSize < 0 then barBSize = 0 end
    local showBarBorder = (barBSize > 0)
    local iconBSize = elem.iconBorderSize or 1
    if iconBSize < 0 then iconBSize = 0 end
    local showIconBorder = (iconBSize > 0)
    local showIcon = ReadBool(elem.showIcon, true)
    local lustShowIcon = ReadBool(elem.lustShowIcon, true)
    local iconSpacing = elem.iconSpacing or 5
    local iconZoom = elem.iconZoom or 0.08
    local fontPath = _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts and _G.ForgeSkin.Media.Fonts[elem.font] or "Fonts\\FRIZQT__.TTF"
    local textColor = elem.textColor or {1, 1, 1, 1}
    local function updateRowStyle(row, isLust)
        local attachMode = elem.attachToParty == true
        local curH, curW, curSz = h, w, iSz
        local rowShowIcon
        if isLust then
            rowShowIcon = lustShowIcon
        else
            rowShowIcon = showIcon
        end
        if isLust and not attachMode then
            curH = elem.lustBarHeight or (h * 1.5)
            curW = elem.lustBarWidth or (w * 1.2)
            curSz = elem.lustIconSize or curH
        end
        if attachMode and not isLust then
            row:SetSize(curSz, curSz); row.info:Hide(); row.classStrip:Hide()
        else
            row.info:Show(); row.classStrip:Show()
            row:SetSize(curW, math.max(curH, rowShowIcon and curSz or 0))
            if rowShowIcon then row.info:SetPoint("LEFT", row.iconBox, "RIGHT", iconSpacing, 0)
            else row.info:SetPoint("LEFT", 4, 0) end
            row.info:SetHeight(curH)
            row.nameText:SetFont(fontPath, (elem.fontSize or 12) * (isLust and 1.2 or 1), elem.fontOutline or "OUTLINE")
            row.nameText:SetTextColor(unpack(textColor))
            row.timerText:SetFont(fontPath, (elem.fontSize or 12) * (isLust and 1.2 or 1), elem.fontOutline or "OUTLINE")
            row.timerText:SetTextColor(unpack(textColor))
            if isLust and attachMode then row.iconTimerText:SetFont(fontPath, (elem.fontSize or 12) * 1.2, elem.fontOutline or "OUTLINE") end
            local chosenTexture = (isLust and elem.lustTexture) or elem.texture
            local tex = _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures and _G.ForgeSkin.Media.Textures[chosenTexture] or "Interface\\TargetingFrame\\UI-StatusBar"
            row.timerBar:SetStatusBarTexture(tex)
        end
        if isLust and not rowShowIcon then
            row.classStrip:Hide()
        end
        if rowShowIcon then
            row.iconBox:Show()
            row.icon:Show()
        else
            row.iconBox:Hide()
            row.icon:Hide()
        end
        row.iconBox:SetSize(curSz, curSz)
        row.iconBox:ClearAllPoints(); row.iconBox:SetPoint("LEFT", (attachMode and not isLust) and 0 or 4, 0)
        if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(row.iconBox) end
        row.iconBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
        row.iconBox:SetBackdropColor(0.1, 0.1, 0.1, attachMode and 1 or barBgAlpha)
        if showIconBorder then row.iconBox:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
        else row.iconBox:SetBackdropBorderColor(0, 0, 0, 0) end
        local iconPad = showIconBorder and iconBSize or 0
        local iconMargin = iconPad + 1
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", iconMargin, -iconMargin)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -iconMargin, iconMargin)
        row.icon:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)
        if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(row.timerBarBg) end
        row.timerBarBg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, tileSize = 0, edgeSize = showBarBorder and barBSize or 1, insets = {left = 0, right = 0, top = 0, bottom = 0}})
        row.timerBarBg:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
        if showBarBorder then row.timerBarBg:SetBackdropBorderColor(unpack(elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
        else row.timerBarBg:SetBackdropBorderColor(0, 0, 0, 0) end
        local barPad = showBarBorder and barBSize or 0
        local barMargin = barPad + 1
        row.timerBar:ClearAllPoints()
        row.timerBar:SetPoint("TOPLEFT", row.timerBarBg, "TOPLEFT", barMargin, -barMargin)
        row.timerBar:SetPoint("BOTTOMRIGHT", row.timerBarBg, "BOTTOMRIGHT", -barMargin, barMargin)
    end
    local count = 0
    for _, row in pairs(container.bars) do
        updateRowStyle(row, false)
        local cat = Sync.globalCategoryMap[row.currentSpellID] or "EXT_DEF"
        local readyColor = elem.colorReady or GetCategoryDefaultColor(elem, cat)
        local cdColor = elem.colorOnCD or GetCategoryDefaultColor(elem, cat)
        if row:GetScript("OnUpdate") then
             row.timerBar:SetStatusBarColor(cdColor[1], cdColor[2], cdColor[3], cdColor[4] or 1)
             if row.cooldown then if elem.attachToParty then row.cooldown:SetCooldown(row.endTime - row.duration, row.duration); row.cooldown:Show() else row.cooldown:Hide() end end
        else
             row.timerBar:SetStatusBarColor(readyColor[1], readyColor[2], readyColor[3], readyColor[4] or 1)
             if row.cooldown then row.cooldown:Hide() end
        end
        count = count + 1
    end
    if container.lustBar and container.lustBar:IsShown() then
        updateRowStyle(container.lustBar, true)
    end
    if not elem.attachToParty then container:SetSize(w, math.max(1, (count * math.max(h, showIcon and iSz or 0)) + (math.max(0, count - 1) * (elem.spacing or 5)))) end
    self:LayoutBars(container)
end
function Sync:CreateSettings(parentFrame)
    local f = parentFrame; local elem = f.config
    local Skin = _G.ForgeSkin
    if elem and elem.catPARTY_DEF == nil and elem.catRAID_DEF ~= nil then
        elem.catPARTY_DEF = elem.catRAID_DEF
    end
    local function RefreshLive()
        for _, inst in ipairs(Sync.Instances) do
            if inst.elem == elem then
                Sync:InitializeGroupBars(inst)
                Sync:RefreshBars(inst)
                if Sync.ForceTest or parentFrame.isTestingGlobal_DefUtil then
                    Sync:Test(inst, true)
                end
            end
        end
    end
    if not _G.WidgetForgeUtils then return end
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content); f.builder = sb
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
    sb:AddHeader(L("HEADER_CATEGORIES_TO_TRACK"))
    sb:AddSwitch("catEXT_DEF", L("LABEL_EXTERNAL_DEFENSIVES_BLUE"), true, elem, RefreshLive)
    sb:AddSwitch("catPARTY_DEF", L("LABEL_PARTY_DEFENSIVES_PURPLE"), true, elem, RefreshLive)
    sb:AddSwitch("catLUST", L("LABEL_BLOODLUST_HEROISM_RED"), true, elem, RefreshLive)
    sb:AddSwitch("catCR", L("LABEL_COMBAT_RES_GREEN"), true, elem, RefreshLive)
    sb:AddHeader(L("HEADER_LUST_BAR"))
    sb:AddSwitch("lustShowIcon", L("LABEL_LUST_SHOW_ICON"), true, elem, RefreshLive)
    sb:AddSlider("lustBarWidth", L("LABEL_LUST_BAR_WIDTH"), 80, 700, 5, 264, elem, RefreshLive)
    sb:AddSlider("lustBarHeight", L("LABEL_LUST_BAR_HEIGHT"), 10, 80, 1, 36, elem, RefreshLive)
    sb:AddSlider("lustIconSize", L("LABEL_LUST_ICON_SIZE"), 10, 100, 1, 36, elem, RefreshLive)
    sb:AddDropdown("lustTexture", L("LABEL_LUST_BAR_TEXTURE"), texItems, "Smooth", elem, RefreshLive)
    sb:AddColor("lustColorStart", L("LABEL_LUST_START_COLOR"), {1.0, 0.2, 0.2, 1}, elem, RefreshLive)
    sb:AddColor("lustColorEnd", L("LABEL_LUST_END_COLOR"), {1.0, 0.9, 0.1, 1}, elem, RefreshLive)
    sb:AddSlider("lustWarnSeconds", L("LABEL_LUST_END_WARN_SECONDS"), 1, 40, 1, 8, elem, RefreshLive)
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
    sb:AddColor("colorReady", L("LABEL_COLOR_READY"), {0.2, 0.8, 1.0, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", L("LABEL_COLOR_BUSY"), {1.0, 0.5, 0.0, 1}, elem, RefreshLive)
    sb:AddHeader(L("HEADER_PARTY_FRAME_INTEGRATION"))
    sb:AddSwitch("attachToParty", L("LABEL_ATTACH_TO_PARTY"), false, elem, RefreshLive)
    sb:AddDropdown("partyAttachSide", L("LABEL_ATTACH_SIDE"), {
        {text = L("OPTION_RIGHT"), value = "RIGHT"},
        {text = L("OPTION_LEFT"), value = "LEFT"},
        {text = L("OPTION_TOP"), value = "TOP"},
        {text = L("OPTION_BOTTOM"), value = "BOTTOM"},
    }, "RIGHT", elem, RefreshLive)
    sb:AddDropdown("partyGrowDirection", L("LABEL_ICON_FLOW_DIRECTION"), {
        {text = L("OPTION_HORIZONTAL"), value = "HORIZONTAL"},
        {text = L("OPTION_VERTICAL"), value = "VERTICAL"},
    }, "HORIZONTAL", elem, RefreshLive)
    sb:AddSlider("partyOffsetX", L("LABEL_X_OFFSET"), -100, 100, 1, 5, elem, RefreshLive)
    sb:AddSlider("partyOffsetY", L("LABEL_Y_OFFSET"), -100, 100, 1, 0, elem, RefreshLive)
    sb:AddHeader(L("HEADER_ANNOUNCEMENTS"))
    sb:AddSwitch("announceDefs", L("LABEL_ANNOUNCE_DEFENSIVES"), false, elem, RefreshLive)
    sb:AddDropdown("announceChannel", L("LABEL_ANNOUNCE_CHANNEL"), {
        {text = L("OPTION_PARTY"), value = "PARTY"},
        {text = L("OPTION_INSTANCE"), value = "INSTANCE_CHAT"}
    }, "PARTY", elem, RefreshLive)
    sb:AddHeader(L("HEADER_PARTY_SYNC"))
    sb:AddSwitch("hideOwnBars", L("LABEL_HIDE_MY_OWN_SPELLS"), false, elem, RefreshLive)
    sb:AddSwitch("partySync", L("LABEL_PARTY_SYNC_DEFENSIVES"), true, elem, RefreshLive)
    parentFrame.isTestingGlobal_DefUtil = parentFrame.isTestingGlobal_DefUtil or false
    if not parentFrame.testBtnDefUtil then
        local btnTest = Skin and select(2, pcall(function() return Skin:CreateButton(f.content, L("LABEL_TEST_MODE_OFF"), 130, 22) end))
        if btnTest then
            btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
            parentFrame.testBtnDefUtil = btnTest
            local function UpdateTestButtonVisuals()
                if parentFrame.isTestingGlobal_DefUtil then
                    btnTest:SetBackdropColor(0, 0.8, 0, 1)
                    if btnTest.text then btnTest.text:SetText(L("LABEL_TEST_MODE_ON")) end
                else
                    if Skin and Skin.Colors and Skin.Colors.button then
                        btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                    end
                    if btnTest.text then btnTest.text:SetText(L("LABEL_TEST_MODE_OFF")) end
                end
            end
            UpdateTestButtonVisuals()
            btnTest:SetScript("OnEnter", function()
                if parentFrame.isTestingGlobal_DefUtil then btnTest:SetBackdropColor(0, 1, 0, 1)
                elseif Skin and Skin.Colors and Skin.Colors.buttonHover then btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
            end)
            btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
            btnTest:SetScript("OnClick", function()
                parentFrame.isTestingGlobal_DefUtil = not parentFrame.isTestingGlobal_DefUtil
                Sync.ForceTest = parentFrame.isTestingGlobal_DefUtil
                UpdateTestButtonVisuals()
                RefreshLive()
            end)
            parentFrame.onCloseWidgetSpecific = function()
                parentFrame.isTestingGlobal_DefUtil = false
                Sync.ForceTest = false
                for _, inst in ipairs(Sync.Instances) do
                    if inst.elem == elem then
                        inst._lustPreviewActive = false
                        if inst.lustBar and inst.lustBar._wfIsPreview then
                            Sync:HideLustCounter(inst)
                        end
                    end
                end
            end
        end
    elseif parentFrame.testBtnDefUtil then
        parentFrame.testBtnDefUtil:Show()
    end
    local txtHelp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtHelp:SetWordWrap(true)
    txtHelp:SetWidth(600)
    txtHelp:SetJustifyH("LEFT")
    txtHelp:SetTextColor(1, 0.82, 0)
    txtHelp:SetText(L("NOTE_PARTY_SYNC_DEFUTIL"))
    sb.y = sb.y - 0
    txtHelp:SetPoint("TOPLEFT", sb.canvas, "TOPLEFT", 12, sb.y)
    local txtLustMove = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtLustMove:SetWordWrap(true)
    txtLustMove:SetWidth(600)
    txtLustMove:SetJustifyH("LEFT")
    txtLustMove:SetTextColor(0.7, 0.9, 1.0)
    txtLustMove:SetText(L("TIP_LUST_BAR_MOVE"))
    txtLustMove:SetPoint("TOPLEFT", txtHelp, "BOTTOMLEFT", 0, -6)
    sb.y = sb.y - 0
    sb:Finish()
end
local fLoad = CreateFrame("Frame")
fLoad:RegisterEvent("ADDON_LOADED")
fLoad:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName and _G.WidgetForge and _G.WidgetForge.RegisterWidgetType then
        _G.WidgetForge:RegisterWidgetType({
            typeID = "Party Defensives & Utility",
            name = WFL_WIDGET("Party Defensives & Utility", "Def / Ult Sync"),
            description = WFL_WIDGET_DESC("Party Defensives & Utility", "Tracks group defensives, bloodlust, and combat res cooldowns."),
            Load = function(_, parent, elem) return Sync:Load(parent, elem) end,
            CreateSettings = function(_, parentFrame) Sync:CreateSettings(parentFrame) end,
            defaultConfig = {
                barWidth = 220,
                barHeight = 24,
                iconSize = 24,
                spacing = 2,
                showIcon = true,
                fontSize = 12,
                fontOutline = "OUTLINE",
                barBgAlpha = 80,
                iconZoom = 0.08,
                barBorderSize = 1,
                iconBorderSize = 1,
                lustShowIcon = true,
                colorReady = {0.2, 0.8, 1.0, 1},
                colorOnCD = {1.0, 0.5, 0.0, 1},
                lustPosX = 0,
                lustPosY = 120,
                lustBarWidth = 264,
                lustBarHeight = 36,
                lustIconSize = 36,
                lustTexture = "Smooth",
                lustColorStart = {1.0, 0.2, 0.2, 1},
                lustColorEnd = {1.0, 0.9, 0.1, 1},
                lustWarnSeconds = 8,
                catEXT_DEF = true,
                catPARTY_DEF = true,
                catLUST = true,
                catCR = true,
                attachToParty = false,
                partyAttachSide = "RIGHT",
                partyGrowDirection = "HORIZONTAL",
                announceDefs = false,
                announceChannel = "PARTY",
                partySync = true,
                hideOwnBars = false,
                partyOffsetX = 5,
                partyOffsetY = 0
            }
        })
    end
end)
