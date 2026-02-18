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
    
    local lastY = -20
    local fullWidth = 400
    local halfWidth = 190
    local startX = 25

    local function AddSlider(key, label, minVal, maxVal, step, defaultVal, width, x, y)
         local val = f.config[key] or defaultVal
         local w = width or fullWidth
         local px = x or startX
         local py = y or lastY
         
         local slider = Skin:CreateSlider(f.content, minVal, maxVal, step, val, function(v)
             f.config[key] = v
             RetirementHome:UpdateVisuals(f.config)
         end, w)
         slider:SetPoint("TOPLEFT", px, py)
         
         local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
         lbl:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
         lbl:SetText(label)
         
         f.controls[key] = slider
         f.controls[key .. "Label"] = lbl -- Store label for visibility sync
         return slider, lbl
    end
    
    local function AddDropdown(key, label, items, width, x, y)
        local w = width or fullWidth
        local px = x or startX
        local py = y or lastY
        
        local dd = Skin:CreateDropdown(f.content, w, items, f.config[key], function(val)
            f.config[key] = val
            RetirementHome:UpdateVisuals(f.config)
            if f.controls["thickness"] then
                local isCross = (val == "Cross")
                f.controls["thickness"]:SetShown(isCross)
                if f.controls["thicknessLabel"] then f.controls["thicknessLabel"]:SetShown(isCross) end
                
                -- Dynamic Resizing
                local mainFrame = _G.ForgeRetirementHomeSettings
                if mainFrame then
                    mainFrame:SetHeight(isCross and 340 or 250)
                end
            end
        end)
        dd:SetPoint("TOPLEFT", px, py)
        
        local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 5)
        lbl:SetText(label)
        
        f.controls[key] = dd
        return dd
    end

    local function AddColor(key, label, width, x, y, horizontalLabel)
        local w = width or fullWidth
        local px = x or startX
        local py = y or lastY
        
        local btn = Skin:CreateButton(f.content, "", w, 25)
        btn:SetPoint("TOPLEFT", px, py)
        
        local col = f.config[key] or {1, 1, 1, 1}
        local swatch = btn:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(w - 4, 19); swatch:SetPoint("CENTER")
        swatch:SetColorTexture(unpack(col))
        
        btn:SetScript("OnClick", function()
             local c = f.config[key] or {1, 1, 1, 1}
             local info = {
                 r = c[1], g = c[2], b = c[3], opacity = c[4],
                 swatchFunc = function(newCol) 
                     f.config[key] = newCol
                     swatch:SetColorTexture(unpack(newCol))
                     RetirementHome:UpdateVisuals(f.config)
                 end,
                 cancelFunc = function()
                     f.config[key] = c
                     swatch:SetColorTexture(unpack(c))
                     RetirementHome:UpdateVisuals(f.config)
                 end
             }
             Skin:ShowColorPicker(info)
        end)
        
        local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if horizontalLabel then
            lbl:SetPoint("LEFT", btn, "RIGHT", 10, 0) -- Label to the RIGHT of button
        else
            lbl:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 5)
        end
        lbl:SetText(label)
        f.controls[key] = btn
        f.controls[key .. "Label"] = lbl
    end
    
    -- Row 1: Shape (Full Width)
    AddDropdown("shape", "Dot Shape", {"Dot", "Circle", "Circle (Filled)", "Square (Border)", "Square (Filled)", "Cross"}, fullWidth, startX, lastY)
    lastY = lastY - 70
    
    -- Row 2: Size (Matches X Offset) + Color (Matches Y Offset)
    AddSlider("size", "Size (8-128)", 8, 128, 1, 32, 190, startX, lastY)
    AddColor("color", "Color", 35, startX + 210, lastY, true) 
    lastY = lastY - 70

    -- Row 3: X (Left) + Y (Right)
    AddSlider("x", "X Offset (-50 to 50)", -50, 50, 1, 0, 190, startX, lastY)
    AddSlider("y", "Y Offset (-50 to 50)", -50, 50, 1, 0, 190, startX + 210, lastY)
    lastY = lastY - 70

    -- Row 4: Thickness (Full Width, Conditional)
    local slThick, lblThick = AddSlider("thickness", "Line Thickness (Cross)", 1, 20, 1, 4, fullWidth, startX, lastY)
    
    -- Init Visibility
    local isCross = (f.config.shape == "Cross")
    slThick:SetShown(isCross)
    lblThick:SetShown(isCross)
    
    -- Set Initial Height
    local mainFrame = _G.ForgeRetirementHomeSettings
    if mainFrame then
        mainFrame:SetHeight(isCross and 340 or 250)
    end
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
        
        -- Clear old controls
        if f.content then
             local kids = { f.content:GetChildren() }
             for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
             f.controls = {}
        end
        
        RetirementHome:CreateSettings(f)
    end
end
