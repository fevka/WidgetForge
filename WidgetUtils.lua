-- =========================================================================
--  WidgetForge UTILITIES
--  Shared utility functions for serialization, validation, and helpers
-- =========================================================================

WidgetForgeUtils = {}

-- =========================================================================
--  SERIALIZATION
-- =========================================================================

-- Serialize a table to a string representation
function WidgetForgeUtils:Serialize(t)
    return ForgeSerializer:Serialize(t)
end

-- Deserialize a string to a table
function WidgetForgeUtils:Deserialize(s)
    local result, err = ForgeSerializer:Deserialize(s)
    if not result then
        WIDGETFORGE_DEBUG("Deserialization Error:", err)
        return nil
    end
    return result
end

-- =========================================================================
--  VALIDATION
-- =========================================================================

-- Validate color table
function WidgetForgeUtils:ValidateColor(color)
    if type(color) ~= "table" then return {1, 1, 1, 1} end
    
    return {
        math.max(0, math.min(1, color[1] or 1)),
        math.max(0, math.min(1, color[2] or 1)),
        math.max(0, math.min(1, color[3] or 1)),
        math.max(0, math.min(1, color[4] or 1))
    }
end

-- Validate bar configuration
function WidgetForgeUtils:ValidateBarConfig(bar)
    if not bar then return false end
    
    bar.name = bar.name or "Unnamed Bar"
    bar.width = math.max(50, math.min(1000, bar.width or 250))
    bar.height = math.max(10, math.min(500, bar.height or 30))
    bar.padding = math.max(-50, math.min(100, bar.padding or 10))
    bar.bgColor = self:ValidateColor(bar.bgColor)
    bar.borderColor = self:ValidateColor(bar.borderColor)
    bar.elements = bar.elements or {}
    
    -- Validate elements
    for _, elem in ipairs(bar.elements) do
        elem.color = self:ValidateColor(elem.color)
        elem.size = math.max(8, math.min(50, elem.size or 14))
    end
    
    return true
end

-- =========================================================================
--  HELPERS
-- =========================================================================

-- Deep copy a table
function WidgetForgeUtils:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:DeepCopy(orig_key)] = self:DeepCopy(orig_value)
        end
        setmetatable(copy, self:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    
    return copy
end

-- Format number with K/M suffix
function WidgetForgeUtils:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

-- Safe string truncation
function WidgetForgeUtils:TruncateString(str, maxLen)
    if not str then return "" end
    if string.len(str) <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

-- Get player identifier
function WidgetForgeUtils:GetPlayerID()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Get current spec ID
function WidgetForgeUtils:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex)
    end
    return nil
end

-- =========================================================================
--  DATABASE MIGRATION
-- =========================================================================

function WidgetForgeUtils:MigrateDatabase(db)
    if not db then return end
    
    -- Version check
    if not db.version then
        db.version = WIDGETFORGE_CONSTANTS.VERSION
    end
    
    -- Ensure bars exist
    if not db.bars then
        db.bars = {}
    end
    
    -- Ensure presets exist
    if not db.presets then
        db.presets = {}
    end
    
    -- Sanitize all bars
    for _, bar in pairs(db.bars) do
        self:ValidateBarConfig(bar)
        
        -- Migrate old element types
        if bar.elements then
            for _, elem in pairs(bar.elements) do
                if elem.type == "BagSpace" then elem.type = "Bag Space" end
                if elem.type == "ItemLevel" then elem.type = "Item Level" end
                if elem.type == "CombatTimer" then elem.type = "Combat Timer" end
            end
        end
    end
    
    WIDGETFORGE_DEBUG("Database migrated to version", db.version)
end


-- =========================================================================
--  SETTINGS BUILDER (POOLED UI)
-- =========================================================================

WidgetForgeUtils.SettingsBuilder = {}
local SB = WidgetForgeUtils.SettingsBuilder
SB.__index = SB

-- Global Pools
local Pool = {
    sliders = {},
    checkboxes = {},
    dropdowns = {},
    colors = {},
    buttons = {},
    headers = {}
}

function WidgetForgeUtils:CreateSettingsBuilder(canvas)
    local sb = {}
    setmetatable(sb, SB)
    sb.canvas = canvas
    sb.controls = {} -- List of controls currently in use by this builder
    sb.y = -10
    
    -- Dynamic Grid System
    -- Panel Width ~640, ScrollBar ~25-30. Content Width ~600-610.
    -- We want 2 columns with ~20px gap.
    -- User Requested +3px padding on sides.
    local totalW = 600
    local colW = 290
    local gap = 20
    local sidePad = 3
    
    sb.col1 = 10 + sidePad
    sb.col2 = 10 + sidePad + colW + gap
    sb.colWidth = colW
    sb.fullWidth = (colW * 2) + gap
    
    sb.isRight = false
    return sb
end

function SB:Release()
    for _, c in ipairs(self.controls) do
        c:Hide()
        c:SetParent(UIParent) -- Detach
        c:ClearAllPoints()
        
        if c.type == "Slider" then table.insert(Pool.sliders, c)
        elseif c.type == "Checkbox" then table.insert(Pool.checkboxes, c)
        elseif c.type == "Dropdown" then table.insert(Pool.dropdowns, c)
        elseif c.type == "Color" then table.insert(Pool.colors, c)
        elseif c.type == "Button" then table.insert(Pool.buttons, c)
        elseif c.type == "Header" then table.insert(Pool.headers, c)
        end
    end
    self.controls = {}
    self.y = -10
    self.isRight = false
end

-- internal: get or create
local function GetControl(pool, createFunc, parent)
    local c = table.remove(pool)
    if not c then
        c = createFunc(parent)
    else
        c:SetParent(parent)
    end
    c:Show()
    return c
end

function SB:AddHeader(text)
    if self.isRight then self.y = self.y - 50; self.isRight = false end
    
    local h = GetControl(Pool.headers, function(p)
        return ForgeSkin:CreateSectionHeader(p, "", 480)
    end, self.canvas)
    
    h.type = "Header"
    if h.text then h.text:SetText(text) end
    h:SetPoint("TOPLEFT", 10, self.y)
    
    -- Update Width
    h:SetWidth(self.fullWidth)
    if h.line then h.line:SetWidth(self.fullWidth) end
    
    table.insert(self.controls, h)
    self.y = self.y - 45
end

function SB:AddSlider(key, label, minVal, maxVal, step, defaultVal, configTable, callback, forceFullRow)
    local width = self.colWidth
    local x = self.isRight and self.col2 or self.col1
    
    if forceFullRow then
        width = self.fullWidth; self.isRight = false; x = self.col1
    end
    
    local val = configTable[key]
    if val == nil then val = defaultVal end
    
    local s = GetControl(Pool.sliders, function(p)
        -- Create with dummy values, will update later
        local sl = ForgeSkin:CreateSlider(p, 0, 100, 1, 0, nil, width)
        sl.label = sl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sl.label:SetPoint("BOTTOMLEFT", sl, "TOPLEFT", 0, 5)
        return sl
    end, self.canvas)
    
    -- Reset State (Fix for pool)
    s:SetAlpha(1)
    s:EnableMouse(true)
    if s.track then s.track:EnableMouse(true) end
    if s.thumb then s.thumb:EnableMouse(true) end
    if s.editBox then s.editBox:EnableMouse(true) end
    
    s.type = "Slider"
    s:SetWidth(width)
    -- Update Skin slider internals if needed (resizing track)
    if s.track then s.track:SetWidth(width - 45) end
    
    s.label:SetText(label)
    s.min = minVal; s.max = maxVal; s.step = step
    
    -- Reset callback to avoid triggering during setup
    s.callback = nil
    s:SetValue(val)
    s.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    
    s:SetPoint("TOPLEFT", x, self.y - 15) -- -15 for label space
    table.insert(self.controls, s)
    
    if forceFullRow then
        self.y = self.y - 50
    else
        if self.isRight then self.y = self.y - 50 end
        self.isRight = not self.isRight
    end
end

function SB:AddCheckbox(key, label, defaultVal, configTable, callback)
    local x = self.isRight and self.col2 or self.col1
    
    local val = configTable[key]
    if val == nil then val = defaultVal end
    
    local c = GetControl(Pool.checkboxes, function(p)
        return ForgeSkin:CreateCheckbox(p, "", false, nil)
    end, self.canvas)
    
    c.type = "Checkbox"
    c.label:SetText(label)
    
    c.callback = nil
    c:SetChecked(val)
    c.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    
    c:SetPoint("TOPLEFT", x, self.y - 10)
    table.insert(self.controls, c)
    
    if self.isRight then self.y = self.y - 35 end
    self.isRight = not self.isRight
end

function SB:AddColor(key, label, defaultVal, configTable, callback)
    local x = self.isRight and self.col2 or self.col1
    
    local val = configTable[key] or defaultVal
    
    local c = GetControl(Pool.colors, function(p)
        -- Manual Color Picker Button Construction
        local btn = CreateFrame("Button", nil, p, "BackdropTemplate")
        btn:SetSize(200, 30) -- Placeholder, resized below
        
        -- Swatch (Control)
        btn.swatch = btn:CreateTexture(nil, "ARTWORK")
        btn.swatch:SetSize(25, 25) -- Square style as requested
        btn.swatch:SetPoint("LEFT", 0, 0)
        btn.swatch:SetColorTexture(1, 1, 1, 1)
        
        -- Swatch Border
        btn.swatchBd = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.swatchBd:SetAllPoints(btn.swatch)
        if ForgeSkin.ApplyBackdrop then ForgeSkin:ApplyBackdrop(btn.swatchBd, 0, 1) end
        
        -- Label (Moved Right to match user request)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.label:SetPoint("LEFT", btn.swatch, "RIGHT", 10, 0)
        btn.label:SetJustifyH("LEFT")
        btn.label:SetWordWrap(false)
        
        return btn
    end, self.canvas)
    
    c.type = "Color"
    c:SetWidth(self.colWidth)
    if c.label then c.label:SetWidth(self.colWidth - 40) end
    c.label:SetText(label)
    
    c:SetScript("OnClick", function()
        local current = configTable[key] or defaultVal
        local info = {
            r = current[1], g = current[2], b = current[3], opacity = current[4],
            swatchFunc = function(newCol)
                local r, g, b, a = unpack(newCol)
                configTable[key] = {r, g, b, a}
                if c.swatch then c.swatch:SetColorTexture(r, g, b, a) end
                if callback then callback({r, g, b, a}) end
            end,
            cancelFunc = function()
                configTable[key] = current
                 if c.swatch then c.swatch:SetColorTexture(unpack(current)) end
                if callback then callback(current) end
            end
        }
        ForgeSkin:ShowColorPicker(info)
    end)
    
    -- Init Visuals
    if val then c.swatch:SetColorTexture(unpack(val)) end
    
    -- Position: Match Checkbox alignment (y-10)
    c:SetPoint("TOPLEFT", x, self.y - 10)
    table.insert(self.controls, c)
    
    -- Height: Match Slider's 50px consumption
    if self.isRight then self.y = self.y - 50 end 
    self.isRight = not self.isRight
end

function SB:AddDropdown(key, label, items, defaultVal, configTable, callback)
    local x = self.isRight and self.col2 or self.col1
    
    local val = configTable[key]
    if val == nil then val = defaultVal end
    
    local d = GetControl(Pool.dropdowns, function(p)
        return ForgeSkin:CreateDropdown(p, 150, {}, nil, nil)
    end, self.canvas)
    
    d.type = "Dropdown"
    d:SetWidth(self.colWidth)
    if d.text then d.text:SetWidth(self.colWidth - 25) end
    
    -- Label
    if not d.label then
        d.label = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d.label:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 0, 5)
    end
    d.label:SetText(label)
    
    d:SetList(items)
    d:SetValue(val)
    
    d.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    
    d:SetPoint("TOPLEFT", x, self.y - 15)
    table.insert(self.controls, d)
    
    if self.isRight then self.y = self.y - 50 end
    self.isRight = not self.isRight
end

function SB:Finish()
    if self.isRight then self.y = self.y - 50 end
    self.canvas:SetHeight(math.abs(self.y) + 10)
end
