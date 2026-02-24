local addonName, addon = ...

-- Ensure global table exists (just in case)
if not _G.WidgetForge then _G.WidgetForge = {} end

-- Initialize Module in Global Table
_G.WidgetForge.Dragonriding = {}
local Dragonriding = _G.WidgetForge.Dragonriding

-- Also link to addon-private table (for internal consistency)
addon.Dragonriding = Dragonriding

-- Variables
Dragonriding.frame = nil

-- Init
function Dragonriding:Load(parent, config)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local Skin = _G.ForgeSkin
    
    -- Store reference for updates
    f.data = config
    f.startSwap = config.swapPositions
    
    -- Background Box (Behind everything)
    if not f.bgBox then
        local bgBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
        bgBox:SetFrameLevel(f:GetFrameLevel()) -- Same level as container
        f.bgBox = bgBox
    end
    
    -- Vigor Segments (max 6)
    f.vigorSegs = {}
    for s = 1, 6 do
        local segFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        segFrame:SetFrameLevel(f:GetFrameLevel() + 2) -- Above bgBox
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
    
    -- Speed Bar (Frame -> StatusBar)
    local spFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    spFrame:SetFrameLevel(f:GetFrameLevel() + 2) -- Above bgBox
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
    
    -- Speed Text
    f.speedText = spBar:CreateFontString(nil, "OVERLAY")
    f.speedText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    f.speedText:SetPoint("CENTER", spBar, "CENTER", 0, 0)
    f.speedText:SetTextColor(1, 1, 1, 1)

    -- Initial Layout Update
    Dragonriding:UpdateLayout(f, config)
    
    return f
end

function Dragonriding:UpdateLayout(f, elem)
    if not f then return end
    
    -- Defaults
    local wW = elem.widgetWidth or 300
    local vH = elem.vigorHeight or 14
    local sH = elem.speedHeight or 14
    local vPad = elem.verticalPadding or 4
    local cGap = elem.cellGap or 4
    
    -- Separate Border Configs
    local vBSize = elem.vigorBorderSize or 1
    local vBColor = elem.vigorBorderColor or {0, 0, 0, 1}
    local sBSize = elem.speedBorderSize or 1
    local sBColor = elem.speedBorderColor or {0, 0, 0, 1}
    
    -- Background Box Config
    local padX = elem.bgPaddingX or 5
    local padY = elem.bgPaddingY or 5
    local bgBoxColor = elem.bgColor or {0, 0, 0, 0}
    
    local swap = elem.swapPositions
    f.startSwap = swap
    
    local totalHeight = vH + sH + vPad
    if elem.height then elem.height = totalHeight end 
    -- [FIX] Update widgetHeight so parent bar layout knows the new size
    if elem.widgetHeight then elem.widgetHeight = totalHeight end
 
    
    f:SetSize(wW, totalHeight)
    f:Show()
    
    -- Apply Background Box Settings
    local bgBox = f.bgBox
    bgBox:ClearAllPoints()
    bgBox:SetPoint("TOPLEFT", f, "TOPLEFT", -padX, padY)
    bgBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", padX, -padY)
    
    bgBox:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = nil, tile = false})
    bgBox:SetBackdropColor(unpack(bgBoxColor))
    bgBox:Show()
    
    -- Prepare Border Configs
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

    -- Layout Calculation
    local segW = (wW - (5 * cGap)) / 6
    if segW < 1 then segW = 1 end
    
    -- Determine Y offsets
    local vigorY, speedY
    if swap then
         -- Speed Top (0), Vigor Bottom (-sH -vPad)
         speedY = 0
         vigorY = -(sH + vPad)
    else
         -- Vigor Top (0), Speed Bottom (-vH -vPad)
         vigorY = 0
         speedY = -(vH + vPad)
    end
    
    -- Position Vigor Segments
    for s = 1, 6 do
        local seg = f.vigorSegs[s]
        seg:ClearAllPoints()
        seg:SetSize(segW, vH)
        local x = (s-1) * (segW + cGap)
        seg:SetPoint("TOPLEFT", f, "TOPLEFT", x, vigorY)
        
        -- Apply Border/Backdrop to Segment Frame
        seg:SetBackdrop(vigorBd)
        seg:SetBackdropBorderColor(unpack(vBColor))
    end
    
    -- Position Speed Bar
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
    
    -- Double-convert to strip Patch 12 taint from secret values
    local vigor = tonumber(tostring(ForgeStats.Data["DragonVigor"])) or 0
    local vigorMax = tonumber(tostring(ForgeStats.Data["DragonVigorMax"])) or 6
    local speed = tonumber(tostring(ForgeStats.Data["DragonSpeed"])) or 0
    local isActive = ForgeStats.Data["DragonActive"] -- Boolean now
    
    -- Update Vigor Segments (Fractional Fill)
    local fillC = elem.vigorFillColor or {0, 0.85, 0.85, 1}
    local emptyC = elem.vigorEmptyColor or {0.15, 0.15, 0.15, 1}
    
    -- Ensure vigor doesn't exceed max
    if vigor > vigorMax then vigor = vigorMax end
    
    for s = 1, 6 do
        local seg = f.vigorSegs[s]
        if s <= vigorMax then
            seg:Show()
            
            -- Calculate fill for this segment
            local fill = 0
            if vigor >= s then
                fill = 1
            elseif vigor > (s-1) then
                fill = vigor - (s-1)
            end
            
            seg.bar:SetValue(fill)
            seg.bar:SetStatusBarColor(fillC[1], fillC[2], fillC[3], fillC[4])
            
            -- Vigor Inset Logic (Fixed)
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
    
    -- Update Speed Bar
    local speedVal = speed * 14.285
    local spBar = f.speedFrame.bar
    local spText = f.speedText
    local spBg = f.speedFrame.bg
    
    -- Color
    local spC = elem.speedBarColor or {0.7, 0, 0.7, 1}
    spBar:SetStatusBarColor(spC[1], spC[2], spC[3], spC[4])
    
    -- Empty Color (Background)
    local spEmptyC = elem.speedEmptyColor or {0.15, 0.15, 0.15, 1}
    if spBg then
        spBg:SetColorTexture(spEmptyC[1], spEmptyC[2], spEmptyC[3], spEmptyC[4])
    end
    
    -- Text Color
    local txtC = elem.speedTextColor or {1, 1, 1, 1}
    spText:SetTextColor(txtC[1], txtC[2], txtC[3], txtC[4])
    
    spBar:SetMinMaxValues(0, 1250)
    spBar:SetValue(speedVal)
    spText:SetText(string.format("%.0f", speedVal))

    -- Bar Inset
    local bSize = elem.speedBorderSize or 1
    spBar:ClearAllPoints()
    spBar:SetPoint("TOPLEFT", bSize, -bSize)
    spBar:SetPoint("BOTTOMRIGHT", -bSize, bSize)
    
    -- Visibility based on active state
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
             -- DIMMED
             local alpha = elem.inactiveAlpha or 0.3
             f:SetAlpha(alpha)
             f:Show()
        end
    end
end

-- Settings UI
function Dragonriding:CreateSettings(parentFrame)
    local f = parentFrame
    f.config.widgetWidth = f.config.widgetWidth or 300
    
    -- Initialize Builder on f.content
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    
    local function Refresh()
        -- 1. Updates Widget Internals (Visuals & Sizes)
        local bars = WidgetForge:GetBarFrames()
        local parentBarIndex = nil
        
        for index, bar in pairs(bars) do
            if bar.customWidgets then
                for _, cw in ipairs(bar.customWidgets) do
                     if cw.bgBox then -- Dragonriding Identification
                        -- Only update if it matches our config object
                        if cw.data == f.config then
                            Dragonriding:UpdateLayout(cw, f.config)
                            Dragonriding:UpdateVisuals(cw, f.config)
                            parentBarIndex = index
                        end
                     end
                end
            end
        end
        
        -- 2. Trigger Parent Bar Reflow (Crucial for Height Changes)
        if parentBarIndex and WidgetForge.UpdateBarValues then
            WidgetForge:UpdateBarValues(parentBarIndex)
        end
    end

    -- 1. Dimensions & Layout
    sb:AddHeader("Dimensions & Layout")
    sb:AddSlider("widgetWidth", "Total Width", 100, 600, 10, 300, f.config, Refresh)
    sb:AddSlider("vigorHeight", "Vigor Bar Height", 4, 100, 1, 14, f.config, Refresh)
    sb:AddSlider("speedHeight", "Speed Bar Height", 4, 100, 1, 14, f.config, Refresh)
    sb:AddSlider("cellGap", "Vigor Split Gap", 0, 20, 1, 4, f.config, Refresh)
    sb:AddSlider("verticalPadding", "Gap Between Bars", 0, 50, 1, 4, f.config, Refresh)
    
    -- Legacy Gap filler for Col 2
    -- The legacy layout put "Transparency" here.
    -- SettingsBuilder fills: Left, Right, Left...
    -- Row 1: Width, VigorH
    -- Row 2: SpeedH, Gap
    -- Row 3: VertPad, [HERE IS TRANSPARENCY]
    

    -- 2. Layout & Background
    sb:AddHeader("Layout & Background")
    sb:AddCheckbox("swapPositions", "Swap Positions (Top/Bottom)", false, f.config, Refresh)
    sb:AddCheckbox("showSpeedText", "Show Speed Text", true, f.config, Refresh)
    
    -- Row: Swap(L), SpeedText(R)
    -- Next: BG Padding X(L), BG Padding Y(R)
    sb:AddSlider("bgPaddingX", "Background Padding X (Width)", 0, 100, 1, 5, f.config, Refresh)
    sb:AddSlider("bgPaddingY", "Background Padding Y (Height)", 0, 50, 1, 5, f.config, Refresh)
    sb:AddColor("bgColor", "Background Box Color", {0, 0, 0, 0}, f.config, Refresh)
    -- Color (L).
    
    -- 3. Vigor Bar Appearance
    sb:AddHeader("Vigor Bar Appearance")
    sb:AddSlider("vigorBorderSize", "Vigor Border Size", 0, 10, 1, 1, f.config, Refresh)
    sb:AddColor("vigorBorderColor", "Vigor Border Color", {0, 0, 0, 1}, f.config, Refresh) 
    -- BorderSize(L), BorderColor(R)
    
    sb:AddColor("vigorFillColor", "Vigor Fill Color", {0, 0.85, 0.85, 1}, f.config, Refresh)
    sb:AddColor("vigorEmptyColor", "Vigor Empty Color", {0.15, 0.15, 0.15, 1}, f.config, Refresh)
    
    -- 4. Speed Bar Appearance
    sb:AddHeader("Speed Bar Appearance")
    sb:AddSlider("speedBorderSize", "Speed Border Size", 0, 10, 1, 1, f.config, Refresh)
    sb:AddColor("speedBorderColor", "Speed Border Color", {0, 0, 0, 1}, f.config, Refresh)
    
    sb:AddColor("speedBarColor", "Speed Bar Color", {0.7, 0, 0.7, 1}, f.config, Refresh)
    sb:AddColor("speedEmptyColor", "Speed Empty Color", {0.15, 0.15, 0.15, 1}, f.config, Refresh)
    sb:AddColor("speedTextColor", "Speed Text Color", {1, 1, 1, 1}, f.config, Refresh)
    
    -- 5. Behavior Settings
    sb:AddHeader("Advanced Behavior")
    
    -- Visibility Dropdown (Left)
    sb:AddDropdown("inactiveBehavior", "When Not Dragonriding:", {
        {text = "Dimmed (Default)", value = "DIMMED"},
        {text = "Always Show", value = "ALWAYS_SHOW"},
        {text = "Hidden", value = "HIDDEN"}
    }, "DIMMED", f.config, function(v)
        f.config.inactiveBehavior = v
        
        -- Refresh panel to update Transparency slider state
        if _G.ForgeConfig then
             C_Timer.After(0.1, function() 
                if f:IsShown() then _G.ForgeConfig:OpenDragonridingSettings(nil, nil, f.config) end
             end)
        end
    end)
    
    -- Transparency Slider (Right) - Only relevant if DIMMED
    sb:AddSlider("inactiveAlpha", "Transparency (Dimmed)", 0, 1, 0.05, 0.2, f.config, Refresh)
    
    -- Apply "Disabled" visual state if not DIMMED (Default is DIMMED)
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

-- Settings injection moved to WidgetForgeConfig.lua to use unified Slide-In Panel
