WidgetForgeUtils = {}
function WidgetForgeUtils:Serialize(t)
    return ForgeSerializer:Serialize(t)
end
function WidgetForgeUtils:Deserialize(s)
    local result, err = ForgeSerializer:Deserialize(s)
    if not result then
        WIDGETFORGE_DEBUG("Deserialization Error:", err)
        return nil
    end
    return result
end
function WidgetForgeUtils:ValidateColor(color)
    if type(color) ~= "table" then return {1, 1, 1, 1} end
    return {
        math.max(0, math.min(1, color[1] or 1)),
        math.max(0, math.min(1, color[2] or 1)),
        math.max(0, math.min(1, color[3] or 1)),
        math.max(0, math.min(1, color[4] or 1))
    }
end
function WidgetForgeUtils:ValidateBarConfig(bar)
    if not bar then return false end
    bar.name = bar.name or "Unnamed Bar"
    bar.width = math.max(50, math.min(1000, bar.width or 250))
    bar.height = math.max(10, math.min(500, bar.height or 30))
    bar.padding = math.max(-50, math.min(100, bar.padding or 10))
    bar.bgColor = self:ValidateColor(bar.bgColor)
    bar.borderColor = self:ValidateColor(bar.borderColor)
    bar.elements = bar.elements or {}
    for _, elem in ipairs(bar.elements) do
        elem.color = self:ValidateColor(elem.color)
        elem.size = math.max(8, math.min(50, elem.size or 14))
    end
    return true
end
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
function WidgetForgeUtils:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end
function WidgetForgeUtils:TruncateString(str, maxLen)
    if not str then return "" end
    if string.len(str) <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end
function WidgetForgeUtils:GetPlayerID()
    return UnitName("player") .. "-" .. GetRealmName()
end
function WidgetForgeUtils:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex)
    end
    return nil
end
function WidgetForgeUtils:MigrateDatabase(db)
    if not db then return end
    if not db.version then
        db.version = WIDGETFORGE_CONSTANTS.VERSION
    end
    if not db.bars then
        db.bars = {}
    end
    if not db.presets then
        db.presets = {}
    end
    for _, bar in pairs(db.bars) do
        self:ValidateBarConfig(bar)
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
WidgetForgeUtils.SettingsBuilder = {}
local SB = WidgetForgeUtils.SettingsBuilder
SB.__index = SB
local Pool = {
    sliders = {},
    checkboxes = {},
    switches = {},
    dropdowns = {},
    colors = {},
    buttons = {},
    headers = {}
}
function WidgetForgeUtils:CreateSettingsBuilder(canvas)
    local sb = {}
    setmetatable(sb, SB)
    sb.canvas = canvas
    sb.controls = {} 
    sb.y = -10
    local parentWidth = canvas and canvas:GetParent() and canvas:GetParent():GetWidth() or 0
    local leftPad = 20
    local rightPad = 35 
    local totalW = parentWidth and parentWidth > 200 and math.floor(parentWidth - leftPad - rightPad) or 692
    local gap = totalW >= 820 and 24 or 20
    local colW = math.floor((totalW - gap) / 2)
    sb.sidePad = leftPad
    sb.col1 = leftPad
    sb.col2 = leftPad + colW + gap
    sb.colWidth = colW
    sb.fullWidth = (colW * 2) + gap
    sb.isRight = false
    sb.currentRowHeight = 0
    sb.pendingControlMeta = nil
    return sb
end
function SB:Release()
    for _, c in ipairs(self.controls) do
        c:Hide()
        c:SetParent(UIParent) 
        c:ClearAllPoints()
        c.callback = nil
        if c.type == "Slider" then 
            table.insert(Pool.sliders, c)
        elseif c.type == "Checkbox" then 
            table.insert(Pool.checkboxes, c)
        elseif c.type == "Switch" then 
            table.insert(Pool.switches, c)
        elseif c.type == "Dropdown" then 
            table.insert(Pool.dropdowns, c)
        elseif c.type == "Color" then 
            if c.swatchBtn and c.swatchBtn:HasScript("OnClick") then 
                c.swatchBtn:SetScript("OnClick", nil) 
            end
            table.insert(Pool.colors, c)
        elseif c.type == "Button" then 
            if c:HasScript("OnClick") then 
                c:SetScript("OnClick", nil) 
            end
            table.insert(Pool.buttons, c)
        elseif c.type == "Header" then 
            table.insert(Pool.headers, c)
        end
    end
    self.controls = {}
    self.y = -10
    self.isRight = false
    self.currentRowHeight = 0
    self.pendingControlMeta = nil
end
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
function SB:AddHeader(text, hideLine)
    if self.isRight then
        self.y = self.y - math.max(self.currentRowHeight, 50)
        self.isRight = false
        self.currentRowHeight = 0
        self.pendingControlMeta = nil
    end
    local h = GetControl(Pool.headers, function(p)
        return ForgeSkin:CreateSectionHeader(p, "", self.fullWidth)
    end, self.canvas)
    h.type = "Header"
    if h.text then
        h.text:SetText(text)
        h.text:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(13), "")
    end
    h:SetPoint("TOPLEFT", self.col1, self.y)
    h:SetWidth(self.fullWidth)
    if h.line then 
        h.line:SetWidth(self.fullWidth) 
        if hideLine == true then h.line:Hide() else h.line:Show() end
    end
    table.insert(self.controls, h)
    self.y = self.y - 45
end
function SB:FinalizeControlRow(rowHeight, forceFullRow)
    rowHeight = math.max(rowHeight or 50, 50)
    if forceFullRow then
        self.y = self.y - rowHeight
        self.isRight = false
        self.currentRowHeight = 0
        self.pendingControlMeta = nil
        return
    end
    if not self.isRight then
        self.currentRowHeight = rowHeight
        self.isRight = true
    else
        self.currentRowHeight = math.max(self.currentRowHeight, rowHeight)
        self.y = self.y - self.currentRowHeight
        self.currentRowHeight = 0
        self.isRight = false
        self.pendingControlMeta = nil
    end
end
function SB:PlaceControlInRow(control, meta)
    meta = meta or {}
    meta.control = control
    meta.rowHeight = math.max(meta.rowHeight or 50, 50)
    meta.controlTopOffset = math.max(meta.controlTopOffset or 0, 0)
    if not meta.apply then
        meta.apply = function(rowTopY, sharedControlTop)
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", meta.x or self.col1, rowTopY - sharedControlTop)
        end
    end
    if meta.forceFullRow then
        if self.isRight then
            self.y = self.y - math.max(self.currentRowHeight, 50)
            self.isRight = false
            self.currentRowHeight = 0
            self.pendingControlMeta = nil
        end
        meta.apply(self.y, meta.controlTopOffset)
        table.insert(self.controls, control)
        self.y = self.y - meta.rowHeight
        return control
    end
    if not self.isRight then
        meta.apply(self.y, meta.controlTopOffset)
        table.insert(self.controls, control)
        self.currentRowHeight = meta.rowHeight
        self.pendingControlMeta = meta
        self.isRight = true
        return control
    end
    local pending = self.pendingControlMeta
    local sharedControlTop = math.max(
        pending and pending.controlTopOffset or 0,
        meta.controlTopOffset
    )
    if pending and pending.apply then
        pending.apply(self.y, sharedControlTop)
    end
    meta.apply(self.y, sharedControlTop)
    table.insert(self.controls, control)
    local pendingHeight = pending and ((pending.rowHeight or 50) + math.max(0, sharedControlTop - (pending.controlTopOffset or 0))) or 50
    local currentHeight = meta.rowHeight + math.max(0, sharedControlTop - meta.controlTopOffset)
    self.currentRowHeight = math.max(50, self.currentRowHeight or 0, pendingHeight, currentHeight)
    self.y = self.y - self.currentRowHeight
    self.currentRowHeight = 0
    self.isRight = false
    self.pendingControlMeta = nil
    return control
end
function SB:AddSlider(key, label, minVal, maxVal, step, defaultVal, configTable, callback, forceFullRow)
    local width = self.colWidth
    local x = self.isRight and self.col2 or self.col1
    if forceFullRow then
        if self.isRight then
            self.y = self.y - math.max(self.currentRowHeight, 50)
            self.isRight = false
            self.currentRowHeight = 0
        end
        width = self.fullWidth; self.isRight = false; x = self.col1
    end
    local val = configTable[key]
    if val == nil then val = defaultVal end
    local s = GetControl(Pool.sliders, function(p)
        local sl = ForgeSkin:CreateSlider(p, 0, 100, 1, 0, nil, width)
        sl.label = sl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sl.label:SetPoint("BOTTOMLEFT", sl, "TOPLEFT", 0, 8)
        sl.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
        return sl
    end, self.canvas)
    s:SetAlpha(1)
    s:EnableMouse(true)
    if s.track then s.track:EnableMouse(true) end
    if s.thumb then s.thumb:EnableMouse(true) end
    if s.editBox then s.editBox:EnableMouse(true) end
    s.type = "Slider"
    s:SetWidth(width)
    if s.RefreshLayout then
        s:RefreshLayout()
    elseif s.track then
        s.track:SetWidth(width - 55)
    end
    local sliderLabelInset = (s.trackInsetX or 0)
    s.label:SetWidth(math.max(80, width - sliderLabelInset))
    s.label:SetJustifyH("LEFT")
    s.label:SetJustifyV("TOP")
    s.label:SetWordWrap(true)
    s.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
    s.label:SetText(label)
    s.min = minVal; s.max = maxVal; s.step = step
    s.callback = nil
    s:SetValue(val)
    s.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    local labelHeight = math.max(14, math.ceil(s.label:GetStringHeight()))
    local rowHeight = labelHeight + 48
    local controlTopOffset = labelHeight + 10
    self:PlaceControlInRow(s, {
        x = x,
        rowHeight = rowHeight,
        controlTopOffset = controlTopOffset,
        forceFullRow = forceFullRow,
        apply = function(rowTopY, sharedControlTop)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", x, rowTopY - sharedControlTop)
            s.label:ClearAllPoints()
            if s.track then
                s.label:SetPoint("BOTTOMLEFT", s.track, "TOPLEFT", 0, 21)
            else
                s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 8)
            end
        end
    })
end
function SB:AddCheckbox(key, label, defaultVal, configTable, callback)
    local x = self.isRight and self.col2 or self.col1
    local val = configTable[key]
    if val == nil then val = defaultVal end
    local c = GetControl(Pool.checkboxes, function(p)
        return ForgeSkin:CreateCheckbox(p, "", false, nil)
    end, self.canvas)
    c.type = "Checkbox"
    c:SetWidth(self.colWidth)
    if c.SetLabelText then
        c:SetLabelText(label)
    else
        c.label:SetText(label)
    end
    c.callback = nil
    c:SetChecked(val)
    c.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    self:PlaceControlInRow(c, {
        x = x,
        rowHeight = c:GetHeight() + 12,
        controlTopOffset = 0,
        apply = function(rowTopY, sharedControlTop)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, rowTopY - sharedControlTop)
        end
    })
    return c
end
function SB:AddSwitch(key, label, defaultVal, configTable, callback, onTextStr, offTextStr)
    local x = self.isRight and self.col2 or self.col1
    local val = configTable[key]
    if val == nil then val = defaultVal end
    local c = GetControl(Pool.switches, function(p)
        return ForgeSkin:CreateSwitch(p, "", false, nil, "ON", "OFF")
    end, self.canvas)
    c.type = "Switch"
    c:SetWidth(self.colWidth)
    if c.SetLabelText then
        c:SetLabelText(label)
    elseif c.label then
        c.label:SetText(label)
    end
    if c.track and c.track.onText and onTextStr then c.track.onText:SetText(onTextStr) end
    if c.track and c.track.offText and offTextStr then c.track.offText:SetText(offTextStr) end
    c.callback = nil
    c:SetChecked(val, true)
    c.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    self:PlaceControlInRow(c, {
        x = x,
        rowHeight = c:GetHeight() + 12,
        controlTopOffset = 0,
        apply = function(rowTopY, sharedControlTop)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, rowTopY - sharedControlTop)
        end
    })
    return c
end
function SB:AddColor(key, label, defaultVal, configTable, callback)
    local x = self.isRight and self.col2 or self.col1
    local val = configTable[key] or defaultVal
    local c = GetControl(Pool.colors, function(p)
        local row = CreateFrame("Frame", nil, p, "BackdropTemplate")
        row:SetSize(200, 30) 
        row.swatch = row:CreateTexture(nil, "ARTWORK")
        row.swatch:SetSize(25, 25)
        row.swatch:SetPoint("TOPLEFT", 0, 0)
        row.swatch:SetColorTexture(1, 1, 1, 1)
        local swatchBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        swatchBtn:SetAllPoints(row.swatch)
        if ForgeSkin.ApplyBackdrop then ForgeSkin:ApplyBackdrop(swatchBtn, 0, 1) end
        row.swatchBtn = swatchBtn
        swatchBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(ForgeSkin.Colors.accent)) end)
        swatchBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(ForgeSkin.Colors.border)) end)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.swatch, "RIGHT", 10, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
        return row
    end, self.canvas)
    c.type = "Color"
    c:SetWidth(self.colWidth)
    c:SetHeight(30)
    if c.label then
        c.label:SetWidth(self.colWidth - 40)
        c.label:SetJustifyH("LEFT")
        c.label:SetJustifyV("MIDDLE")
        c.label:SetWordWrap(true)
        c.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
    end
    c.label:SetText(label)
    if c.swatch and val then
        c.swatch:SetColorTexture(unpack(val))
    end
    c.swatchBtn:SetScript("OnClick", function()
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
    local labelHeight = math.max(18, math.ceil(c.label:GetStringHeight()))
    local rowHeight = math.max(30, labelHeight)
    if c.swatch then
        c.swatch:ClearAllPoints()
        c.swatch:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    end
    if c.swatchBtn then
        c.swatchBtn:ClearAllPoints()
        c.swatchBtn:SetAllPoints(c.swatch)
    end
    c.label:ClearAllPoints()
    c.label:SetPoint("LEFT", c.swatch, "RIGHT", 10, 0)
    c.label:SetHeight(rowHeight)
    c:SetHeight(rowHeight)
    self:PlaceControlInRow(c, {
        x = x,
        rowHeight = rowHeight + 12,
        controlTopOffset = 0,
        apply = function(rowTopY, sharedControlTop)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, rowTopY - sharedControlTop)
        end
    })
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
    if not d.label then
        d.label = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d.label:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 0, 5)
        d.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
    end
    d.label:SetWidth(self.colWidth)
    d.label:SetJustifyH("LEFT")
    d.label:SetJustifyV("TOP")
    d.label:SetWordWrap(true)
    d.label:SetFont(ForgeSkin.Constants.FONT_NORMAL, ForgeSkin:GetResponsiveFontSize(ForgeSkin.Constants.FONT_SIZE_UI), "")
    d.label:SetText(label)
    d:SetList(items)
    d:SetValue(val)
    d.callback = function(v)
        configTable[key] = v
        if callback then callback(v) end
    end
    local labelHeight = math.max(14, math.ceil(d.label:GetStringHeight()))
    local rowHeight = labelHeight + 42
    local controlTopOffset = labelHeight + 10
    self:PlaceControlInRow(d, {
        x = x,
        rowHeight = rowHeight,
        controlTopOffset = controlTopOffset,
        apply = function(rowTopY, sharedControlTop)
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", x, rowTopY - sharedControlTop)
            d.label:ClearAllPoints()
            d.label:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 0, 8)
        end
    })
end
function SB:Finish()
    if self.isRight then
        self.y = self.y - math.max(self.currentRowHeight, 50)
        self.isRight = false
        self.currentRowHeight = 0
        self.pendingControlMeta = nil
    end
    self.canvas:SetHeight(math.abs(self.y) + 0)
end
