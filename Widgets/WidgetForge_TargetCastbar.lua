-- =========================================================================
--  WidgetForge - Target Castbar Module
--  Displays the current target's spell casting/channeling progress.
--  [API 12 FINAL FIX] Logic priority: Shield > Interrupt CD > Ready
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.TargetCastbar = {}
local TargetCastbar = _G.WidgetForge.TargetCastbar
addonTable.TargetCastbar = TargetCastbar

TargetCastbar.Instances = {}

-- [API 12 FIX] Duration Objesi Polyfill (BreakForge mantığıyla birebir)
local function CreateDurationObject(s, e)
    local obj = {}
    obj.GetTotalDuration = function() return (e - s) / 1000 end
    obj.GetRemainingDuration = function() local t = (e - (GetTime()*1000))/1000; return (t<0) and 0 or t end
    obj.GetElapsedDuration = function() local t = ((GetTime()*1000) - s)/1000; return (t<0) and 0 or t end
    return obj
end
if not _G.UnitCastingDuration then _G.UnitCastingDuration = function(u) local _,_,_,s,e=UnitCastingInfo(u); return CreateDurationObject(s or 0,e or 0) end end
if not _G.UnitChannelDuration then _G.UnitChannelDuration = function(u) local _,_,_,s,e=UnitChannelInfo(u); return CreateDurationObject(s or 0,e or 0) end end

-- --- WIDGET YÜKLEME VE ÇİZİM ---
function TargetCastbar:Load(parent, elem)
    local Skin = _G.ForgeSkin
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(elem.widgetWidth or 200, elem.widgetHeight or 25)
    container.elem = elem
    container.isTesting = false
    container.isShielded = false

    container.bg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.bg:SetAllPoints()
    Skin:ApplyBackdrop(container.bg)
    container.bg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    
    local isBorderShown = (elem.showBorder == nil) and true or elem.showBorder
    container.bg:SetBackdropBorderColor(0.3, 0.3, 0.3, isBorderShown and 1 or 0)

    local h = elem.widgetHeight or 25
    container.icon = container.bg:CreateTexture(nil, "OVERLAY")
    container.icon:SetSize(h - 4, h - 4)
    container.icon:SetPoint("LEFT", container.bg, "LEFT", 2, 0)
    container.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) 

    container.bar = CreateFrame("StatusBar", nil, container.bg)
    local texPath = Skin.Media.Textures.Smooth or "Interface\\TargetingFrame\\UI-StatusBar"
    if Skin and Skin.Media and Skin.Media.Textures and elem.texture then
        texPath = Skin.Media.Textures[elem.texture] or texPath
    end
    container.bar:SetStatusBarTexture(texPath)
    container.bar:SetPoint("TOPLEFT", container.icon, "TOPRIGHT", 2, 0)
    container.bar:SetPoint("BOTTOMRIGHT", container.bg, "BOTTOMRIGHT", -2, 2)
    container.bar:SetMinMaxValues(0, 100)
    container.bar:SetValue(0)

    container.spellName = container.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.spellName:SetPoint("LEFT", container.bar, "LEFT", 5, 0)
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then fontPath = Skin.Media.Fonts[elem.font] or fontPath end
    container.spellName:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.spellName:SetText("No Target")

    container.timer = container.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timer:SetPoint("RIGHT", container.bar, "RIGHT", -5, 0)
    container.timer:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.timer:SetText("0.0s")

    container:SetAlpha(0)
    container.durationObj = nil
    container.isChanneling = false
    container.isInterrupted = false

    -- [YENİ MANTIK]: Renklerin hiyerarşisi
    local function UpdateColors()
        -- 1. Öncelik: Büyü kesildi mi?
        if container.isInterrupted then
            container.bar:SetStatusBarColor(unpack(elem.colorInterrupted or {0, 1, 0, 1}))
            return
        end

        -- 2. Öncelik: Büyü kalkanlı (kesilemez) mı?
        if container.isShielded then
            container.bar:SetStatusBarColor(unpack(elem.colorShielded or {0.5, 0.5, 0.5, 1}))
            return
        end

        -- 3. Öncelik: Senin interrupt yeteneğin CD'de mi?
        local isReady = true
        if _G.BreakForge and _G.BreakForge.nextReadyTime then
            if GetTime() <= _G.BreakForge.nextReadyTime then
                isReady = false
            end
        end

        if isReady then
            container.bar:SetStatusBarColor(unpack(elem.colorReady or {1, 0.7, 0, 1}))
        else
            -- BreakForge'daki ColorCooldown rengi (Kırmızımsı)
            container.bar:SetStatusBarColor(unpack(elem.colorInterrupted or {1, 0, 0, 1})) 
        end
    end

    local function UpdateCastInfo(event, unit)
        if unit ~= "target" and not container.isTesting then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            local name, texture, durationObj
            if event == "UNIT_SPELLCAST_START" then
                name, _, texture = UnitCastingInfo("target")
                durationObj = _G.UnitCastingDuration("target")
                container.isChanneling = false
            else
                name, _, texture = UnitChannelInfo("target")
                durationObj = _G.UnitChannelDuration("target")
                container.isChanneling = true
            end

            if container.isTesting then
                name = "Pyroblast (Test)"; texture = 135808 
                durationObj = CreateDurationObject(GetTime()*1000, (GetTime()+3)*1000)
                container.isChanneling = false; container.isShielded = false 
            end

            if not name or not durationObj then container:SetAlpha(0); return end

            container.durationObj = durationObj
            container.spellName:SetText(name); container.icon:SetTexture(texture or 134400)
            container.isInterrupted = false; container.isShielded = false -- Başlarken reset
            container.bar:SetMinMaxValues(0, durationObj:GetTotalDuration())

            UpdateColors()
            container:SetAlpha(1)
            
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            container.isShielded = true
            UpdateColors()
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            container.isShielded = false
            UpdateColors()
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            if not container.isInterrupted then container:SetAlpha(0); container.durationObj = nil end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            container.isInterrupted = true
            UpdateColors()
            container.spellName:SetText("Interrupted")
            C_Timer.After(0.75, function() if container.isInterrupted then container:SetAlpha(0); container.isInterrupted = false end end)
        end
    end

    container:RegisterEvent("UNIT_SPELLCAST_START")
    container:RegisterEvent("UNIT_SPELLCAST_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_FAILED")
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE") 
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")     
    container:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    container:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            if self.isTesting then return end
            if UnitCastingInfo("target") then UpdateCastInfo("UNIT_SPELLCAST_START", "target")
            elseif UnitChannelInfo("target") then UpdateCastInfo("UNIT_SPELLCAST_CHANNEL_START", "target")
            else self:SetAlpha(0) end
        else UpdateCastInfo(event, ...) end
    end)

    container:SetScript("OnUpdate", function(self, elapsed)
        if self:GetAlpha() == 0 or self.isInterrupted or not self.durationObj then return end
        
        if not container.isTesting then
            local stillCasting = self.isChanneling and UnitChannelInfo("target") or UnitCastingInfo("target")
            if not stillCasting then self:SetAlpha(0); return end
        end

        local dObj = self.durationObj
        local rem = dObj:GetRemainingDuration()
        self.bar:SetValue(self.isChanneling and rem or dObj:GetElapsedDuration())
        self.timer:SetText(string.format("%.1f", rem))
        
        -- CD durumu OnUpdate içinde de kontrol edilmeli ki yetenek hazır olunca renk değişsin
        UpdateColors()

        if self.isTesting and rem <= 0 then UpdateCastInfo("UNIT_SPELLCAST_START", "target") end
    end)

    table.insert(TargetCastbar.Instances, container)
    container.Unload = function(self)
        for i, inst in ipairs(TargetCastbar.Instances) do if inst == self then table.remove(TargetCastbar.Instances, i); break end end
    end
    return container
end

-- [AYARLAR BÖLÜMÜ DEĞİŞMEDİ, AYNI KALIYOR...]
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
                    if inst.elem == elem then inst.isTesting = true; inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target") end
                end
            end
        end
    end

    sb:AddHeader("Dimensions & Styling")
    sb:AddSlider("widgetWidth", "Bar Width", 50, 600, 5, 200, elem, RefreshLive)
    sb:AddSlider("widgetHeight", "Bar Height", 10, 60, 1, 25, elem, RefreshLive)
    sb:AddCheckbox("showBorder", "Show Border", true, elem, RefreshLive)

    local texItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then for k, _ in pairs(Skin.Media.Textures) do table.insert(texItems, {text=k, value=k}) end end
    sb:AddDropdown("texture", "Bar Texture", texItems, "Smooth", elem, RefreshLive)

    sb:AddHeader("Typography")
    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=k, value=k}) end end
    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 12, elem, RefreshLive)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)

    sb:AddHeader("Bar Colors")
    sb:AddColor("colorReady", "Interrupt Ready", {1, 0.7, 0, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", "Uninterruptible", {0.5, 0.5, 0.5, 1}, elem, RefreshLive)
    sb:AddColor("colorInterrupted", "Interrupt CD / Interrupted", {1, 0, 0, 1}, elem, RefreshLive)

    sb:Finish()

    -- --- TEST MODU BUTONU ---
    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then bottomY = childBottom end
                end
            end
        end
        local btnTest = Skin:CreateButton(f.content, "Toggle Test Mode", 200, 30)
        btnTest:SetPoint("TOPLEFT", 10, bottomY - 20)
        if parentFrame.isTestingGlobal then btnTest:SetBackdropColor(0, 0.8, 0, 1); btnTest.text:SetText("Test Mode: ACTIVE") end
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal = not parentFrame.isTestingGlobal
            if parentFrame.isTestingGlobal then btnTest:SetBackdropColor(0, 0.8, 0, 1); btnTest.text:SetText("Test Mode: ACTIVE")
            else btnTest:SetBackdropColor(unpack(Skin.Colors.button)); btnTest.text:SetText("Toggle Test Mode") end
            for _, inst in ipairs(TargetCastbar.Instances) do
                if inst.elem == elem then inst.isTesting = parentFrame.isTestingGlobal
                    if parentFrame.isTestingGlobal then inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target")
                    else inst:SetAlpha(0) end
                end
            end
        end)
        if parentFrame and not parentFrame.onCloseWidgetSpecific then
             parentFrame.onCloseWidgetSpecific = function() parentFrame.isTestingGlobal = false
                 for _, inst in ipairs(TargetCastbar.Instances) do inst.isTesting = false; inst:SetAlpha(0) end
             end
        end
        if f.content.SetHeight then f.content:SetHeight(math.abs(bottomY - 60)) end
    end
end    container.bar:SetPoint("BOTTOMRIGHT", container.bg, "BOTTOMRIGHT", -2, 2)
    container.bar:SetMinMaxValues(0, 100)
    container.bar:SetValue(0)

    container.spellName = container.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.spellName:SetPoint("LEFT", container.bar, "LEFT", 5, 0)
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then
        fontPath = Skin.Media.Fonts[elem.font] or fontPath
    end
    container.spellName:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.spellName:SetJustifyH("LEFT")
    container.spellName:SetText("No Target")

    container.timer = container.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timer:SetPoint("RIGHT", container.bar, "RIGHT", -5, 0)
    container.timer:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.timer:SetJustifyH("RIGHT")
    container.timer:SetText("0.0s")

    container:SetAlpha(0)

    container.durationObj = nil
    container.isChanneling = false
    container.isInterrupted = false

    local function UpdateColors()
        if container.isInterrupted then
            local intColor = elem.colorInterrupted or {1, 0, 0, 1}
            container.bar:SetStatusBarColor(unpack(intColor))
        elseif container.isShielded then
            local shieldColor = elem.colorShielded or {0.5, 0.5, 0.5, 1}
            container.bar:SetStatusBarColor(unpack(shieldColor))
        else
            local readyColor = elem.colorReady or {1, 0.7, 0, 1}
            container.bar:SetStatusBarColor(unpack(readyColor))
        end
    end

    local function UpdateCastInfo(event, unit)
        if unit ~= "target" and not container.isTesting then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            local name, texture, durationObj
            
            if event == "UNIT_SPELLCAST_START" then
                name, _, texture = UnitCastingInfo("target")
                durationObj = _G.UnitCastingDuration("target")
                container.isChanneling = false
            else
                name, _, texture = UnitChannelInfo("target")
                durationObj = _G.UnitChannelDuration("target")
                container.isChanneling = true
            end

            if container.isTesting then
                name = "Pyroblast (Test Mode)"
                texture = 135808 
                durationObj = CreateDurationObject(GetTime()*1000, (GetTime()+3)*1000)
                container.isChanneling = false
                container.isShielded = false 
            end

            if not name or not durationObj then 
                container:SetAlpha(0)
                return 
            end

            container.durationObj = durationObj
            container.spellName:SetText(name)
            container.icon:SetTexture(texture or 134400)
            container.isInterrupted = false
            container.bar:SetMinMaxValues(0, durationObj:GetTotalDuration())

            if not container.isTesting then container.isShielded = false end
            UpdateColors()
            container:SetAlpha(1)
            
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            container.isShielded = true
            UpdateColors()
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            container.isShielded = false
            UpdateColors()
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            if not container.isInterrupted then container:SetAlpha(0); container.durationObj = nil end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            container.isInterrupted = true
            UpdateColors()
            container.spellName:SetText("Interrupted")
            C_Timer.After(0.75, function() if container.isInterrupted then container:SetAlpha(0); container.isInterrupted = false end end)
        end
    end

    container:RegisterEvent("UNIT_SPELLCAST_START")
    container:RegisterEvent("UNIT_SPELLCAST_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_FAILED")
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE") 
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")     
    container:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    container:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            if self.isTesting then return end
            if UnitCastingInfo("target") then UpdateCastInfo("UNIT_SPELLCAST_START", "target")
            elseif UnitChannelInfo("target") then UpdateCastInfo("UNIT_SPELLCAST_CHANNEL_START", "target")
            else self:SetAlpha(0) end
        else UpdateCastInfo(event, ...) end
    end)

    -- [API 12 FINAL FIX] Karşılaştırma yapmadan OnUpdate yönetimi
    container:SetScript("OnUpdate", function(self, elapsed)
        if self:GetAlpha() == 0 or self.isInterrupted or not self.durationObj then return end
        
        -- HATAYA SEBEP OLAN 'remaining > 0' KONTROLÜ KALDIRILDI!
        -- Onun yerine fonksiyonların varlığını sorguluyoruz (Boşsa büyü bitmiştir)
        if not container.isTesting then
            local stillCasting = self.isChanneling and UnitChannelInfo("target") or UnitCastingInfo("target")
            if not stillCasting then
                self:SetAlpha(0)
                return
            end
        end

        local dObj = self.durationObj
        local rem = dObj:GetRemainingDuration()
        -- Value set ederken secret taint bulaşmaz, sadece compare (>, <, ==) yaparken bulaşır.
        self.bar:SetValue(self.isChanneling and rem or dObj:GetElapsedDuration())
        self.timer:SetText(string.format("%.1f", rem))
        
        -- Test modu sonsuz döngüsü
        if self.isTesting and rem <= 0 then UpdateCastInfo("UNIT_SPELLCAST_START", "target") end
    end)

    table.insert(TargetCastbar.Instances, container)
    container.Unload = function(self)
        for i, inst in ipairs(TargetCastbar.Instances) do if inst == self then table.remove(TargetCastbar.Instances, i); break end end
    end
    return container
end

-- =========================================================================
--  AYARLAR (SETTINGS & BUILDER)
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
                    if inst.elem == elem then inst.isTesting = true; inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target") end
                end
            end
        end
    end

    sb:AddHeader("Dimensions & Styling")
    sb:AddSlider("widgetWidth", "Bar Width", 50, 600, 5, 200, elem, RefreshLive)
    sb:AddSlider("widgetHeight", "Bar Height", 10, 60, 1, 25, elem, RefreshLive)
    sb:AddCheckbox("showBorder", "Show Border", true, elem, RefreshLive)

    local texItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then for k, _ in pairs(Skin.Media.Textures) do table.insert(texItems, {text=k, value=k}) end end
    sb:AddDropdown("texture", "Bar Texture", texItems, "Smooth", elem, RefreshLive)

    sb:AddHeader("Typography")
    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=k, value=k}) end end
    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 12, elem, RefreshLive)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)

    sb:AddHeader("Bar Colors")
    sb:AddColor("colorReady", "Normal Cast", {1, 0.7, 0, 1}, elem, RefreshLive)
    sb:AddColor("colorShielded", "Uninterruptible", {0.5, 0.5, 0.5, 1}, elem, RefreshLive)
    sb:AddColor("colorInterrupted", "Interrupted", {1, 0, 0, 1}, elem, RefreshLive)

    sb:Finish()

    -- --- TEST MODU BUTONU ---
    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then bottomY = childBottom end
                end
            end
        end
        local btnTest = Skin:CreateButton(f.content, "Toggle Test Mode", 200, 30)
        btnTest:SetPoint("TOPLEFT", 10, bottomY - 20)
        if parentFrame.isTestingGlobal then btnTest:SetBackdropColor(0, 0.8, 0, 1); btnTest.text:SetText("Test Mode: ACTIVE") end
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal = not parentFrame.isTestingGlobal
            if parentFrame.isTestingGlobal then btnTest:SetBackdropColor(0, 0.8, 0, 1); btnTest.text:SetText("Test Mode: ACTIVE")
            else btnTest:SetBackdropColor(unpack(Skin.Colors.button)); btnTest.text:SetText("Toggle Test Mode") end
            for _, inst in ipairs(TargetCastbar.Instances) do
                if inst.elem == elem then inst.isTesting = parentFrame.isTestingGlobal
                    if parentFrame.isTestingGlobal then inst:GetScript("OnEvent")(inst, "UNIT_SPELLCAST_START", "target")
                    else inst:SetAlpha(0) end
                end
            end
        end)
        if parentFrame and not parentFrame.onCloseWidgetSpecific then
             parentFrame.onCloseWidgetSpecific = function() parentFrame.isTestingGlobal = false
                 for _, inst in ipairs(TargetCastbar.Instances) do inst.isTesting = false; inst:SetAlpha(0) end
             end
        end
        if f.content.SetHeight then f.content:SetHeight(math.abs(bottomY - 60)) end
    end

end
