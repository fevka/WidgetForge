-- =========================================================================
--  WidgetForge - Target Castbar Module
--  Advanced Interrupt Tracking & Heuristic Shielded Check
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.TargetCastbar = {}
local TargetCastbar = _G.WidgetForge.TargetCastbar
addonTable.TargetCastbar = TargetCastbar

TargetCastbar.Instances = {}
TargetCastbar.ShieldedUnits = { target = false, focus = false }

-- --- INTERRUPT SPELL DATABASE ---
local INTERRUPT_DATA = {
    WARRIOR = { DEFAULT = 6552 },
    ROGUE   = { DEFAULT = 1766 },
    MAGE    = { DEFAULT = 2139 },
    DEATHKNIGHT = { DEFAULT = 47528 },
    PALADIN = { DEFAULT = 96231 },
    MONK    = { DEFAULT = 116705 },
    DEMONHUNTER = { DEFAULT = 183752 },
    EVOKER  = { DEFAULT = 351338 },
    WARLOCK = { DEFAULT = 119914 },
    SHAMAN  = { DEFAULT = 57994 },
    PRIEST  = { DEFAULT = 0, [3] = 15487 }, -- Sadece Shadow
    HUNTER  = { DEFAULT = 147362, [3] = 187707 }, -- Survival
    DRUID   = { DEFAULT = 106839, [1] = 78675 }, -- Balance Solar Beam fallback
}

local function GetPlayerInterruptID()
    local _, classFilename = UnitClassBase("player")
    local data = INTERRUPT_DATA[classFilename]
    if not data then return 0 end
    
    local specIndex = GetSpecialization() or 0
    return data[specIndex] or data.DEFAULT or 0
end

local function IsInterruptReady()
    local spellID = GetPlayerInterruptID()
    if spellID == 0 then return false end
    
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd and cd.duration and cd.duration > 1.5 then -- Global CD yoksay
            return false
        end
    end
    return true
end

-- --- HEURISTIC SHIELD CHECK (FROM USER R&D) ---
local function GetNamePlateCastBarShielded(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unit, false)
    if not ok or not nameplate or not nameplate.UnitFrame or not nameplate.UnitFrame.castBar then return nil end
    local bar = nameplate.UnitFrame.castBar
    local barType = bar.barType or bar.BarType
    if barType == "uninterruptable" or barType == "UNINTERRUPTABLE" then return true end
    if barType == "interruptable" or barType == "INTERRUPTABLE" or barType == "default" then return false end
    return nil
end

-- --- WIDGET YÜKLEME ---
function TargetCastbar:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    
    local Skin = _G.ForgeSkin
    local barHeight = elem.widgetHeight or 30
    local iconSize = barHeight
    local iconZoom = elem.iconZoom or 0.08
    
    -- Icon Frame
    container.iconBox = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.iconBox:SetPoint("LEFT", 0, 0)
    container.iconBox:SetSize(iconSize, iconSize)
    if Skin then Skin:ApplyBackdrop(container.iconBox, 0, 1) end

    container.icon = container.iconBox:CreateTexture(nil, "ARTWORK")
    container.icon:SetPoint("TOPLEFT", 1, -1)
    container.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    container.icon:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)

    -- Status Bar
    container.statusBar = CreateFrame("StatusBar", nil, container, "BackdropTemplate")
    container.statusBar:SetPoint("LEFT", container.iconBox, "RIGHT", 5, 0)
    container.statusBar:SetPoint("RIGHT", 0, 0)
    container.statusBar:SetHeight(barHeight)
    if Skin then Skin:ApplyBackdrop(container.statusBar, 0.5, 1) end
    
    -- Text Frame
    container.textFrame = CreateFrame("Frame", nil, container.statusBar)
    container.textFrame:SetAllPoints()
    container.textFrame:SetFrameLevel(container.statusBar:GetFrameLevel() + 2)
    
    container.spellText = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.spellText:SetPoint("LEFT", 5, 0)
    container.spellText:SetJustifyH("LEFT")
    
    container.timeText = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timeText:SetPoint("RIGHT", -5, 0)
    container.timeText:SetJustifyH("RIGHT")
    
    -- Dinamik Font ve Boyut Ayarları
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then
        fontPath = Skin.Media.Fonts[elem.font] or fontPath
    end
    local fSize = elem.fontSize or 12
    local fOut = elem.fontOutline or "OUTLINE"

    container.spellText:SetFont(fontPath, fSize, fOut)
    container.timeText:SetFont(fontPath, fSize, fOut)

    container.activeUnit = nil
    container.endTime = 0
    container.duration = 0
    container.isChannel = false
    container.isInterrupted = false

    table.insert(TargetCastbar.Instances, container)
    
    TargetCastbar:RegisterEvents()
    
    container.Unload = function(self)
        for i, inst in ipairs(TargetCastbar.Instances) do
            if inst == self then table.remove(TargetCastbar.Instances, i); break end
        end
    end
    
    -- Ana Döngü
    container:SetScript("OnUpdate", function(self, elapsed)
        TargetCastbar:UpdateFrame(self)
    end)
    
    container:Hide()
    return container
end

function TargetCastbar:UpdateFrame(f)
    local elem = f.elem
    local texPath = elem.texture or "Interface\\TargetingFrame\\UI-StatusBar"
    
    -- Kilit Açıkken (Ayar Modu) Prevew Göster
    if (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown()) then
        f:Show()
        f.statusBar:SetMinMaxValues(0, 1)
        f.statusBar:SetValue(0.6)
        f.statusBar:SetStatusBarTexture(texPath)
        f.statusBar:SetStatusBarColor(unpack(elem.colorReady or {1, 0.5, 0, 1}))
        f.icon:SetTexture(134400) -- Soru işareti
        f.spellText:SetText("Preview Cast")
        f.timeText:SetText("1.5")
        return
    end

    if not f.activeUnit then 
        f:Hide() 
        return 
    end

    -- Büyü kontrolü
    local nameCast, _, texCast, startTimeCast, endTimeCast = UnitCastingInfo(f.activeUnit)
    local nameChan, _, texChan, startTimeChan, endTimeChan = UnitChannelInfo(f.activeUnit)
    
    local name = nameCast or nameChan
    
    if not name then
        if f.isInterrupted then
            -- Kesildi mesajını 1 saniye ekranda tut
            if GetTime() - (f.interruptedTime or 0) > 1.0 then
                f.activeUnit = nil
                f:Hide()
            end
        else
            f.activeUnit = nil
            f:Hide()
        end
        return
    end
    
    f:Show()
    f.isChannel = (nameChan ~= nil)
    local startTime = (f.isChannel and startTimeChan or startTimeCast) / 1000
    local endTime = (f.isChannel and endTimeChan or endTimeCast) / 1000
    f.duration = endTime - startTime
    
    local tex = texCast or texChan
    f.icon:SetTexture(tex or 134400)
    
    local targetName = UnitSpellTargetName(f.activeUnit)
    f.spellText:SetText(targetName and (name .. " -> " .. targetName) or name)

    -- Süre hesaplama
    local currentTime = GetTime()
    local remaining = endTime - currentTime
    local elapsed = currentTime - startTime
    
    if remaining < 0 then remaining = 0 end
    
    f.statusBar:SetMinMaxValues(0, f.duration)
    f.statusBar:SetValue(f.isChannel and remaining or elapsed)
    f.timeText:SetText(string.format("%.1f", remaining))
    
    f.statusBar:SetStatusBarTexture(texPath)

    -- Renk Mantığı (Zırhlı mı? Interrupt hazır mı?)
    local npShielded = GetNamePlateCastBarShielded(f.activeUnit)
    local isShielded = false
    if npShielded ~= nil then
        isShielded = npShielded
    else
        isShielded = TargetCastbar.ShieldedUnits[f.activeUnit]
    end

    if f.isInterrupted then
        f.statusBar:SetStatusBarColor(unpack(elem.colorInterrupted or {0, 1, 0, 1}))
        f.spellText:SetText("INTERRUPTED")
    elseif isShielded then
        f.statusBar:SetStatusBarColor(unpack(elem.colorShielded or {0.5, 0.5, 0.5, 1}))
    elseif IsInterruptReady() then
        f.statusBar:SetStatusBarColor(unpack(elem.colorReady or {1, 0.5, 0, 1}))
    else
        f.statusBar:SetStatusBarColor(unpack(elem.colorCooldown or {1, 0, 0, 1}))
    end
end

-- --- EVENT HANDLING ---
function TargetCastbar:RegisterEvents()
    if TargetCastbar.eventFrame then return end
    
    local eventFrame = CreateFrame("Frame")
    TargetCastbar.eventFrame = eventFrame
    
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    
    local units = {"target", "focus"}
    for _, u in ipairs(units) do
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", u)
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", u)
    end
    
    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            for _, inst in ipairs(TargetCastbar.Instances) do
                if UnitExists("target") then
                    inst.activeUnit = "target"
                elseif UnitExists("focus") then
                    inst.activeUnit = "focus"
                else
                    inst.activeUnit = nil
                end
                inst.isInterrupted = false
            end
            return
        end
        
        if event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then TargetCastbar.ShieldedUnits[unit] = true end
        if event == "UNIT_SPELLCAST_INTERRUPTIBLE" then TargetCastbar.ShieldedUnits[unit] = false end

        for _, inst in ipairs(TargetCastbar.Instances) do
            if inst.activeUnit == unit then
                if event == "UNIT_SPELLCAST_INTERRUPTED" then
                    inst.isInterrupted = true
                    inst.interruptedTime = GetTime()
                elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
                    inst.isInterrupted = false
                end
            end
        end
    end)
end

-- =========================================================================
--  AYARLAR (SETTINGS BUILDER)
--  Tüm ayarlar bu dosya içinden yönetilir.
-- =========================================================================
function TargetCastbar:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    
    local function Refresh()
        if barIndex and _G.WidgetForge then
            -- Slider tetiklendiğinde barı anında yeniden çizer
            _G.WidgetForge:RebuildBarComponents(barIndex)
        end
    end

    sb:AddHeader("Dimensions & Layout")
    sb:AddSlider("widgetHeight", "Castbar Height", 10, 100, 1, 30, elem, Refresh)
    sb:AddSlider("iconZoom", "Icon Zoom (Crop Border)", 0, 0.30, 0.01, 0.08, elem, Refresh)

    sb:AddHeader("Typography & Textures")
    local Skin = _G.ForgeSkin
    local fontItems = {}
    local textureItems = {}
    
    if Skin and Skin.Media then
        if Skin.Media.Fonts then
            for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=k, value=k}) end
        end
        if Skin.Media.Textures then
            for k, v in pairs(Skin.Media.Textures) do table.insert(textureItems, {text=k, value=v}) end
        end
    end
    
    if #fontItems == 0 then fontItems = {{text="Default", value="Fonts\\FRIZQT__.TTF"}} end
    if #textureItems == 0 then textureItems = {{text="Default", value="Interface\\TargetingFrame\\UI-StatusBar"}} end

    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, Refresh)
    sb:AddSlider("fontSize", "Font Size", 8, 32, 1, 12, elem, Refresh)
    sb:AddDropdown("fontOutline", "Font Outline", {
        {text="None", value=""},
        {text="Outline", value="OUTLINE"},
        {text="Thick Outline", value="THICKOUTLINE"},
    }, "OUTLINE", elem, Refresh)
    
    sb:AddDropdown("texture", "Bar Texture", textureItems, "Interface\\TargetingFrame\\UI-StatusBar", elem, Refresh)

    sb:AddHeader("Dynamic Colors (API 12)")
    sb:AddColor("colorReady", "Interrupt Ready Color", {1, 0.5, 0, 1}, elem, Refresh)
    sb:AddColor("colorCooldown", "Interrupt on Cooldown", {1, 0, 0, 1}, elem, Refresh)
    sb:AddColor("colorShielded", "Not Interruptible (Shielded)", {0.5, 0.5, 0.5, 1}, elem, Refresh)
    sb:AddColor("colorInterrupted", "Successfully Interrupted", {0, 1, 0, 1}, elem, Refresh)

    -- Ekrana Çizme Komutu (En önemli kısım)
    sb:Finish()
end