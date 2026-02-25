local addonName, addonTable = ...
local WidgetForge = _G.WidgetForge
local Skin = _G.ForgeSkin

local f = CreateFrame("Frame", nil, UIParent)
f:SetSize(64, 64)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
    behavior = "ALWAYS", -- [NEW]
}

-- Visibility Logic
local function UpdateVisibility(config)
    if not config then return end
    
    -- Force show if in preview mode (Settings Open)
    if f.previewMode then
        f:Show()
        return
    end
    
    -- Check global bar visibility first, then fallback to own behavior
    local mode = config.behavior or "ALWAYS"
    if f.parentBar and f.parentBar.index then
         local pbarConf = WidgetForgeDB.bars[f.parentBar.index]
         if pbarConf and pbarConf.visibility then
             mode = pbarConf.visibility
         end
    end
    
    local show = false
    
    if mode == "ALWAYS" then
        show = true
    elseif mode == "COMBAT" then
         -- UnitAffectingCombat is more reliable for visual states than InCombatLockdown
        show = UnitAffectingCombat("player")
    elseif mode == "OUT_OF_COMBAT" then
        show = not UnitAffectingCombat("player")
    elseif mode == "INSTANCE" then
        local inInstance, instanceType = IsInInstance()
        show = (inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "arena"))
    elseif mode == "COMBAT_INSTANCE" then
        local inInstance, instanceType = IsInInstance()
        local isInstance = (inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "arena"))
        show = UnitAffectingCombat("player") or isInstance
    end
    
    if show then f:Show() else f:Hide() end
end

-- Event Handling for Visibility
f:SetScript("OnEvent", function(self, event)
    if self.config then UpdateVisibility(self.config) end
end)

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
    
    if shape == "Square (Border)" or shape == "Square" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\square_emty.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Square (Filled)" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\square_full.tga")
        dot:SetTexCoord(0, 1, 0, 1)

    elseif shape == "Circle (Filled)" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle_full.tga")
        dot:SetTexCoord(0, 1, 0, 1)
        
    elseif shape == "Circle" or shape == "Dot" then
        dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle.tga")
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
    
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self:UpdateVisuals(config)
    -- f:Show() -- Handled by UpdateVisibility
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
    
    -- Visibility
    UpdateVisibility(config)
    
    -- Layer
    local layer = "DIALOG"
    if f.parentBar and f.parentBar.index then
         local pbarConf = WidgetForgeDB.bars[f.parentBar.index]
         if pbarConf and pbarConf.layer then
             layer = pbarConf.layer
         end
    end
    f:SetFrameStrata(layer)
end

function RetirementHome:Unload()
    f:Hide()
    f:UnregisterAllEvents()
    if f.parentBar then
        f.parentBar:SetAlpha(1)
        f.parentBar:EnableMouse(true)
        f.parentBar = nil
    end
end

-- Settings Preview helpers
function RetirementHome:ShowPreview()
    f.previewMode = true
    UpdateVisibility(f.config)
end

function RetirementHome:HidePreview()
    f.previewMode = false
    UpdateVisibility(f.config)
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

    -- Row 1: Shape + Color
    sb:AddDropdown("shape", "Shape", {"Circle", "Circle (Filled)", "Square", "Square (Filled)", "Cross"}, "Circle", f.config, OnShapeChange)
    sb:AddColor("color", "Color", f.config.color, f.config, OnUpdate)
    
    -- Row 2: Behavior (Full Width?) - Let's use AddDropdown but maybe it fits in 1 col?
    -- User said "altında behavior olsun" (let behavior be under it).
    -- If Row 1 has 2 cols (Shape, Color), then "Under it" means Row 2.
    -- Option 1: Behavior + Size on Row 2? 
    -- User: "onun devamında size". Meaning Behavior, then Size.
    -- Let's put Behavior on Row 2 (Left), Size on Row 2 (Right)? Or Behavior Full Width?
    -- "dot shape ve color secimi yanı sırada olsun" -> Row 1: Shape, Color.
    -- "altında behavior olsun" -> Row 2 starts with Behavior.
    -- "onun devamında size" -> Next is Size.
    -- So Row 2: Behavior (Left), Size (Right).
    
    local behaviorOpts = {
        {text="Always Show", value="ALWAYS"},
        {text="Combat Only", value="COMBAT"},
        {text="Instance Only", value="INSTANCE"},
        {text="Combat + Instance", value="COMBAT_INSTANCE"}
    }
    sb:AddDropdown("behavior", "Visibility", behaviorOpts, "ALWAYS", f.config, OnUpdate)
    
    -- Size (Right of Behavior)
    sb:AddSlider("size", "Size (8-128)", 8, 128, 1, 32, f.config, OnUpdate)
    
    -- Row 3: X + Y
    sb:AddSlider("x", "X Offset", -50, 50, 1, 0, f.config, OnUpdate)
    sb:AddSlider("y", "Y Offset", -50, 50, 1, 0, f.config, OnUpdate)
    
    -- Row 4: Thickness (Conditional)
    if f.config.shape == "Cross" then
        sb:AddSlider("thickness", "Line Thickness (Cross)", 1, 20, 1, 4, f.config, OnUpdate, true)
    end
    
    sb:Finish()
end

-- Settings injection removed (Migrated to WidgetForgeConfig.lua)
