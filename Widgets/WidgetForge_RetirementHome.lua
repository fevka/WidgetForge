local addonName, addonTable = ...
local WidgetForge = _G.WidgetForge
local Skin = _G.ForgeSkin
local L = WFL
local f = CreateFrame("Frame", nil, UIParent)
f:SetSize(64, 64)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:Hide()
local dot = f:CreateTexture(nil, "OVERLAY")
dot:SetAllPoints(f)
dot:SetTexture("Interface\\AddOns\\WidgetForge\\media\\circle.tga")
local dot2 = f:CreateTexture(nil, "OVERLAY")
dot2:Hide()
dot2:SetTexture("Interface\\Buttons\\WHITE8x8")
local RetirementHome = {}
WidgetForge.RetirementHome = RetirementHome
local defaults = {
    color = {1, 0, 0, 1},
    size = 32,
    shape = "Circle",
    thickness = 4, 
    behavior = "ALWAYS", 
}
local function UpdateVisibility(config)
    if not config then return end
    if f.previewMode then
        f:Show()
        return
    end
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
f:SetScript("OnEvent", function(self, event)
    if self.config then UpdateVisibility(self.config) end
end)
local function ApplyShape(config)
    local shape = config.shape or "Circle"
    local size = config.size or 32
    local thickness = config.thickness or 4
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
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        dot:SetTexCoord(0, 1, 0, 1)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER")
        dot:SetSize(size, thickness) 
        dot2:Show()
        dot2:SetPoint("CENTER")
        dot2:SetSize(thickness, size) 
        dot2:SetVertexColor(dot:GetVertexColor()) 
    else
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
    return f
end
function RetirementHome:UpdateVisuals(config)
    if not config then return end
    local s = config.size or 32
    f:SetSize(s, s)
    local c = config.color or {1, 0, 0, 1}
    dot:SetVertexColor(unpack(c))
    if dot2:IsShown() then dot2:SetVertexColor(unpack(c)) end
    ApplyShape(config)
    local x = config.x or 0
    local y = config.y or 0
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    UpdateVisibility(config)
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
function RetirementHome:ShowPreview()
    f.previewMode = true
    UpdateVisibility(f.config)
end
function RetirementHome:HidePreview()
    f.previewMode = false
    UpdateVisibility(f.config)
end
f.UpdateVisuals = function(_, cfg) RetirementHome:UpdateVisuals(cfg) end
f.Unload = function() RetirementHome:Unload() end
f.ShowPreview = function() RetirementHome:ShowPreview() end
f.HidePreview = function() RetirementHome:HidePreview() end
function RetirementHome:CreateSettings(parentFrame)
    local f = parentFrame
    f.config.x = f.config.x or 0
    f.config.y = f.config.y or 0
    f.config.shape = f.config.shape or "Circle"
    f.config.size = f.config.size or 32
    f.config.thickness = f.config.thickness or 4
    if not f.config.color then f.config.color = {1, 1, 1, 1} end
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    local function FullRebuild()
        sb:Release()
        RetirementHome:CreateSettings(f)
    end
    local function OnShapeChange(val)
        f.config.shape = val
        RetirementHome:UpdateVisuals(f.config)
        FullRebuild() 
    end
    local function OnUpdate(val)
        RetirementHome:UpdateVisuals(f.config)
    end
    sb:AddDropdown("shape", L("LABEL_SHAPE"), {L("OPTION_CIRCLE"), L("OPTION_CIRCLE_FILLED"), L("OPTION_SQUARE"), L("OPTION_SQUARE_FILLED"), L("OPTION_CROSS")}, "Circle", f.config, OnShapeChange)
    sb:AddColor("color", L("LABEL_COLOR"), f.config.color, f.config, OnUpdate)
    local behaviorOpts = {
        {text=L("OPTION_ALWAYS_SHOW"), value="ALWAYS"},
        {text=L("OPTION_COMBAT_ONLY"), value="COMBAT"},
        {text=L("OPTION_INSTANCE_ONLY"), value="INSTANCE"},
        {text=L("OPTION_COMBAT_INSTANCE"), value="COMBAT_INSTANCE"}
    }
    sb:AddDropdown("behavior", L("LABEL_VISIBILITY_MODE"), behaviorOpts, "ALWAYS", f.config, OnUpdate)
    sb:AddSlider("size", L("LABEL_SIZE_RANGE"), 8, 128, 1, 32, f.config, OnUpdate)
    sb:AddSlider("x", L("LABEL_X_OFFSET"), -50, 50, 1, 0, f.config, OnUpdate)
    sb:AddSlider("y", L("LABEL_Y_OFFSET"), -50, 50, 1, 0, f.config, OnUpdate)
    if f.config.shape == "Cross" then
        sb:AddSlider("thickness", L("LABEL_LINE_THICKNESS_CROSS"), 1, 20, 1, 4, f.config, OnUpdate, true)
    end
    sb:Finish()
end
