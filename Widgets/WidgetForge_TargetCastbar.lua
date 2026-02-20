-- =========================================================================
--  WidgetForge - Target Castbar Module
--  [API 12 FINAL STABLE] Independent Layout + Perfect Symmetry & Zoom
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.TargetCastbar = {}
local TargetCastbar = _G.WidgetForge.TargetCastbar
addonTable.TargetCastbar = TargetCastbar

TargetCastbar.Instances = {}

-- ============================================================================
-- 1. MANUEL INTERRUPT CD TAKİBİ
-- ============================================================================
local INTERRUPT_DATA = {
    WARRIOR = { DEFAULT = {id = 6552, cd = 15} },
    ROGUE   = { DEFAULT = {id = 1766, cd = 15} },
    MAGE    = { DEFAULT = {id = 2139, cd = 24} },
    DEATHKNIGHT = { DEFAULT = {id = 47528, cd = 15} },
    PALADIN = { DEFAULT = {id = 96231, cd = 15} },
    MONK    = { DEFAULT = {id = 116705, cd = 15} },
    DEMONHUNTER = { DEFAULT = {id = 183752, cd = 15} },
    EVOKER  = { DEFAULT = {id = 351338, cd = 20} },
    WARLOCK = { DEFAULT = {id = 119914, cd = 24} },
    SHAMAN  = { DEFAULT = {id = 57994, cd = 12}, [3] = {id = 57994, cd = 30} },
    PRIEST  = { DEFAULT = {id = 0, cd = 0}, [3] = {id = 15487, cd = 45} },
    HUNTER  = { DEFAULT = {id = 147362, cd = 24}, [3] = {id = 187707, cd = 15} },
    DRUID   = { DEFAULT = {id = 106839, cd = 15}, [1] = {id = 78675, cd = 60} },
}

TargetCastbar.interruptID = 0
TargetCastbar.interruptCD = 0
TargetCastbar.nextReadyTime = 0

function TargetCastbar:LoadClassInterrupt()
    local class = select(2, UnitClass("player"))
    local data = INTERRUPT_DATA[class]
    if not data then self.interruptID = 0; self.interruptCD = 0; return end
    local specIndex = GetSpecialization() or 0
    local specData = data[specIndex] or data.DEFAULT
    if specData then self.interruptID = specData.id; self.interruptCD = specData.cd
    else self.interruptID = 0; self.interruptCD = 0 end
end

TargetCastbar:LoadClassInterrupt()

local trackerFrame = CreateFrame("Frame")
trackerFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
trackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
trackerFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == TargetCastbar.interruptID then
            TargetCastbar.nextReadyTime = GetTime() + TargetCastbar.interruptCD
        end
    else
        TargetCastbar:LoadClassInterrupt()
    end
end)

-- ============================================================================
-- 2. DURATION OBJESİ (Secret Number Safe)
-- ============================================================================
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

-- ============================================================================
-- 3. LOAD (BAĞIMSIZ İKON VE BAR MİMARİSİ)
-- ============================================================================
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

    -- [1] BAĞIMSIZ İKON ÇERÇEVESİ
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
    
    -- DİNAMİK İKON ZOOM
    local z = elem.iconZoom or 0.08
    container.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    
    if not showIcon then container.iconBg:Hide() end

    -- [2] BAĞIMSIZ BAR ÇERÇEVESİ
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

    -- NORMAL BAR
    container.bar = CreateFrame("StatusBar", nil, container.barBg)
    container.bar:SetStatusBarTexture(texPath)
    container.bar:SetPoint("TOPLEFT", container.barBg, "TOPLEFT", barMargin, -barMargin)
    container.bar:SetPoint("BOTTOMRIGHT", container.barBg, "BOTTOMRIGHT", -barMargin, barMargin)
    container.bar:SetMinMaxValues(0, 100)

    -- SHIELD BAR
    container.shieldBar = CreateFrame("StatusBar", nil, container.barBg)
    container.shieldBar:SetStatusBarTexture(texPath)
    container.shieldBar:SetAllPoints(container.bar)
    container.shieldBar:SetFrameLevel(container.bar:GetFrameLevel() + 1)
    container.shieldBar:SetStatusBarColor(unpack(elem.colorShielded or {0.45, 0.45, 0.6, 1}))
    container.shieldBar:SetAlpha(0)

    -- TEXT FRAME
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
    container.spellName:SetText("No Target")

    container.timer = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timer:SetPoint("RIGHT", container.textFrame, "RIGHT", -5, 0)
    container.timer:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.timer:SetTextColor(unpack(textColor))
    container.timer:SetText("0.0s")

    container:SetAlpha(0)
    container.durationObj = nil
    container.isChanneling = false
    container.isInterrupted = false

    local function UpdateNormalBarColor()
        local db = container.elem
        if container.isInterrupted then
            container.bar:SetStatusBarColor(unpack(db.colorSuccess or {0.1, 1.0, 0.3, 1}))
            return
        end
        local ready = true
        if TargetCastbar.interruptID > 0 and GetTime() < TargetCastbar.nextReadyTime then ready = false end
        if ready then
            container.bar:SetStatusBarColor(unpack(db.colorReady or {1.0, 0.72, 0.04, 1}))
        else
            container.bar:SetStatusBarColor(unpack(db.colorOnCD or {1.0, 0.2, 0.2, 1}))
        end
    end

    local function UpdateCastInfo(event, unit)
        if unit and unit ~= "target" and not container.isTesting then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            local name, texture, notInt
            if event == "UNIT_SPELLCAST_START" then
                name, _, texture, _, _, _, _, notInt = UnitCastingInfo("target")
                container.isChanneling = false
            else
                name, _, texture, _, _, _, notInt = UnitChannelInfo("target")
                container.isChanneling = true
            end

            container.isInterrupted = false

            if container.isTesting then
                name = "Pyroblast (Test)"
                texture = 135808
                container.durationObj = CreateDurationObject(GetTime()*1000,(GetTime()+3)*1000)
                container.shieldBar:SetAlpha(0)
            else
                if not name then container:SetAlpha(0) return end
                container.durationObj = container.isChanneling and _G.UnitChannelDuration("target") or _G.UnitCastingDuration("target")

                if container.shieldBar.SetAlphaFromBoolean then
                    container.shieldBar:SetAlphaFromBoolean(notInt,1,0)
                else
                    if type(notInt) == "boolean" then container.shieldBar:SetAlpha(notInt and 1 or 0) end
                end
            end

            if not container.durationObj then container:SetAlpha(0) return end

            container.spellName:SetText(name)
            container.icon:SetTexture(texture or 134400)

            local totalDur = container.durationObj:GetTotalDuration()
            container.bar:SetMinMaxValues(0,totalDur)
            container.shieldBar:SetMinMaxValues(0,totalDur)

            UpdateNormalBarColor()
            container:SetAlpha(1)

        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then container.shieldBar:SetAlpha(1)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then container.shieldBar:SetAlpha(0)
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            container.isInterrupted = true
            UpdateNormalBarColor()
            container.spellName:SetText("KESILDI")
            C_Timer.After(0.75,function()
                if container.isInterrupted then
                    container:SetAlpha(0)
                    container.isInterrupted = false
                end
            end)
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            if not container.isInterrupted then container:SetAlpha(0); container.durationObj = nil end
        end
    end

    container:RegisterUnitEvent("UNIT_SPELLCAST_START","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_STOP","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_FAILED","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE","target")
    container:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE","target")
    container:RegisterEvent("PLAYER_TARGET_CHANGED")

    container:SetScript("OnEvent",function(self,event,...)
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

    container:SetScript("OnUpdate",function(self)
        if self:GetAlpha()==0 or not self.durationObj then return end

        if not self.isTesting then
            local still = self.isChanneling and UnitChannelInfo("target") or UnitCastingInfo("target")
            if not still and not self.isInterrupted then self:SetAlpha(0); return end
        end

        local rem = self.durationObj:GetRemainingDuration()
        local val = self.isChanneling and rem or self.durationObj:GetElapsedDuration()

        self.bar:SetValue(val)
        self.shieldBar:SetValue(val)
        self.timer:SetText(string.format("%.1f",rem))

        UpdateNormalBarColor()

        if self.isTesting and rem<=0 then UpdateCastInfo("UNIT_SPELLCAST_START","target") end
    end)

    table.insert(TargetCastbar.Instances,container)
    container.Unload = function(self)
        for i,inst in ipairs(TargetCastbar.Instances) do
            if inst==self then table.remove(TargetCastbar.Instances,i); break end
        end
    end

    return container
end

-- =========================================================================
--  4. AYARLAR MENÜSÜ (ÖZEL İSTEĞE GÖRE SIRALANMIŞ)
-- =========================================================================
function TargetCastbar:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    local Skin = _G.ForgeSkin

    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    parentFrame.isTestingGlobal = parentFrame.isTestingGlobal or false
    
    local function RefreshLive()
        if barIndex and _G.WidgetForge then
            _G.WidgetForge:RebuildBarComponents(barIndex)
            if parentFrame.isTestingGlobal then
                for _, inst in ipairs(TargetCastbar.Instances) do
                    if inst.elem == elem then 
                        inst.isTesting = true
                        inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target") 
                    end
                end
            end
        end
    end

    -- --- TEST MODU BUTONU ---
    if not parentFrame.testBtnCreated then
        local btnTest = Skin:CreateButton(f.content, "Test Mode: OFF", 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnCreated = btnTest
        
        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal then 
                btnTest:SetBackdropColor(0, 0.8, 0, 1)
                btnTest.text:SetText("Test Mode: ON")
            else 
                btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                btnTest.text:SetText("Test Mode: OFF") 
            end
        end
        
        UpdateTestButtonVisuals()
        
        btnTest:SetScript("OnEnter", function()
            if parentFrame.isTestingGlobal then btnTest:SetBackdropColor(0, 1, 0, 1) 
            else btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
        end)
        btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
        
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal = not parentFrame.isTestingGlobal
            UpdateTestButtonVisuals()
            
            for _, inst in ipairs(TargetCastbar.Instances) do
                if inst.elem == elem then 
                    inst.isTesting = parentFrame.isTestingGlobal
                    if parentFrame.isTestingGlobal then inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target")
                    else inst:SetAlpha(0) end
                end
            end
        end)
        
        if not parentFrame.onCloseWidgetSpecific then
             parentFrame.onCloseWidgetSpecific = function() 
                 parentFrame.isTestingGlobal = false
                 for _, inst in ipairs(TargetCastbar.Instances) do inst.isTesting = false; inst:SetAlpha(0) end
             end
        end
    end

    -- Doku (Texture) ve Font listelerini dropdownlar için önceden hazırla
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

    -- [GRUP 1] BAR & TEXT AYARLARI (Birleştirilmiş Grup)
    sb:AddHeader("Bar & Text Settings")
    
    -- Satır 1
    sb:AddSlider("barHeight", "Bar Height", 10, 60, 1, 25, elem, RefreshLive)
    sb:AddSlider("barWidth", "Bar Width", 50, 600, 5, 200, elem, RefreshLive)
    
    -- Satır 2
    sb:AddSlider("barBgAlpha", "Background Alpha (%)", 0, 100, 5, 80, elem, RefreshLive)
    sb:AddDropdown("texture", "Bar Texture", texItems, "Smooth", elem, RefreshLive)
    
    -- Satır 3
    sb:AddColor("barBorderColor", "Bar Border Color", {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("barBorderSize", "Border Thickness (0 to Disable)", 0, 5, 1, 1, elem, RefreshLive)
    
    -- Satır 4
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 12, elem, RefreshLive)
    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, RefreshLive)
    
    -- Satır 5
    sb:AddColor("textColor", "Text Color", {1, 1, 1, 1}, elem, RefreshLive)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)

    -- [GRUP 2] İKON AYARLARI
    sb:AddHeader("Icon Settings")
    sb:AddCheckbox("showIcon", "Show Spell Icon", true, elem, RefreshLive)
    sb:AddSlider("iconSpacing", "Spacing from Bar", 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("iconSize", "Icon Size", 10, 100, 1, 25, elem, RefreshLive)
    sb:AddSlider("iconZoom", "Icon Zoom (Crop Border)", 0, 0.20, 0.01, 0.08, elem, RefreshLive)
    sb:AddColor("iconBorderColor", "Icon Border Color", {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddSlider("iconBorderSize", "Border Thickness (0 to Disable)", 0, 5, 1, 1, elem, RefreshLive)

    -- [GRUP 3] DURUM RENKLERİ
    sb:AddHeader("Status Colors")
    sb:AddColor("colorReady", "1. Can Interrupt (Ready)", {1.0, 0.72, 0.04, 1}, elem, RefreshLive)
    sb:AddColor("colorSuccess", "2. Interrupted (Success)", {0.1, 1.0, 0.3, 1}, elem, RefreshLive)
    sb:AddColor("colorOnCD", "3. Cannot Interrupt (On CD)", {1.0, 0.2, 0.2, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", "4. Not Interruptible (Shield)", {0.45, 0.45, 0.6, 1}, elem, RefreshLive)

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