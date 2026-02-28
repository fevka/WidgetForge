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
CCSync.lastPartySize = 0
CCSync.hasBroadcasted = false

-- ============================================================================
-- 1. CC DATA (Dynamic CD Detection)
-- ============================================================================
local CC_DATA = {
    WARRIOR = { DEFAULT = {ids = {107570, 5246}, spellName = "Storm Bolt / Intimidating Shout", names = {"Storm Bolt", "Intimidating Shout"}} },
    ROGUE   = { DEFAULT = {ids = {408, 2094}, spellName = "Kidney Shot / Blind", names = {"Kidney Shot", "Blind"}}, [1] = {ids = {408}, names = {"Kidney Shot"}}, [2] = {ids = {408}, names = {"Kidney Shot"}}, [3] = {ids = {408}, names = {"Kidney Shot"}} },
    MAGE    = { DEFAULT = {ids = {122, 118}, spellName = "Frost Nova / Polymorph", names = {"Frost Nova", "Polymorph"}}, [3] = {ids = {122}, spellName = "Frost Nova", names = {"Frost Nova"}} },
    DEATHKNIGHT = { DEFAULT = {ids = {221562, 108194}, spellName = "Asphyxiate", names = {"Asphyxiate"}} },
    PALADIN = { DEFAULT = {ids = {853}, spellName = "Hammer of Justice", names = {"Hammer of Justice"}} },
    MONK    = { DEFAULT = {ids = {119381}, spellName = "Leg Sweep", names = {"Leg Sweep"}} },
    DEMONHUNTER = { DEFAULT = {ids = {179057}, spellName = "Chaos Nova", names = {"Chaos Nova"}} },
    EVOKER  = { DEFAULT = {ids = {372048, 357214}, spellName = "Oppressing Roar / Deep Breath", names = {"Oppressing Roar", "Deep Breath"}} },
    WARLOCK = { DEFAULT = {ids = {30283, 89766}, spellName = "Shadowfury / Axe Toss", names = {"Shadowfury", "Axe Toss"}} },
    SHAMAN  = { DEFAULT = {ids = {118345, 192058}, spellName = "Pulverize / Capacitor Totem", names = {"Pulverize", "Capacitor Totem"}} },
    PRIEST  = { DEFAULT = {ids = {8122}, spellName = "Psychic Scream", names = {"Psychic Scream"}} },
    HUNTER  = { DEFAULT = {ids = {3355, 24394, 109248}, spellName = "Freezing Trap / Intimidation", names = {"Freezing Trap", "Intimidation", "Binding Shot"}} },
    DRUID   = { DEFAULT = {ids = {5211}, spellName = "Mighty Bash", names = {"Mighty Bash"}} },
}

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
            local known = IsPlayerSpell(id)
            if not known and IsSpellKnown then known = IsSpellKnown(id) end
            if not known and IsSpellKnownOrOverridesKnown then known = IsSpellKnownOrOverridesKnown(id) end
            
            if known then
                table.insert(self.ccIDs, id)
            end
        end
        
        -- Pass 2: If we didn't find all expected spells, try name-based lookup for missing ones
        if #self.ccIDs < #specData.ids and specData.names then
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
                        local known = IsPlayerSpell(id)
                        if not known and IsSpellKnown then known = IsSpellKnown(id) end
                        if not known and IsSpellKnownOrOverridesKnown then known = IsSpellKnownOrOverridesKnown(id) end
                        
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
end

CCSync:LoadClassCC()

local specTrackerFrame = CreateFrame("Frame")
specTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
specTrackerFrame:SetScript("OnEvent", function(_, event)
    CCSync:LoadClassCC()
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

-- Flatten for spell ID lookup
local CC_SPELL_DATA = {}
for class, data in pairs(CC_DATA) do
    for specIdx, specData in pairs(data) do
        for _, id in ipairs(specData.ids) do
            CC_SPELL_DATA[id] = specData.spellName or "CC"
        end
    end
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
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
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

function CCSync:InitializeGroupBars(container)
    local activeNames = {}
    
    -- Self: always show if we have CC spells
    local myName = UnitName("player")
    if myName and self.knownSpells[myName] and #self.knownSpells[myName] > 0 then
        self:EnsureBarIsReady(container, myName, select(2, UnitClass("player")))
        activeNames[myName] = true
    end
    
    -- Party members: only show if they shared their spells via addon
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and 40 or 4
        for i=1, num do
            local unit = prefix..i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name and self.knownSpells[name] and #self.knownSpells[name] > 0 then
                    self:EnsureBarIsReady(container, name, select(2, UnitClass(unit)))
                    activeNames[name] = true
                end
            end
        end
    end

    -- Remove bars for players no longer active or without known spells
    if container.bars then
        for name, bar in pairs(container.bars) do
            if not activeNames[name] then
                bar:Hide()
                container.bars[name] = nil
            end
        end
    end
    self:RefreshBars(container)
end

function CCSync:EnsureBarIsReady(container, name, class)
    if not name or not class then return end
    
    -- Use known spells if available, otherwise fall back to class data
    local spellID = 0
    if self.knownSpells[name] and #self.knownSpells[name] > 0 then
        spellID = self.knownSpells[name][1]
    elseif CC_DATA[class] then
        local specData = CC_DATA[class].DEFAULT or {}
        spellID = specData.ids and specData.ids[1] or 0
    end
    
    if not container.bars[name] then
        local row = self:CreateBar(container, name)
        container.bars[name] = row
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
    if not CC_SPELL_DATA[spellID] then return end
    
    local name = UnitName(unit)
    if not name then return end
    
    -- We use a fallback duration or data lookup since WoW 11.0 C_Spell.GetSpellCooldown triggers taint errors mid-combat
    local duration = 60
    local specData = CC_DATA[select(2, UnitClass(unit))]
    if specData and specData.DEFAULT and specData.DEFAULT.cooldown then
        duration = specData.DEFAULT.cooldown
    end
    
    for _, container in ipairs(self.Instances) do
        self:UpdateBar(container, name, spellID, duration)
    end
    
    self:SendSync(spellID, duration)
end

function CCSync:SendSync(spellID, duration, timestamp)
    if not IsInGroup() then return end
    if not duration or duration <= 0 then return end
    
    local ts = timestamp or GetServerTime()
    local msg = string.format("CC:%d:%d:%d", spellID, duration, ts)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    
    C_ChatInfo.SendAddonMessage(self.commPrefix, msg, channel)
end

function CCSync:OnCommReceived(prefix, text, channel, sender)
    if prefix ~= self.commPrefix then return end
    sender = Ambiguate(sender, "none")
    
    if sender == UnitName("player") then return end
    
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
            
            if adjDur > 0 then
                for _, container in ipairs(self.Instances) do
                    self:UpdateBar(container, sender, spellID, adjDur)
                end
            end
        end
    end
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
    if not container.bars[senderName] then 
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
        if unitClass then self:EnsureBarIsReady(container, senderName, unitClass) end
    end
    
    local bar = container.bars[senderName]
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
    
    self.activeCooldowns = self.activeCooldowns or {}
    self.activeCooldowns[senderName] = { spellID = spellID, endTime = bar.endTime, duration = duration }
    
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

function CCSync:GetUnitFrame(unitName)
    if not unitName then return nil end
    local isPlayer = (unitName == UnitName("player"))
    
    if isPlayer then
        if ElvUF_Player and ElvUF_Player:IsVisible() then return ElvUF_Player end
        if PlayerFrame and PlayerFrame:IsVisible() then return PlayerFrame end
    end
    
    -- Find which unitId corresponds to this name
    local unitId = nil
    if isPlayer then unitId = "player"
    elseif IsInGroup() then
        for i = 1, 40 do
            local u = (IsInRaid() and "raid" or "party")..i
            if UnitName(u) == unitName then
                unitId = u
                break
            end
        end
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

    -- Fallback to player frame in test mode if frame not found
    if self.ForceTest and isPlayer then
        return PlayerFrame or UIParent
    end
    
    return nil
end

function CCSync:LayoutBars(container)
    local elem = container.elem
    local prev = nil
    local spacing = elem.spacing or 5
    local sortedNames = {}
    local attachMode = elem.attachToParty == true
    
    for name, _ in pairs(container.bars) do table.insert(sortedNames, name) end
    table.sort(sortedNames)
    
    local yOffset = 0
    
    for _, name in ipairs(sortedNames) do
        local bar = container.bars[name]
        if bar:IsShown() then
            bar:ClearAllPoints()
            
            if attachMode then
                -- Find party frame
                local targetFrame = self:GetUnitFrame(name)
                
                -- If testing and frame not found, fallback to anchoring to UIParent center or stack locally
                if not targetFrame and self.ForceTest then
                    if name == UnitName("player") then
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
                
                if targetFrame and not (self.ForceTest and not targetFrame and name ~= UnitName("player")) then
                    if bar:GetParent() ~= targetFrame then
                        bar:SetParent(targetFrame)
                    end
                    bar:SetFrameStrata(targetFrame:GetFrameStrata() or "MEDIUM")
                    bar:SetFrameLevel((targetFrame:GetFrameLevel() or 1) + 10)
                    
                    local offX = elem.partyOffsetX or 5
                    local offY = elem.partyOffsetY or 0
                    -- Default anchor right side of the unit frame
                    bar:SetPoint("LEFT", targetFrame, "RIGHT", offX, offY)
                else
                    -- If frame not found and not testing, un-anchor or hide
                    if not self.ForceTest then
                        bar:Hide()
                    end
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
        for name, bar in pairs(container.bars) do
            if name == "StunBoi" or name == "FreezeGal" or name == "SweepMaster" then
                bar:Hide()
                container.bars[name] = nil
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
                 CCSync:RefreshBars(inst)
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
    sb:AddSlider("partyOffsetX", "X Offset", -100, 100, 1, 5, elem, RefreshLive)
    sb:AddSlider("partyOffsetY", "Y Offset", -100, 100, 1, 0, elem, RefreshLive)

    sb:AddHeader("Party Sync")
    sb:AddSwitch("partySync", "Listen to party CC abilities", true, elem, RefreshLive)
    
    local txtHelp = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txtHelp:SetWordWrap(true)
    txtHelp:SetWidth(600)
    txtHelp:SetJustifyH("LEFT")
    txtHelp:SetTextColor(1, 0.82, 0)
    txtHelp:SetText("Note: For the Party Sync to function correctly and track your group members' CC abilities, all players in the party MUST have the WidgetForge addon installed.")
    
    sb.y = sb.y - 45
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
                    partyOffsetX = 5,
                    partyOffsetY = 0,
                }
            })
        end
    end
end)
