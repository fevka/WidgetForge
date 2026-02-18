local addonName, addonTable = ...
local WidgetForge = _G.WidgetForge
local Skin = _G.ForgeSkin

local f = CreateFrame("Frame", nil, UIParent)
f:SetSize(64, 64)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetFrameStrata("DIALOG")
f:Hide()

-- The main textures (Dot/Shape)
local dot = f:CreateTexture(nil, "OVERLAY")
dot:SetAllPoints(f)
dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle.tga")

local dot2 = f:CreateTexture(nil, "OVERLAY")
dot2:Hide()
dot2:SetTexture("Interface\\Buttons\\WHITE8x8")

local RetirementHome = {}
WidgetForge.RetirementHome = RetirementHome

-- Configuration default
local defaults = {
    color = {1, 0, 0, 1},
    size = 32,
    shape = "Circle",
    thickness = 4, 
}

-- Shape Logic
-- We handle texture selection AND sizing logic here (called by UpdateVisuals)
local function ApplyShape(config)
    local shape = config.shape or "Circle"
    local size = config.size or 32
    local thickness = config.thickness or 4
    
    -- Reset default state
    dot:ClearAllPoints()
    dot:SetAllPoints(f)
    dot2:Hide()
    
    if shape == "Square (Border)" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\square_emty.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Square (Filled)" or shape == "Square" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\square_full.tga")
        dot:SetTexCoord(0, 1, 0, 1)

    elseif shape == "Circle (Filled)" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle_full.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Circle" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Dot" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\dot.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Cross" then
        -- Crosshair (Two White Bars)
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        dot:SetTexCoord(0, 1, 0, 1)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER")
        dot:SetSize(size, thickness) -- Horizontal
        
        dot2:Show()
        dot2:SetPoint("CENTER")
        dot2:SetSize(thickness, size) -- Vertical
        dot2:SetVertexColor(dot:GetVertexColor()) -- Sync Color
    else
        -- Fallback
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle.tga")
    end
end

function RetirementHome:Load(bar, config)
    f.config = config
    f.parentBar = bar
    if bar then
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    end
    self:UpdateVisuals(config)
    f:Show()
    return f
end

function RetirementHome:UpdateVisuals(config)
    if not config then return end
    
    -- Size (Frame size defines bounds, but shape logic might override texture size)
    local s = config.size or 32
    f:SetSize(s, s)
    
    -- Color
    local c = config.color or {1, 0, 0, 1}
    dot:SetVertexColor(unpack(c))
    if dot2:IsShown() then dot2:SetVertexColor(unpack(c)) end
    
    -- Shape
    ApplyShape(config)

    -- Position (Offsets)
    local x = config.x or 0
    local y = config.y or 0
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function RetirementHome:Unload()
    f:Hide()
    if f.parentBar then
        f.parentBar:SetAlpha(1)
        f.parentBar:EnableMouse(true)
        f.parentBar = nil
    end
end

-- Settings Preview helpers
function RetirementHome:ShowPreview()
    -- Always visible
end

function RetirementHome:HidePreview()
    -- No op
end

-- Attach Methods to Frame for Interface Compatibility
f.UpdateVisuals = function(_, cfg) RetirementHome:UpdateVisuals(cfg) end
f.Unload = function() RetirementHome:Unload() end
f.ShowPreview = function() RetirementHome:ShowPreview() end
f.HidePreview = function() RetirementHome:HidePreview() end

-- Settings Menu Construction (re-added for user request)
function RetirementHome:CreateSettings(parentFrame)
    local f = parentFrame
    f.config.x = f.config.x or 0
    f.config.y = f.config.y or 0
    
    -- Ensure Defaults
    f.config.shape = f.config.shape or "Circle"
    f.config.size = f.config.size or 32
    f.config.thickness = f.config.thickness or 4
    if not f.config.color then f.config.color = {1, 1, 1, 1} end
    
    -- Initialize Builder on f.content
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb -- Store for release later
    
    -- We need a wrapper to handle dynamic rebuilds for Cross shape
    local function FullRebuild()
        sb:Release()
        RetirementHome:CreateSettings(f)
    end
    
    local function OnShapeChange(val)
        f.config.shape = val
        RetirementHome:UpdateVisuals(f.config)
        FullRebuild() -- Rebuild to show/hide thickness toggle
    end
    
    local function OnUpdate(val)
        -- specific key update handled by closure in builder
        RetirementHome:UpdateVisuals(f.config)
    end

    -- Row 1: Shape (Full Width)
    sb:AddDropdown("shape", "Dot Shape", {"Dot", "Circle", "Circle (Filled)", "Square (Border)", "Square (Filled)", "Cross"}, "Circle", f.config, OnShapeChange)
    
    -- Row 2: Size (Matches X Offset) + Color (Matches Y Offset)
    sb:AddSlider("size", "Size (8-128)", 8, 128, 1, 32, f.config, OnUpdate)
    sb:AddColor("color", "Color", f.config.color, f.config, OnUpdate)
    
    -- Row 3: X (Left) + Y (Right)
    sb:AddSlider("x", "X Offset (-50 to 50)", -50, 50, 1, 0, f.config, OnUpdate)
    sb:AddSlider("y", "Y Offset (-50 to 50)", -50, 50, 1, 0, f.config, OnUpdate)
    
    -- Row 4: Thickness (Full Width, Conditional)
    if f.config.shape == "Cross" then
        sb:AddSlider("thickness", "Line Thickness (Cross)", 1, 20, 1, 4, f.config, OnUpdate, true)
    end
    
    sb:Finish()
end

-- Inject into Config
if _G.ForgeConfig then
    function _G.ForgeConfig:OpenRetirementHomeSettings(barIndex, elemIndex, elem)
        local f = _G.ForgeRetirementHomeSettings
        if not f then
            f = CreateFrame("Frame", "ForgeRetirementHomeSettings", UIParent, "BackdropTemplate")
            f:SetSize(450, 250) -- Matches standard height
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            f:EnableMouse(true); f:SetMovable(true)
            Skin:ApplyBackdrop(f)
            
            -- Use Skin TitleBar (handles close)
            local title = Skin:CreateTitleBar(f, "Retirement Home", function() f:Hide() end)
            title:RegisterForDrag("LeftButton")
            title:SetScript("OnDragStart", function() f:StartMoving() end)
            title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
            
            -- Content area
            local content = CreateFrame("Frame", nil, f)
            content:SetPoint("TOPLEFT", 0, -40) -- Increased top padding
            content:SetPoint("BOTTOMRIGHT", 0, 0)
            f.content = content
            f.controls = {}
            
            -- Keep ESC Close logic
            f:EnableKeyboard(true)
            f:SetPropagateKeyboardInput(true)
            f:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); self:Hide() else self:SetPropagateKeyboardInput(true) end
            end)
            f:HookScript("OnShow", function(self) self:EnableKeyboard(true) end)
            f:HookScript("OnHide", function(self) self:EnableKeyboard(false) end)
        end
        
        f.config = elem
        f:Show()
        
        -- Clear old controls via Builder
        if f.builder then
             f.builder:Release()
        end
        
        RetirementHome:CreateSettings(f)
    end
end
