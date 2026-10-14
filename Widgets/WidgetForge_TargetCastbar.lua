local addonName, addonTable = ...
local L = WFL
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.TargetCastbar = {}
local TargetCastbar = _G.WidgetForge.TargetCastbar
addonTable.TargetCastbar = TargetCastbar
TargetCastbar.Instances = {}

local function SafeBool(v)
    local ok, result = pcall(function() return v == true end)
    return ok and result or false
end

local function SafeNum(v, default)
    local ok, result = pcall(function() return v + 0 end)
    return ok and result or (default or 0)
end

local function SafeVal(v, default)
    local ok, result = pcall(function() return v end)
    return ok and result or default
end

function TargetCastbar:HasActiveInstances()
    return self.Instances and #self.Instances > 0
end

function TargetCastbar:UpdateSpecTracker()
    if not self.specTrackerFrame then return end
    self.specTrackerFrame:UnregisterAllEvents()
    if not self:HasActiveInstances() then return end
    self.specTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.specTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.specTrackerFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.specTrackerFrame:RegisterEvent("SPELLS_CHANGED")
end

local INTERRUPT_DATA = {
    WARRIOR = { DEFAULT = {ids = {6552}} },
    ROGUE   = { DEFAULT = {ids = {1766}} },
    MAGE    = { DEFAULT = {ids = {2139}} },
    DEATHKNIGHT = { DEFAULT = {ids = {47528}} },
    PALADIN = { DEFAULT = {ids = {96231}} },
    MONK    = { DEFAULT = {ids = {116705}} },
    DEMONHUNTER = { DEFAULT = {ids = {183752}} },
    EVOKER  = { DEFAULT = {ids = {351338}} },
    WARLOCK = { DEFAULT = {ids = {119914, 132409, 19647}} },
    SHAMAN  = { DEFAULT = {ids = {57994}} },
    PRIEST  = { DEFAULT = {ids = {0}}, [3] = {ids = {15487}} },
    HUNTER  = { DEFAULT = {ids = {147362}}, [3] = {ids = {187707}} },
    DRUID   = { DEFAULT = {ids = {106839}}, [1] = {ids = {78675, 106839}} },
}

TargetCastbar.interruptIDs = {}

function TargetCastbar:LoadClassInterrupt()
    local class = select(2, UnitClass("player"))
    local data = INTERRUPT_DATA[class]
    self.interruptIDs = {}
    if not data then return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex] or data.DEFAULT
    if specData and type(specData.ids) == "table" then
        for _, id in ipairs(specData.ids) do
            if id and id > 0 then
                self.interruptIDs[#self.interruptIDs + 1] = id
            end
        end
    end
end
TargetCastbar:LoadClassInterrupt()

local specTrackerFrame = CreateFrame("Frame")
TargetCastbar.specTrackerFrame = specTrackerFrame
specTrackerFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    TargetCastbar:LoadClassInterrupt()
    for _, inst in ipairs(TargetCastbar.Instances) do
        if inst.UpdateNormalBarColor then
            inst.UpdateNormalBarColor()
        end
    end
end)
TargetCastbar:UpdateSpecTracker()

local function CreateDurationObject(s, e)
    local obj = {}
    obj.GetTotalDuration = function() return (e - s) / 1000 end
    obj.GetRemainingDuration = function()
        local t = (e - (GetTime()*1000))/1000
        return (t < 0) and 0 or t
    end
    obj.GetElapsedDuration = function()
        local t = ((GetTime()*1000) - s)/1000
        return (t < 0) and 0 or t
    end
    return obj
end

if not _G.UnitCastingDuration then
    _G.UnitCastingDuration = function(u)
        local _,_,_,s,e = UnitCastingInfo(u)
        return CreateDurationObject(s or 0, e or 0)
    end
end

if not _G.UnitChannelDuration then
    _G.UnitChannelDuration = function(u)
        local _,_,_,s,e = UnitChannelInfo(u)
        return CreateDurationObject(s or 0, e or 0)
    end
end

function TargetCastbar:Load(parent, elem)
    local Skin = _G.ForgeSkin
    local container = CreateFrame("Frame", nil, parent)
    local barWidth = elem.barWidth or elem.widgetWidth or 200
    local barHeight = elem.barHeight or elem.widgetHeight or 25
    local iconSize = elem.iconSize or elem.widgetHeight or 25
    local iconSpacing = elem.iconSpacing or 5
    local showIcon = (elem.showIcon == nil) and true or elem.showIcon
    local totalWidth = showIcon and (iconSize + iconSpacing + barWidth) or barWidth
    local totalHeight = showIcon and math.max(iconSize, barHeight) or barHeight
    container:SetSize(totalWidth, totalHeight)
    container.elem = elem
    container.isTesting = false

    local bgAlpha = (elem.barBgAlpha or 80) / 100

    container.iconBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.iconBg:SetSize(iconSize, iconSize)
    container.iconBg:SetPoint("LEFT", container, "LEFT", 0, 0)
    local iconBSize = elem.iconBorderSize or 1
    if iconBSize < 0 then iconBSize = 0 end
    local showIconBorder = (iconBSize > 0)
    Skin:ApplyBackdrop(container.iconBg)
    container.iconBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.iconBg:SetBackdropColor(0.1, 0.1, 0.1, bgAlpha)
    if showIconBorder then
        container.iconBg:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        container.iconBg:SetBackdropBorderColor(0, 0, 0, 0)
    end
    local iconPad = showIconBorder and iconBSize or 0
    local iconMargin = iconPad + 1
    container.icon = container.iconBg:CreateTexture(nil, "OVERLAY")
    container.icon:SetPoint("TOPLEFT", container.iconBg, "TOPLEFT", iconMargin, -iconMargin)
    container.icon:SetPoint("BOTTOMRIGHT", container.iconBg, "BOTTOMRIGHT", -iconMargin, iconMargin)
    local z = elem.iconZoom or 0.08
    container.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    if not showIcon then container.iconBg:Hide() end

    container.barBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.barBg:SetSize(barWidth, barHeight)
    if showIcon then
        container.barBg:SetPoint("LEFT", container.iconBg, "RIGHT", iconSpacing, 0)
    else
        container.barBg:SetPoint("LEFT", container, "LEFT", 0, 0)
    end
    local barBSize = elem.barBorderSize or 1
    if barBSize < 0 then barBSize = 0 end
    local showBarBorder = (barBSize > 0)
    Skin:ApplyBackdrop(container.barBg)
    container.barBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = showBarBorder and barBSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.barBg:SetBackdropColor(0.1, 0.1, 0.1, bgAlpha)
    if showBarBorder then
        container.barBg:SetBackdropBorderColor(unpack(elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        container.barBg:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local texPath = Skin.Media.Textures.Smooth or "Interface\\TargetingFrame\\UI-StatusBar"
    if Skin and Skin.Media and Skin.Media.Textures and elem.texture then texPath = Skin.Media.Textures[elem.texture] or texPath end

    local barPad = showBarBorder and barBSize or 0
    local barMargin = barPad + 1
    container.bar = CreateFrame("StatusBar", nil, container.barBg)
    container.bar:SetStatusBarTexture(texPath)
    container.bar:SetPoint("TOPLEFT", container.barBg, "TOPLEFT", barMargin, -barMargin)
    container.bar:SetPoint("BOTTOMRIGHT", container.barBg, "BOTTOMRIGHT", -barMargin, barMargin)
    container.bar:SetMinMaxValues(0, 100)

    container.shieldBar = CreateFrame("StatusBar", nil, container.barBg)
    container.shieldBar:SetStatusBarTexture(texPath)
    container.shieldBar:SetAllPoints(container.bar)
    container.shieldBar:SetFrameLevel(container.bar:GetFrameLevel() + 1)
    container.shieldBar:SetStatusBarColor(unpack(elem.colorShielded or {0.45, 0.45, 0.6, 1}))
    container.shieldBar:SetAlpha(0)

    container.textFrame = CreateFrame("Frame", nil, container.barBg)
    container.textFrame:SetAllPoints(container.bar)
    container.textFrame:SetFrameLevel(container.shieldBar:GetFrameLevel() + 5)

    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then fontPath = Skin.Media.Fonts[elem.font] or fontPath end
    local textColor = elem.textColor or {1, 1, 1, 1}
    container.spellName = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.spellName:SetPoint("LEFT", container.textFrame, "LEFT", 5, 0)
    container.spellName:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.spellName:SetTextColor(unpack(textColor))
    container.spellName:SetText(L("LABEL_NO_TARGET"))

    container.timer = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timer:SetPoint("RIGHT", container.textFrame, "RIGHT", -5, 0)
    container.timer:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.timer:SetTextColor(unpack(textColor))
    container.timer:SetText("0.0s")

    container:SetAlpha(0)
    container.durationObj = nil
    container.isChanneling = false
    container.isInterrupted = false
    container.interruptTime = 0
    container.notInterruptible = false

    local function PlayerKnowsInterrupt(id)
        if not id or id == 0 then return false end
        if C_Spell and C_Spell.IsSpellKnown then
            local ok, v = pcall(C_Spell.IsSpellKnown, id)
            if ok and v then return true end
        end
        if IsPlayerSpell then
            local ok, v = pcall(IsPlayerSpell, id)
            if ok and v then return true end
        end
        if IsSpellKnown then
            local ok, v = pcall(IsSpellKnown, id, true)
            if ok and v then return true end
        end
        return false
    end

    local function GetActiveInterruptID()
        local ids = TargetCastbar.interruptIDs
        if not ids then return nil end
        for _, id in ipairs(ids) do
            if PlayerKnowsInterrupt(id) then return id end
        end
        return nil
    end

    local function IsInterruptOnCooldown(spellID)
        if not spellID then return false end
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
            if ok and info then
                local isActive = info.isActive
                local isOnGCD = info.isOnGCD
                local secret = issecretvalue and (issecretvalue(isActive) or issecretvalue(isOnGCD))
                if not secret and isActive ~= nil and isOnGCD ~= nil then
                    return (isActive and not isOnGCD) and true or false
                end
                local st = SafeNum(info.startTime, 0)
                local dur = SafeNum(info.duration, 0)
                return (st > 0 and dur > 1.5)
            end
        end
        if GetSpellCooldown then
            local ok, startTime, duration = pcall(GetSpellCooldown, spellID)
            if ok then
                local st = SafeNum(startTime, 0)
                local dur = SafeNum(duration, 0)
                return (st > 0 and dur > 1.5)
            end
        end
        return false
    end

    local function IsInterruptUsable(spellID)
        if not spellID then return true, true end
        local usable = true
        local inRange = true

        if C_Spell and C_Spell.IsSpellUsable then
            local ok, u = pcall(C_Spell.IsSpellUsable, spellID)
            if ok and u ~= nil then
                if not (issecretvalue and issecretvalue(u)) then
                    usable = u and true or false
                end
            end
        elseif IsUsableSpell then
            local ok, u = pcall(IsUsableSpell, spellID)
            if ok and u ~= nil then
                if not (issecretvalue and issecretvalue(u)) then
                    usable = u and true or false
                end
            end
        end

        if C_Spell and C_Spell.IsSpellInRange then
            local ok, r = pcall(C_Spell.IsSpellInRange, spellID, "target")
            if ok and r ~= nil then
                if not (issecretvalue and issecretvalue(r)) then
                    if type(r) == "number" then
                        inRange = (r == 1)
                    else
                        inRange = r and true or false
                    end
                end
            end
        elseif IsSpellInRange then
            local ok, r = pcall(IsSpellInRange, spellID, "target")
            if ok and r ~= nil then
                if type(r) == "number" then
                    inRange = (r == 1)
                else
                    inRange = r and true or false
                end
            end
        end

        return usable, inRange
    end

    local function UpdateNormalBarColor()
        local db = container.elem
        if container.isInterrupted then
            container.bar:SetStatusBarColor(unpack(db.colorSuccess or {0.1, 1.0, 0.3, 1}))
            return
        end

        local activeIntID = GetActiveInterruptID()
        if not activeIntID then
            container.bar:SetStatusBarColor(unpack(db.colorReady or {1.0, 0.72, 0.04, 1}))
            return
        end

        local usable, inRange = IsInterruptUsable(activeIntID)
        if not usable or inRange == false then
            container.bar:SetStatusBarColor(unpack(db.colorUnusable or {0.5, 0.5, 0.5, 1}))
            return
        end

        if IsInterruptOnCooldown(activeIntID) then
            container.bar:SetStatusBarColor(unpack(db.colorOnCD or {1.0, 0.2, 0.2, 1}))
            return
        end

        container.bar:SetStatusBarColor(unpack(db.colorReady or {1.0, 0.72, 0.04, 1}))
    end
    container.UpdateNormalBarColor = UpdateNormalBarColor

    local function UpdateCastInfo(event, unit)
        if unit and unit ~= "target" and not container.isTesting then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            local name, texture, startTimeMS, endTimeMS, notInt
            if event == "UNIT_SPELLCAST_START" then
                name, _, texture, startTimeMS, endTimeMS, _, _, notInt = UnitCastingInfo("target")
                container.isChanneling = false
            else
                name, _, texture, startTimeMS, endTimeMS, _, notInt = UnitChannelInfo("target")
                container.isChanneling = true
            end

            container.isInterrupted = false
            container:SetAlpha(1)

            if container.isTesting then
                name = L("TARGETCASTBAR_TEST_SPELL")
                texture = 135808
                container.durationObj = CreateDurationObject(GetTime()*1000,(GetTime()+3)*1000)
                container.shieldBar:SetAlpha(0)
            else
                if not name then container:SetAlpha(0) return end
                local durObj = container.isChanneling and _G.UnitChannelDuration and _G.UnitChannelDuration("target") or (_G.UnitCastingDuration and _G.UnitCastingDuration("target"))
                if not durObj and startTimeMS and endTimeMS then
                    durObj = CreateDurationObject(startTimeMS, endTimeMS)
                end
                container.durationObj = durObj
                container.shieldBar:SetAlpha(notInt and 1 or 0)
            end

            if not container.durationObj then container:SetAlpha(0) return end
            container.spellName:SetText(name)
            container.icon:SetTexture(texture or 134400)
            local totalDur = container.durationObj:GetTotalDuration()
            container.bar:SetMinMaxValues(0,totalDur)
            container.shieldBar:SetMinMaxValues(0,totalDur)
            UpdateNormalBarColor()

        elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            if container.isTesting then return end
            local name, texture, startTimeMS, endTimeMS, notInt
            if container.isChanneling then
                name, _, texture, startTimeMS, endTimeMS, _, notInt = UnitChannelInfo("target")
            else
                name, _, texture, startTimeMS, endTimeMS, _, _, notInt = UnitCastingInfo("target")
            end
            if name and startTimeMS and endTimeMS then
                local durObj = container.isChanneling and _G.UnitChannelDuration and _G.UnitChannelDuration("target") or (_G.UnitCastingDuration and _G.UnitCastingDuration("target"))
                if not durObj then
                    durObj = CreateDurationObject(startTimeMS, endTimeMS)
                end
                container.durationObj = durObj
                local totalDur = durObj:GetTotalDuration()
                container.bar:SetMinMaxValues(0, totalDur)
                container.shieldBar:SetMinMaxValues(0, totalDur)
            end

        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            container.notInterruptible = true
            container.shieldBar:SetAlpha(1)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            container.notInterruptible = false
            container.shieldBar:SetAlpha(0)
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            container.isInterrupted = true
            container.interruptTime = GetTime()
            UpdateNormalBarColor()
            container.spellName:SetText(L("LABEL_SUCCESS"))
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            if not container.isInterrupted then container:SetAlpha(0); container.durationObj = nil end
        end
    end

    container:RegisterUnitEvent("UNIT_SPELLCAST_START","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_STOP","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_FAILED","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE","target")
    container:RegisterEvent("PLAYER_TARGET_CHANGED")
    container:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    container:RegisterEvent("SPELL_UPDATE_USABLE")

    container:SetScript("OnEvent",function(self,event,...)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
            if self:GetAlpha() > 0 or self.isTesting then
                UpdateNormalBarColor()
            end
            return
        end
        if event=="PLAYER_TARGET_CHANGED" then
            if self.isTesting then return end
            local still = UnitCastingInfo("target") or UnitChannelInfo("target")
            if still then
                if UnitChannelInfo("target") then UpdateCastInfo("UNIT_SPELLCAST_CHANNEL_START","target")
                else UpdateCastInfo("UNIT_SPELLCAST_START","target") end
            else
                self:SetAlpha(0)
            end
        else
            UpdateCastInfo(event,...)
        end
    end)

    container.colorElapsed = 0
    container:SetScript("OnUpdate",function(self, dt)
        if self:GetAlpha()==0 or not self.durationObj then return end
        if self.isInterrupted then
            local elapsedFade = GetTime() - self.interruptTime
            if elapsedFade < 0.5 then
                self:SetAlpha(1 - (elapsedFade / 0.5))
            else
                self:SetAlpha(0)
                self.isInterrupted = false
            end
            return
        end

        if not self.isTesting then
            local still = self.isChanneling and UnitChannelInfo("target") or UnitCastingInfo("target")
            if not still then self:SetAlpha(0); return end
        end

        local rem = self.durationObj:GetRemainingDuration()
        local val = self.isChanneling and rem or self.durationObj:GetElapsedDuration()
        self.bar:SetValue(val)
        self.shieldBar:SetValue(val)
        self.timer:SetText(string.format("%.1f",rem))

        self.colorElapsed = (self.colorElapsed or 0) + (dt or 0)
        if self.colorElapsed >= 0.10 then
            self.colorElapsed = 0
            UpdateNormalBarColor()
        end

        if self.isTesting and rem<=0 then UpdateCastInfo("UNIT_SPELLCAST_START","target") end
    end)

    table.insert(TargetCastbar.Instances,container)
    TargetCastbar:UpdateSpecTracker()

    container.Unload = function(self)
        for i,inst in ipairs(TargetCastbar.Instances) do
            if inst==self then table.remove(TargetCastbar.Instances,i); break end
        end
        TargetCastbar:UpdateSpecTracker()
    end

    return container
end

function TargetCastbar:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    local Skin = _G.ForgeSkin
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb
    parentFrame.isTestingGlobal_TargetCastbar = parentFrame.isTestingGlobal_TargetCastbar or false

    local function RefreshLive()
        if barIndex and _G.WidgetForge then
            _G.WidgetForge:RebuildBarComponents(barIndex)
            if parentFrame.isTestingGlobal_TargetCastbar then
                for _, inst in ipairs(TargetCastbar.Instances) do
                    if inst.elem == elem then
                        inst.isTesting = true
                        inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target")
                    end
                end
            end
        end
    end

    if not parentFrame.testBtnTargetCastbar then
        local btnTest = Skin:CreateButton(f.content, L("LABEL_TEST_MODE_OFF"), 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnTargetCastbar = btnTest

        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal_TargetCastbar then
                btnTest:SetBackdropColor(0, 0.8, 0, 1)
                btnTest.text:SetText(L("LABEL_TEST_MODE_ON"))
            else
                btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                btnTest.text:SetText(L("LABEL_TEST_MODE_OFF"))
            end
        end
        UpdateTestButtonVisuals()

        btnTest:SetScript("OnEnter", function()
            if parentFrame.isTestingGlobal_TargetCastbar then btnTest:SetBackdropColor(0, 1, 0, 1)
            else btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
        end)
        btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal_TargetCastbar = not parentFrame.isTestingGlobal_TargetCastbar
            UpdateTestButtonVisuals()
            for _, inst in ipairs(TargetCastbar.Instances) do
                if inst.elem == elem then
                    inst.isTesting = parentFrame.isTestingGlobal_TargetCastbar
                    if parentFrame.isTestingGlobal_TargetCastbar then inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target")
                    else inst:SetAlpha(0) end
                end
            end
        end)

        if not parentFrame.onCloseWidgetSpecific then
             parentFrame.onCloseWidgetSpecific = function()
                 parentFrame.isTestingGlobal_TargetCastbar = false
                 for _, inst in ipairs(TargetCastbar.Instances) do inst.isTesting = false; inst:SetAlpha(0) end
             end
        end
    else
        if parentFrame.testBtnTargetCastbar then
            parentFrame.testBtnTargetCastbar:Show()
        end
    end

    local texItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then
        for k, _ in pairs(Skin.Media.Textures) do table.insert(texItems, {text=tostring(k), value=k}) end
    end
    if #texItems == 0 then texItems = {{text=L("DEFAULT_OPTION"), value="Smooth"}}
    else table.sort(texItems, function(a,b) return a.text < b.text end) end

    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then
        for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=tostring(k), value=k}) end
    end
    if #fontItems == 0 then fontItems = {{text=L("DEFAULT_OPTION"), value="Fonts\\FRIZQT__.TTF"}}
    else table.sort(fontItems, function(a,b) return a.text < b.text end) end

    sb:AddHeader(L("HEADER_BAR_SETTINGS"))
    sb:AddSlider("barHeight", L("LABEL_BAR_HEIGHT"), 10, 60, 1, 25, elem, RefreshLive)
    sb:AddSlider("barWidth", L("LABEL_BAR_WIDTH"), 50, 600, 5, 200, elem, RefreshLive)
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
    sb:AddSlider("iconSize", L("LABEL_ICON_SIZE"), 10, 100, 1, 25, elem, RefreshLive)
    sb:AddSlider("iconZoom", L("LABEL_ICON_ZOOM_CROP"), 0, 0.20, 0.01, 0.08, elem, RefreshLive)
    sb:AddColor("iconBorderColor", L("LABEL_ICON_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("iconBorderSize", L("LABEL_BORDER_THICKNESS_DISABLE"), 0, 5, 1, 1, elem, RefreshLive)
    sb:AddHeader(L("HEADER_STATUS_COLORS"))
    sb:AddColor("colorReady", L("LABEL_CAN_INTERRUPT_READY"), {1.0, 0.72, 0.04, 1}, elem, RefreshLive)
    sb:AddColor("colorSuccess", L("LABEL_INTERRUPTED_SUCCESS"), {0.1, 1.0, 0.3, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", L("LABEL_CANNOT_INTERRUPT_ON_CD"), {1.0, 0.2, 0.2, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", L("LABEL_NOT_INTERRUPTIBLE_SHIELD"), {0.45, 0.45, 0.6, 1}, elem, RefreshLive)
    sb:AddColor("colorUnusable", L("LABEL_UNUSABLE_OUT_OF_RANGE"), {0.5, 0.5, 0.5, 1}, elem, RefreshLive)
    sb:Finish()

    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() and child ~= parentFrame.testBtnCreated then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then bottomY = childBottom end
                end
            end
        end
        if f.content.SetHeight then f.content:SetHeight(math.abs(bottomY - 40)) end
    end
end
