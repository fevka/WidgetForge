local addonName, addon = ...
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.Dragonriding = {}
local Dragonriding = _G.WidgetForge.Dragonriding
local L = WFL
addon.Dragonriding = Dragonriding
Dragonriding.frame = nil
function Dragonriding:Load(parent, config)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local Skin = _G.ForgeSkin
    f.data = config
    f.startSwap = config.swapPositions
    if not f.bgBox then
        local bgBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
        bgBox:SetFrameLevel(f:GetFrameLevel()) 
        f.bgBox = bgBox
    end
    f.vigorSegs = {}
    for s = 1, 6 do
        local segFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        segFrame:SetFrameLevel(f:GetFrameLevel() + 2) 
        local segBar = CreateFrame("StatusBar", nil, segFrame)
        segBar:SetAllPoints()
        segBar:SetMinMaxValues(0, 1)
        segBar:SetValue(1)
        segBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        local bg = segFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        segFrame.bg = bg
        segFrame.bar = segBar
        f.vigorSegs[s] = segFrame
    end
    local spFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    spFrame:SetFrameLevel(f:GetFrameLevel() + 2) 
    local spBar = CreateFrame("StatusBar", nil, spFrame)
    spBar:SetAllPoints()
    spBar:SetMinMaxValues(0, 100)
    spBar:SetValue(0)
    spBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local spBg = spFrame:CreateTexture(nil, "BACKGROUND")
    spBg:SetAllPoints()
    spFrame.bg = spBg
    spFrame.bar = spBar
    f.speedFrame = spFrame
    f.speedText = spBar:CreateFontString(nil, "OVERLAY")
    f.speedText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    f.speedText:SetPoint("CENTER", spBar, "CENTER", 0, 0)
    f.speedText:SetTextColor(1, 1, 1, 1)
    Dragonriding:UpdateLayout(f, config)
    return f
end
function Dragonriding:UpdateLayout(f, elem)
    if not f then return end
    local wW = elem.widgetWidth or 300
    local vH = elem.vigorHeight or 14
    local sH = elem.speedHeight or 14
    local vPad = elem.verticalPadding or 4
    local cGap = elem.cellGap or 4
    local vBSize = elem.vigorBorderSize or 1
    local vBColor = elem.vigorBorderColor or {0, 0, 0, 1}
    local sBSize = elem.speedBorderSize or 1
    local sBColor = elem.speedBorderColor or {0, 0, 0, 1}
    local padX = elem.bgPaddingX or 5
    local padY = elem.bgPaddingY or 5
    local bgBoxColor = elem.bgColor or {0, 0, 0, 0}
    local swap = elem.swapPositions
    f.startSwap = swap
    local totalHeight = vH + sH + vPad
    if elem.height then elem.height = totalHeight end 
    if elem.widgetHeight then elem.widgetHeight = totalHeight end
    f:SetSize(wW, totalHeight)
    f:Show()
    local bgBox = f.bgBox
    bgBox:ClearAllPoints()
    bgBox:SetPoint("TOPLEFT", f, "TOPLEFT", -padX, padY)
    bgBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", padX, -padY)
    bgBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = nil, tile = false})
    bgBox:SetBackdropColor(unpack(bgBoxColor))
    bgBox:Show()
    local function GetBackdrop(size)
        local cfg = {
            bgFile = nil, 
            edgeFile = "Interface\\Buttons\\WHITE8x8", 
            edgeSize = size, 
            insets = {left=0, right=0, top=0, bottom=0} 
        }
        if size == 0 then cfg.edgeFile = nil end
        return cfg
    end
    local vigorBd = GetBackdrop(vBSize)
    local speedBd = GetBackdrop(sBSize)
    local segW = (wW - (5 * cGap)) / 6
    if segW < 1 then segW = 1 end
    local vigorY, speedY
    if swap then
         speedY = 0
         vigorY = -(sH + vPad)
    else
         vigorY = 0
         speedY = -(vH + vPad)
    end
    for s = 1, 6 do
        local seg = f.vigorSegs[s]
        seg:ClearAllPoints()
        seg:SetSize(segW, vH)
        local x = (s-1) * (segW + cGap)
        seg:SetPoint("TOPLEFT", f, "TOPLEFT", x, vigorY)
        seg:SetBackdrop(vigorBd)
        seg:SetBackdropBorderColor(unpack(vBColor))
    end
    local sp = f.speedFrame
    sp:ClearAllPoints()
    sp:SetSize(wW, sH)
    sp:SetPoint("TOPLEFT", f, "TOPLEFT", 0, speedY)
    sp:SetBackdrop(speedBd)
    sp:SetBackdropBorderColor(unpack(sBColor))
    local showSpeed = (elem.showSpeedText == nil) and true or elem.showSpeedText
    if showSpeed then f.speedText:Show() else f.speedText:Hide() end
end
function Dragonriding:UpdateVisuals(f, elem)
    if not f then return end
    local vigor = tonumber(tostring(ForgeStats.Data["DragonVigor"])) or 0
    local vigorMax = tonumber(tostring(ForgeStats.Data["DragonVigorMax"])) or 6
    local speed = tonumber(tostring(ForgeStats.Data["DragonSpeed"])) or 0
    local isActive = ForgeStats.Data["DragonActive"] 
    local fillC = elem.vigorFillColor or {0, 0.85, 0.85, 1}
    local emptyC = elem.vigorEmptyColor or {0.15, 0.15, 0.15, 1}
    if vigor > vigorMax then vigor = vigorMax end
    for s = 1, 6 do
        local seg = f.vigorSegs[s]
        if s <= vigorMax then
            seg:Show()
            local fill = 0
            if vigor >= s then
                fill = 1
            elseif vigor > (s-1) then
                fill = vigor - (s-1)
            end
            seg.bar:SetValue(fill)
            seg.bar:SetStatusBarColor(fillC[1], fillC[2], fillC[3], fillC[4])
            local vbSize = elem.vigorBorderSize or 1
            seg.bar:ClearAllPoints()
            seg.bar:SetPoint("TOPLEFT", vbSize, -vbSize)
            seg.bar:SetPoint("BOTTOMRIGHT", -vbSize, vbSize)
            if seg.bg then
                 seg.bg:SetColorTexture(emptyC[1], emptyC[2], emptyC[3], emptyC[4])
            end
        else
            seg:Hide()
        end
    end
    local speedVal = speed * 14.285
    local spBar = f.speedFrame.bar
    local spText = f.speedText
    local spBg = f.speedFrame.bg
    local spC = elem.speedBarColor or {0.7, 0, 0.7, 1}
    spBar:SetStatusBarColor(spC[1], spC[2], spC[3], spC[4])
    local spEmptyC = elem.speedEmptyColor or {0.15, 0.15, 0.15, 1}
    if spBg then
        spBg:SetColorTexture(spEmptyC[1], spEmptyC[2], spEmptyC[3], spEmptyC[4])
    end
    local txtC = elem.speedTextColor or {1, 1, 1, 1}
    spText:SetTextColor(txtC[1], txtC[2], txtC[3], txtC[4])
    spBar:SetMinMaxValues(0, 1250)
    spBar:SetValue(speedVal)
    spText:SetText(string.format("%.0f", speedVal))
    local bSize = elem.speedBorderSize or 1
    spBar:ClearAllPoints()
    spBar:SetPoint("TOPLEFT", bSize, -bSize)
    spBar:SetPoint("BOTTOMRIGHT", -bSize, bSize)
    local behavior = elem.inactiveBehavior or "DIMMED"
    if isActive then
        f:SetAlpha(1)
        f:Show()
    else
        if behavior == "ALWAYS_SHOW" then
             f:SetAlpha(1)
             f:Show()
        elseif behavior == "HIDDEN" then
             f:Hide()
        else
             local alpha = elem.inactiveAlpha or 0.3
             f:SetAlpha(alpha)
             f:Show()
        end
    end
end
function Dragonriding:CreateSettings(parentFrame)
    local f = parentFrame
    f.config.widgetWidth = f.config.widgetWidth or 300
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    local function Refresh()
        local bars = WidgetForge:GetBarFrames()
        local parentBarIndex = nil
        for index, bar in pairs(bars) do
            if bar.customWidgets then
                for _, cw in ipairs(bar.customWidgets) do
                     if cw.bgBox then 
                        if cw.data == f.config then
                            Dragonriding:UpdateLayout(cw, f.config)
                            Dragonriding:UpdateVisuals(cw, f.config)
                            parentBarIndex = index
                        end
                     end
                end
            end
        end
        if parentBarIndex and WidgetForge.UpdateBarValues then
            WidgetForge:UpdateBarValues(parentBarIndex)
        end
    end
    sb:AddHeader(L("HEADER_DIMENSIONS_LAYOUT"))
    sb:AddSlider("widgetWidth", L("LABEL_TOTAL_WIDTH"), 100, 600, 10, 300, f.config, Refresh)
    sb:AddSlider("vigorHeight", L("LABEL_VIGOR_BAR_HEIGHT"), 4, 100, 1, 14, f.config, Refresh)
    sb:AddSlider("speedHeight", L("LABEL_SPEED_BAR_HEIGHT"), 4, 100, 1, 14, f.config, Refresh)
    sb:AddSlider("cellGap", L("LABEL_VIGOR_SPLIT_GAP"), 0, 20, 1, 4, f.config, Refresh)
    sb:AddSlider("verticalPadding", L("LABEL_GAP_BETWEEN_BARS"), 0, 50, 1, 4, f.config, Refresh)
    sb:AddHeader(L("HEADER_LAYOUT_BACKGROUND"))
    sb:AddSwitch("swapPositions", L("LABEL_SWAP_POSITIONS"), false, f.config, Refresh)
    sb:AddSwitch("showSpeedText", L("LABEL_SHOW_SPEED_TEXT"), true, f.config, Refresh)
    sb:AddSlider("bgPaddingX", L("LABEL_BACKGROUND_PADDING_X"), 0, 100, 1, 5, f.config, Refresh)
    sb:AddSlider("bgPaddingY", L("LABEL_BACKGROUND_PADDING_Y"), 0, 50, 1, 5, f.config, Refresh)
    sb:AddColor("bgColor", L("LABEL_BACKGROUND_BOX_COLOR"), {0, 0, 0, 0}, f.config, Refresh)
    sb:AddHeader(L("HEADER_VIGOR_BAR_APPEARANCE"))
    sb:AddSlider("vigorBorderSize", L("LABEL_VIGOR_BORDER_SIZE"), 0, 10, 1, 1, f.config, Refresh)
    sb:AddColor("vigorBorderColor", L("LABEL_VIGOR_BORDER_COLOR"), {0, 0, 0, 1}, f.config, Refresh) 
    sb:AddColor("vigorFillColor", L("LABEL_VIGOR_FILL_COLOR"), {0, 0.85, 0.85, 1}, f.config, Refresh)
    sb:AddColor("vigorEmptyColor", L("LABEL_VIGOR_EMPTY_COLOR"), {0.15, 0.15, 0.15, 1}, f.config, Refresh)
    sb:AddHeader(L("HEADER_SPEED_BAR_APPEARANCE"))
    sb:AddSlider("speedBorderSize", L("LABEL_SPEED_BORDER_SIZE"), 0, 10, 1, 1, f.config, Refresh)
    sb:AddColor("speedBorderColor", L("LABEL_SPEED_BORDER_COLOR"), {0, 0, 0, 1}, f.config, Refresh)
    sb:AddColor("speedBarColor", L("LABEL_SPEED_BAR_COLOR"), {0.7, 0, 0.7, 1}, f.config, Refresh)
    sb:AddColor("speedEmptyColor", L("LABEL_SPEED_EMPTY_COLOR"), {0.15, 0.15, 0.15, 1}, f.config, Refresh)
    sb:AddColor("speedTextColor", L("LABEL_SPEED_TEXT_COLOR"), {1, 1, 1, 1}, f.config, Refresh)
    sb:AddHeader(L("HEADER_ADVANCED_BEHAVIOR"))
    sb:AddDropdown("inactiveBehavior", L("LABEL_WHEN_NOT_DRAGONRIDING"), {
        {text = L("OPTION_DIMMED_DEFAULT"), value = "DIMMED"},
        {text = L("OPTION_ALWAYS_SHOW"), value = "ALWAYS_SHOW"},
        {text = L("OPTION_HIDDEN"), value = "HIDDEN"}
    }, "DIMMED", f.config, function(v)
        f.config.inactiveBehavior = v
        if _G.ForgeConfig then
             C_Timer.After(0.1, function() 
                if f:IsShown() then _G.ForgeConfig:OpenDragonridingSettings(nil, nil, f.config) end
             end)
        end
    end)
    sb:AddSlider("inactiveAlpha", L("LABEL_TRANSPARENCY_DIMMED"), 0, 1, 0.05, 0.2, f.config, Refresh)
    local lastControl = sb.controls[#sb.controls] 
    local currentBehavior = f.config.inactiveBehavior or "DIMMED"
    if currentBehavior ~= "DIMMED" then
        if lastControl then
            lastControl:SetAlpha(0.5)
            if lastControl.track then lastControl.track:EnableMouse(false) end
            if lastControl.thumb then lastControl.thumb:EnableMouse(false) end
            if lastControl.editBox then lastControl.editBox:EnableMouse(false); lastControl.editBox:ClearFocus() end
        end
    else
        if lastControl then
            lastControl:SetAlpha(1)
            if lastControl.track then lastControl.track:EnableMouse(true) end
            if lastControl.thumb then lastControl.thumb:EnableMouse(true) end
            if lastControl.editBox then lastControl.editBox:EnableMouse(true) end
        end
    end
    sb:Finish()
end
