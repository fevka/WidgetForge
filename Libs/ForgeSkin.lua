ForgeSkin = {}
local Skin = ForgeSkin

Skin.Clipboard = nil 

-------------------------------------------------------------------------
-- 1. DESIGN PARAMETERS (Colors & Fonts)
-------------------------------------------------------------------------
Skin.Colors = {
    bg = {0.05, 0.05, 0.05, 0.95},      
    titleBg = {0.1, 0.1, 0.1, 1},       
    border = {0.2, 0.2, 0.2, 1},        
    accent = {0, 0.8, 1, 1},            
    accentHover = {0.2, 0.9, 1, 1},     
    ready = {0, 1, 0.5, 1},             
    cd = {1, 0.3, 0.3, 1},              
    text = {0.9, 0.9, 0.9, 1},          
    textDim = {0.6, 0.6, 0.6, 1},       
    button = {0.15, 0.15, 0.15, 0.9},
    buttonHover = {0.25, 0.25, 0.25, 0.9},
}

Skin.Constants = {
    FONT_NORMAL = "Fonts\\FRIZQT__.TTF",
    FONT_SIZE_NORMAL = 12,
    FONT_SIZE_SMALL = 10,
    BACKDROP_EDGE_SIZE = 1,
}

-- MEDIA LIBRARY
Skin.Media = {
    Textures = {
        ["1. Flat"] = "Interface\\Buttons\\WHITE8x8",
        ["2. Smooth"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["3. Blizzard"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        ["4. Aluminium"] = "Interface\\RaidFrame\\Shield-Fill",
        ["5. Grayscale"] = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
        ["6. Character"] = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
        ["7. Absorb"] = "Interface\\RaidFrame\\Absorb-Fill",
        ["8. Otter"] = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
    },
    Fonts = {
        ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
        ["Skurri"] = "Fonts\\skurri.ttf",
    },
    Outlines = {
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick", value = "THICKOUTLINE"},
        {text = "Monochrome", value = "MONOCHROME"},
        {text = "Mono+Outline", value = "MONOCHROME,OUTLINE"},
    }
}

-------------------------------------------------------------------------
-- COLOR UTILITIES
-------------------------------------------------------------------------
function Skin:RGBToHSV(r, g, b)
    local min = math.min(r, g, b)
    local max = math.max(r, g, b)
    local delta = max - min
    local h, s, v = 0, 0, max
    if delta ~= 0 then
        s = delta / max
        local dr = (((max - r) / 6) + (delta / 2)) / delta
        local dg = (((max - g) / 6) + (delta / 2)) / delta
        local db = (((max - b) / 6) + (delta / 2)) / delta
        if r == max then h = db - dg
        elseif g == max then h = (1 / 3) + dr - db
        else h = (2 / 3) + dg - dr end
        if h < 0 then h = h + 1 end
        if h > 1 then h = h - 1 end
    end
    return h, s, v
end

function Skin:HSVToRGB(h, s, v)
    if s == 0 then return v, v, v end
    local var_h = h * 6
    if var_h == 6 then var_h = 0 end
    local var_i = math.floor(var_h)
    local var_1 = v * (1 - s)
    local var_2 = v * (1 - s * (var_h - var_i))
    local var_3 = v * (1 - s * (1 - (var_h - var_i)))
    if var_i == 0 then return v, var_3, var_1
    elseif var_i == 1 then return var_2, v, var_1
    elseif var_i == 2 then return var_1, v, var_3
    elseif var_i == 3 then return var_1, var_2, v
    elseif var_i == 4 then return var_3, var_1, v
    else return v, var_1, var_2 end
end

function Skin:ApplyBackdrop(frame, bgAlpha, borderAlpha)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = Skin.Constants.BACKDROP_EDGE_SIZE,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local bg = Skin.Colors.bg
    local border = Skin.Colors.border
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha or bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], borderAlpha or border[4])
end

-------------------------------------------------------------------------
-- WIDGET FACTORY
-------------------------------------------------------------------------
function Skin:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 30)
    self:ApplyBackdrop(btn)
    btn:SetBackdropColor(unpack(Skin.Colors.button))
    btn:SetBackdropBorderColor(unpack(Skin.Colors.border))
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_NORMAL, "OUTLINE")
    btn.text:SetTextColor(unpack(Skin.Colors.text))
    
    btn:SetScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        self:SetBackdropColor(unpack(Skin.Colors.buttonHover))
        self:SetBackdropBorderColor(unpack(Skin.Colors.accent))
    end)
    btn:SetScript("OnLeave", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        self:SetBackdropColor(unpack(Skin.Colors.button))
        self:SetBackdropBorderColor(unpack(Skin.Colors.border))
    end)
    btn:SetScript("OnMouseDown", function(self) if self.IsEnabled and not self:IsEnabled() then return end self.text:SetPoint("CENTER", 1, -1) end)
    btn:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    return btn
end

function Skin:CreateCheckbox(parent, text, checked, callback)
    local cb = CreateFrame("Frame", nil, parent)
    cb:SetSize(200, 20)
    cb.box = CreateFrame("Frame", nil, cb, "BackdropTemplate")
    cb.box:SetSize(18, 18); cb.box:SetPoint("LEFT", 0, 0)
    self:ApplyBackdrop(cb.box); cb.box:SetBackdropColor(0.15, 0.15, 0.15, 1)
    
    cb.check = cb.box:CreateTexture(nil, "OVERLAY")
    cb.check:SetTexture("Interface\\Buttons\\WHITE8x8")
    cb.check:SetPoint("CENTER"); cb.check:SetSize(10, 10)
    cb.check:SetVertexColor(unpack(Skin.Colors.accent))
    cb.check:Hide()
    
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb.box, "RIGHT", 8, 0)
    cb.label:SetText(text)
    cb.label:SetFont(Skin.Constants.FONT_NORMAL, 11, "OUTLINE")
    cb.label:SetTextColor(unpack(Skin.Colors.text))
    
    cb.checked = checked; cb.callback = callback
    function cb:SetChecked(val)
        self.checked = val
        if val then self.check:Show() else self.check:Hide() end
        if self.callback then self.callback(val) end
    end
    -- Only the box itself is clickable
    cb.box:EnableMouse(true)
    cb.box:SetScript("OnMouseDown", function() cb:SetChecked(not cb.checked) end)
    if checked then cb.check:Show() else cb.check:Hide() end
    return cb
end

function Skin:CreateSlider(parent, min, max, step, value, callback, width)
    local slider = CreateFrame("Frame", nil, parent)
    slider:SetSize(width or 220, 30)
    local trackWidth = (width or 220) - 45
    slider.track = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    slider.track:SetPoint("LEFT", 0, 0); slider.track:SetSize(trackWidth, 4)
    slider.track:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", tile=false, edgeSize=1})
    slider.track:SetBackdropColor(0.1, 0.1, 0.1, 1); slider.track:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    slider.fill = slider.track:CreateTexture(nil, "ARTWORK")
    slider.fill:SetTexture("Interface\\Buttons\\WHITE8x8"); slider.fill:SetPoint("LEFT", 1, 0); slider.fill:SetSize(1, 2)
    slider.fill:SetVertexColor(unpack(Skin.Colors.accent))
    
    slider.thumb = CreateFrame("Frame", nil, slider.track, "BackdropTemplate")
    slider.thumb:SetSize(14, 20); self:ApplyBackdrop(slider.thumb)
    slider.thumb:SetBackdropColor(0.6, 0.6, 0.6, 1); slider.thumb:SetBackdropBorderColor(0, 0, 0, 1)
    slider.thumb:EnableMouse(true)
    
    slider.min = min or 0; slider.max = max or 100; slider.step = step or 1; slider.value = value or slider.min; slider.callback = callback
    local edit = CreateFrame("EditBox", nil, slider, "BackdropTemplate")
    edit:SetSize(40, 20); edit:SetPoint("LEFT", slider.track, "RIGHT", 5, 0)
    edit:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE"); edit:SetAutoFocus(false); edit:SetJustifyH("CENTER")
    self:ApplyBackdrop(edit); edit:SetBackdropColor(0, 0, 0, 0.5)
    slider.editBox = edit -- Expose to parent
    
    edit:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then slider:SetValue(val) end
        self:ClearFocus()
    end)
    function slider:SetValue(val)
        val = math.max(self.min, math.min(self.max, val))
        if self.step then val = math.floor((val / self.step) + 0.5) * self.step end
        self.value = val
        local w = self.track:GetWidth()
        local pct = (val - self.min) / (self.max - self.min)
        if pct < 0 then pct = 0 end; if pct > 1 then pct = 1 end
        self.thumb:SetPoint("CENTER", self.track, "LEFT", pct * w, 0)
        self.fill:SetWidth(math.max(1, pct * (w - 2)))
        
        local fmt = self.valueFormat or (self.step and self.step < 0.01 and "%.3f" or (self.step and self.step < 0.1 and "%.2f" or (val < 1 and "%.1f" or "%.0f")))
        local text = string.format(fmt, val)
        
        if not self.editBox:HasFocus() then self.editBox:SetText(text) end
        if self.callback then self.callback(val) end
    end
    local function UpdateFromMouse()
        local px = GetCursorPosition() / UIParent:GetEffectiveScale()
        local trackLeft = slider.track:GetLeft()
        local trackWidth = slider.track:GetWidth()
        if not trackLeft or not trackWidth then return end
        local relative = (px - trackLeft) / trackWidth
        relative = math.max(0, math.min(1, relative))
        slider:SetValue(slider.min + (relative * (slider.max - slider.min)))
    end
    slider.thumb:SetScript("OnMouseDown", function() slider.dragging = true end)
    slider.thumb:SetScript("OnMouseUp", function() slider.dragging = false end)
    slider.track:EnableMouse(true)
    slider.track:SetScript("OnMouseDown", function() slider.dragging = true; UpdateFromMouse() end)
    slider.track:SetScript("OnMouseUp", function() slider.dragging = false end)
    slider.track:SetScript("OnUpdate", function() if slider.dragging then if IsMouseButtonDown("LeftButton") then UpdateFromMouse() else slider.dragging = false end end end)
    
    local cb = slider.callback; slider.callback = nil; slider:SetValue(value); slider.callback = cb
    return slider
end

function Skin:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetSize(width, height)
    scrollFrame:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width - 16, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    local scrollBar = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -4, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -4, 0)
    scrollBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    scrollBar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    
    local thumb = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    thumb:SetWidth(8); thumb:SetHeight(30); thumb:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    thumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"}); thumb:SetBackdropColor(unpack(Skin.Colors.accent))
    thumb:EnableMouse(true); thumb:SetMovable(true)
    
    -- Always keep scrollbar track visible for layout consistency
    -- Only hide the THUMB if not scrollable
    local function UpdateThumb()
        local range = scrollFrame:GetVerticalScrollRange()
        local barHeight = scrollBar:GetHeight()
        thumb:SetFrameLevel(scrollBar:GetFrameLevel() + 5)
        
        scrollBar:Show() -- Always show track
        scrollBar:SetAlpha(1)
        
        if range < 1 then
            scrollFrame:SetVerticalScroll(0)
            thumb:Hide(); thumb:EnableMouse(false)
        else
            thumb:Show(); thumb:SetAlpha(1); thumb:EnableMouse(true); thumb:SetBackdropColor(unpack(Skin.Colors.accent))
            local curr = scrollFrame:GetVerticalScroll()
            if curr > range then
                scrollFrame:SetVerticalScroll(range)
                curr = range
            end
            local viewRatio = height / (height + range)
            local thumbH = math.max(20, barHeight * viewRatio)
            thumbH = math.min(barHeight, thumbH)
            thumb:SetHeight(thumbH)
            local curr = scrollFrame:GetVerticalScroll()
            local pct = curr / range; if pct ~= pct then pct = 0 end
            local travel = barHeight - thumbH
            thumb:SetPoint("TOP", scrollBar, "TOP", 0, -(travel * pct))
        end
    end
    scrollFrame:SetScript("OnScrollRangeChanged", UpdateThumb)
    scrollFrame:SetScript("OnVerticalScroll", UpdateThumb)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll(); local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - (delta * WIDGETFORGE_CONSTANTS.SCROLL_WHEEL_SPEED))))
    end)
    thumb:SetScript("OnMouseDown", function(self)
        self.isDragging = true; self.startY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        self.startScroll = scrollFrame:GetVerticalScroll(); self:SetBackdropColor(1,1,1,1)
    end)
    thumb:SetScript("OnMouseUp", function(self) self.isDragging = false; self:SetBackdropColor(unpack(Skin.Colors.accent)) end)
    thumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
            local delta = self.startY - currY
            local range = scrollFrame:GetVerticalScrollRange(); local travel = scrollBar:GetHeight() - self:GetHeight()
            if travel > 0 then
                local scrollDelta = (delta / travel) * range
                scrollFrame:SetVerticalScroll(math.max(0, math.min(range, self.startScroll + scrollDelta)))
            end
        end
    end)
    C_Timer.After(0.1, UpdateThumb)
    scrollFrame.scrollBar = scrollBar; scrollFrame.scrollThumb = thumb
    return scrollFrame, scrollChild
end

function Skin:CreateDropdown(parent, width, items, selectedValue, callback)
    -- Overload check
    if type(selectedValue) == "function" then
        callback = selectedValue
        selectedValue = nil
    end

    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width, 25)
    self:ApplyBackdrop(dd, 1, 1) -- Opaque background to prevent text bleed from behind
    
    dd.text = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dd.text:SetPoint("LEFT", 10, 0)
    dd.text:SetWidth(width - 25); dd.text:SetJustifyH("LEFT")
    
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(8, 8); arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture("Interface\\Buttons\\WHITE8x8"); arrow:SetVertexColor(unpack(Skin.Colors.accent))

    -- Internal state
    dd.items = items or {}
    dd.callback = callback
    dd.internalWidth = width

    -- [FIX] Override SetWidth to update internal state and avoid closure-based truncation issues
    local origSetWidth = dd.SetWidth
    function dd:SetWidth(w)
        origSetWidth(self, w)
        self.internalWidth = w
        self.text:SetWidth(w - 25)
    end
    
    -- Helper to find text
    local function GetLabel(val)
        if not val then return "Select..." end
        for _, v in ipairs(dd.items) do
             if type(v) == "table" and v.value == val then return v.text end
             if v == val then return v end
        end
        return val
    end
    
    -- Truncation and Text Setter
    local function SetText(fs, text, w)
        fs:SetText(text)
        if fs:GetStringWidth() > w then
            local len = string.len(text)
            for i = len, 1, -1 do
                 local sub = string.sub(text, 1, i) .. ".."
                 fs:SetText(sub)
                 if fs:GetStringWidth() <= w then break end
            end
        end
    end
    SetText(dd.text, GetLabel(selectedValue), dd.internalWidth - 25)

    -- List Container (Singleton-ish per dropdown, but created new for simplicity with pooling)
    local listContainer = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    listContainer:SetFrameStrata("TOOLTIP") 
    listContainer:SetClampedToScreen(true)
    listContainer:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
    listContainer:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, -2)
    self:ApplyBackdrop(listContainer, 0.95, 1)
    listContainer:SetBackdropBorderColor(unpack(Skin.Colors.accent))
    listContainer:Hide()
    
    dd:SetScript("OnHide", function() listContainer:Hide() end)
    
    local listScroll, listChild = Skin:CreateScrollFrame(listContainer, dd.internalWidth - 4, 10) 
    listScroll:SetPoint("TOPLEFT", 2, -2); listScroll:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Button Pool
    local buttonPool = {}
    
    local function RefreshList(newItems)
        if newItems then dd.items = newItems end
        local items = dd.items
        
        -- Hide all existing buttons
        for _, btn in ipairs(buttonPool) do btn:Hide() end
        
        local h = 0
        local finalWidth = dd.internalWidth - 4
        
        -- Check if we need scrollbar logic mostly to adjust width
        local totalHeight = #items * 20
        local maxH = WIDGETFORGE_CONSTANTS and WIDGETFORGE_CONSTANTS.DROPDOWN_MAX_HEIGHT or 300
        if totalHeight > maxH then
             finalWidth = dd.internalWidth - 16 -- Space for scrollbar
             listContainer:SetHeight(maxH + 4)
             listScroll:SetHeight(maxH)
             if listScroll.scrollBar then listScroll.scrollBar:Show() end
        else
             listContainer:SetHeight(totalHeight + 4)
             listScroll:SetHeight(totalHeight)
             if listScroll.scrollBar then listScroll.scrollBar:Hide() end
        end
        listChild:SetWidth(finalWidth)

        -- Create/Update buttons
        for i, item in ipairs(items) do
            local btn = buttonPool[i]
            if not btn then
                btn = CreateFrame("Button", nil, listChild)
                btn:SetHeight(20)
                btn.textObj = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.textObj:SetPoint("LEFT", 5, 0)
                btn.textObj:SetJustifyH("LEFT")
                
                btn:SetScript("OnEnter", function(self) self.textObj:SetTextColor(unpack(Skin.Colors.accent)) end)
                btn:SetScript("OnLeave", function(self) self.textObj:SetTextColor(1, 1, 1) end)
                
                table.insert(buttonPool, btn)
            end
            
            btn:Show()
            btn:SetWidth(finalWidth)
            btn:SetPoint("TOPLEFT", 0, -h)
            
            local label = (type(item)=="table") and item.text or item
            local val = (type(item)=="table") and item.value or item
            
            -- Font check
            if type(item)=="table" and item.font then
                btn.textObj:SetFont(item.font, 12, "OUTLINE")
            else
                btn.textObj:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            end
            
            SetText(btn.textObj, label, finalWidth - 10)
            
            btn:SetScript("OnClick", function()
                dd.text:SetFont(Skin.Constants.FONT_NORMAL, 10, "") 
                SetText(dd.text, label, dd.internalWidth - 25)
                listContainer:Hide()
                if dd.callback then dd.callback(val) end
            end)
            
            h = h + 20
        end
        
        listChild:SetHeight(h)
    end
    
    -- Public method to update list
    function dd:SetList(newItems)
        RefreshList(newItems)
        -- Reset selection text if needed or just keep current? 
        -- Usually better to reset if the current selection is not in new list, 
        -- but for simplicity we keep current text unless user changes it.
    end
    
    -- Public method to select a value programmatically
    function dd:SetValue(val, label)
        if label then
             SetText(dd.text, label, self.internalWidth - 25)
        else
             SetText(dd.text, GetLabel(val), self.internalWidth - 25)
        end
    end
    
    function dd:GetValue()
         -- This is tricky without storing it, but usually we don't need it back from the dropdown UI itself
         return nil 
    end

    -- Initial populate
    RefreshList(items)
    
    -- [NEW] Dropdown Closer Logic
    -- Create a singleton closer frame if not exists
    if not Skin.Closer then
        Skin.Closer = CreateFrame("Button", nil, UIParent)
        Skin.Closer:SetFrameStrata("FULLSCREEN_DIALOG") -- Very high to cover everything
        Skin.Closer:SetAllPoints(UIParent)
        Skin.Closer:Hide()
        Skin.Closer:SetScript("OnClick", function()
            if Skin.ActiveDropdownList then
                Skin.ActiveDropdownList:Hide()
                Skin.ActiveDropdownList = nil
            end
            Skin.Closer:Hide()
        end)
    end
    
    dd:SetScript("OnClick", function()
        if listContainer:IsShown() then 
            listContainer:Hide() 
            Skin.ActiveDropdownList = nil
            Skin.Closer:Hide()
        else 
            -- Close any other active dropdown first
            if Skin.ActiveDropdownList then 
                Skin.ActiveDropdownList:Hide() 
            end
            
            -- Refresh on open to ensure width/layout is correct
            RefreshList() 
            listContainer:Show()
            listScroll:SetVerticalScroll(0) 
            
            -- Register as active and show closer
            Skin.ActiveDropdownList = listContainer
            Skin.Closer:Show()
            
            -- Ensure list is above the closer
            -- [FIX] Force TOOLTIP strata to ensure it is above everything (including FULLSCREEN_DIALOGs like Reset/Delete prompts)
            Skin.Closer:SetFrameStrata("TOOLTIP")
            listContainer:SetFrameStrata("TOOLTIP")
            Skin.Closer:SetFrameLevel(2000) -- High enough
            listContainer:SetFrameLevel(2005) -- Higher than Closer
        end
    end)
    
    -- Hook Hide to ensure cleanup if hidden via other means
    listContainer:HookScript("OnHide", function()
        if Skin.ActiveDropdownList == listContainer then
            Skin.ActiveDropdownList = nil
            Skin.Closer:Hide()
        end
    end)
    
    return dd
end

function Skin:CreateMultiDropdown(parent, width, items, selectedMap, callback)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dd:SetSize(width, 25)
    self:ApplyBackdrop(dd, 1, 1) -- Opaque background
    
    dd.text = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dd.text:SetPoint("LEFT", 10, 0)
    dd.text:SetWidth(width - 25); dd.text:SetJustifyH("LEFT")
    
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(8, 8); arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture("Interface\\Buttons\\WHITE8x8"); arrow:SetVertexColor(unpack(Skin.Colors.accent))

    -- Internal state
    dd.items = items or {}
    dd.selectedMap = selectedMap or {} -- map<value, bool>
    dd.callback = callback
    
    local function UpdateLabel()
        local count = 0
        local total = 0
        local firstText = nil
        
        -- Special "Select All" check
        local allSelected = dd.selectedMap["ALL"]
        if allSelected then
             dd.text:SetText("Show All")
             return
        end
        
        for _, item in ipairs(dd.items) do
             if item.value ~= "ALL" then
                total = total + 1
                  if dd.selectedMap[item.value] then
                      count = count + 1
                      if not firstText then firstText = item.text end
                  end
             end
        end
        
        if count == 0 then dd.text:SetText("None")
        elseif count == total then dd.text:SetText("All Categories")
        elseif count == 1 then dd.text:SetText(firstText)
        else dd.text:SetText(count .. " Selected") end
    end
    UpdateLabel()

    -- List Container
    local listContainer = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    listContainer:SetFrameStrata("TOOLTIP") 
    listContainer:SetClampedToScreen(true)
    listContainer:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
    listContainer:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, -2)
    self:ApplyBackdrop(listContainer, 0.95, 1)
    listContainer:SetBackdropBorderColor(unpack(Skin.Colors.accent))
    listContainer:Hide()
    
    dd:SetScript("OnHide", function() listContainer:Hide() end)
    
    local listScroll, listChild = Skin:CreateScrollFrame(listContainer, width - 4, 10) 
    listScroll:SetPoint("TOPLEFT", 2, -2); listScroll:SetPoint("BOTTOMRIGHT", -2, 2)

    local buttonPool = {}
    
    local function RefreshList()
        local items = dd.items
        for _, btn in ipairs(buttonPool) do btn:Hide() end
        
        local h = 0
        local finalWidth = width - 4
        
        local totalHeight = #items * 20
        local maxH = WIDGETFORGE_CONSTANTS and WIDGETFORGE_CONSTANTS.DROPDOWN_MAX_HEIGHT or 300
        if totalHeight > maxH then
             finalWidth = width - 16
             listContainer:SetHeight(maxH + 4)
             listScroll:SetHeight(maxH)
             if listScroll.scrollBar then listScroll.scrollBar:Show() end
        else
             listContainer:SetHeight(totalHeight + 4)
             listScroll:SetHeight(totalHeight)
             if listScroll.scrollBar then listScroll.scrollBar:Hide() end
        end
        listChild:SetWidth(finalWidth)

        for i, item in ipairs(items) do
            local btn = buttonPool[i]
            if not btn then
                btn = CreateFrame("Button", nil, listChild)
                btn:SetHeight(20)
                
                -- Checkbox visual
                btn.check = btn:CreateTexture(nil, "OVERLAY")
                btn.check:SetSize(10, 10); btn.check:SetPoint("LEFT", 5, 0)
                btn.check:SetTexture("Interface\\Buttons\\WHITE8x8")
                
                btn.textObj = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.textObj:SetPoint("LEFT", 20, 0)
                btn.textObj:SetJustifyH("LEFT")
                
                btn:SetScript("OnEnter", function(self) self.textObj:SetTextColor(unpack(Skin.Colors.accent)) end)
                btn:SetScript("OnLeave", function(self) self.textObj:SetTextColor(1, 1, 1) end)
                
                table.insert(buttonPool, btn)
            end
            
            btn:Show()
            btn:SetWidth(finalWidth)
            btn:SetPoint("TOPLEFT", 0, -h)
            
            local label = item.text
            local val = item.value
            
            btn.textObj:SetText(label)
            
            -- Check state
            local isChecked = dd.selectedMap[val]
            if isChecked then
                 btn.check:SetVertexColor(unpack(Skin.Colors.accent))
                 btn.check:SetAlpha(1)
            else
                 btn.check:SetVertexColor(0.3, 0.3, 0.3)
                 btn.check:SetAlpha(0.5)
            end
            
            btn:SetScript("OnClick", function()
                -- Logic handled by caller via callback usually, but here we update internal map first?
                -- Or callback returns new map?
                -- Let's update map locally then call callback
                local newState = not dd.selectedMap[val]
                dd.selectedMap[val] = newState
                
                if val == "ALL" then
                     -- Handle ALL logic
                     if newState then
                         for _, it in ipairs(items) do dd.selectedMap[it.value] = true end
                     else
                         for _, it in ipairs(items) do dd.selectedMap[it.value] = false end
                     end
                else
                     -- If individual clicked, check if ALL should be unchecked?
                     if not newState then dd.selectedMap["ALL"] = false end
                     -- If all are now checked, check ALL? (Optional)
                end
                
                UpdateLabel()
                RefreshList() -- Update checks visually
                
                if dd.callback then dd.callback(val, newState) end
            end)
            
            h = h + 20
        end
        listChild:SetHeight(h)
    end
    
    -- Dropdown Logic
    if not Skin.Closer then
        -- (Reuse existing closer logic from CreateDropdown if available, else create new)
        -- Since CreateDropdown created it, we assume it exists. 
        -- But to be safe, duplicate check or ensure shared Closer.
        -- CreateDropdown makes Skin.Closer global to Skin.
    end
    
    dd:SetScript("OnClick", function()
        if listContainer:IsShown() then 
            listContainer:Hide() 
            Skin.ActiveDropdownList = nil
            Skin.Closer:Hide()
        else 
            if Skin.ActiveDropdownList then Skin.ActiveDropdownList:Hide() end
            
            RefreshList() 
            listContainer:Show()
            listScroll:SetVerticalScroll(0) 
            
            Skin.ActiveDropdownList = listContainer
            Skin.Closer:Show()
            Skin.Closer:SetFrameStrata("TOOLTIP")
            listContainer:SetFrameStrata("TOOLTIP")
            Skin.Closer:SetFrameLevel(2000)
            listContainer:SetFrameLevel(2005)
        end
    end)
    
    listContainer:HookScript("OnHide", function()
        if Skin.ActiveDropdownList == listContainer then
            Skin.ActiveDropdownList = nil
            Skin.Closer:Hide()
        end
    end)
    
    return dd
end



function Skin:GetColorPickerFrame()
    if Skin.ColorPickerFrame then return Skin.ColorPickerFrame end
    local f = CreateFrame("Frame", "ForgeColorPicker", UIParent, "BackdropTemplate")
    f:SetSize(350, 260); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing); f:Hide()
    self:ApplyBackdrop(f); f:SetBackdropColor(unpack(Skin.Colors.bg))
    Skin:CreateTitleBar(f, "Color Picker", function() if f.cancelFunc then f.cancelFunc() end f:Hide() end)
    
    local pickerHeight = 140; local pickerWidth = 140; local sliderWidth = 21; local gap = 10
    local sv = CreateFrame("Button", nil, f); sv:SetSize(pickerWidth, pickerHeight); sv:SetPoint("TOPLEFT", 10, -40)
    sv.hueBg = sv:CreateTexture(nil, "BACKGROUND", nil, 1); sv.hueBg:SetAllPoints(); sv.hueBg:SetColorTexture(1, 0, 0, 1)
    sv.satBg = sv:CreateTexture(nil, "BACKGROUND", nil, 2); sv.satBg:SetAllPoints(); sv.satBg:SetColorTexture(1, 1, 1, 1)
    if sv.satBg.SetGradient then sv.satBg:SetGradient("HORIZONTAL", CreateColor(1,1,1,1), CreateColor(1,1,1,0)) end
    sv.valBg = sv:CreateTexture(nil, "BACKGROUND", nil, 3); sv.valBg:SetAllPoints(); sv.valBg:SetColorTexture(0, 0, 0, 1)
    if sv.valBg.SetGradient then sv.valBg:SetGradient("VERTICAL", CreateColor(0,0,0,1), CreateColor(0,0,0,0)) end
    sv.thumb = CreateFrame("Frame", nil, sv, "BackdropTemplate"); sv.thumb:SetSize(8, 8); self:ApplyBackdrop(sv.thumb); sv.thumb:SetBackdropColor(1, 1, 1, 1); sv.thumb:SetBackdropBorderColor(0, 0, 0, 1); sv.thumb:SetPoint("CENTER", sv, "BOTTOMLEFT", 0, 0)
    
    local hue = CreateFrame("Button", nil, f); hue:SetSize(sliderWidth, pickerHeight); hue:SetPoint("TOPLEFT", sv, "TOPRIGHT", gap, 0)
    hue.bg = hue:CreateTexture(nil, "BACKGROUND"); hue.bg:SetAllPoints(); hue.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    local function CreateGradientSeg(parent, r1,g1,b1, r2,g2,b2, yStart, h)
        local t = parent:CreateTexture(nil, "ARTWORK"); t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, yStart); t:SetSize(sliderWidth, h); t:SetColorTexture(1,1,1,1)
        if t.SetGradient then t:SetGradient("VERTICAL", CreateColor(r1,g1,b1,1), CreateColor(r2,g2,b2,1)) end
        return t
    end
    local segH = pickerHeight / 6
    CreateGradientSeg(hue, 1,0,1, 1,0,0, segH*5, segH); CreateGradientSeg(hue, 0,0,1, 1,0,1, segH*4, segH)
    CreateGradientSeg(hue, 0,1,1, 0,0,1, segH*3, segH); CreateGradientSeg(hue, 0,1,0, 0,1,1, segH*2, segH)
    CreateGradientSeg(hue, 1,1,0, 0,1,0, segH*1, segH); CreateGradientSeg(hue, 1,0,0, 1,1,0, 0, segH)
    hue.thumb = hue:CreateTexture(nil, "OVERLAY"); hue.thumb:SetSize(sliderWidth + 4, 6); hue.thumb:SetColorTexture(1,1,1,1); hue.thumb:SetPoint("CENTER")
    
    local alpha = CreateFrame("Button", nil, f); alpha:SetSize(sliderWidth, pickerHeight); alpha:SetPoint("TOPLEFT", hue, "TOPRIGHT", gap, 0)
    alpha.checkers = alpha:CreateTexture(nil, "BACKGROUND"); alpha.checkers:SetAllPoints(); alpha.checkers:SetColorTexture(0.5, 0.5, 0.5, 1)
    alpha.bg = alpha:CreateTexture(nil, "ARTWORK"); alpha.bg:SetAllPoints(); alpha.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    alpha.thumb = alpha:CreateTexture(nil, "OVERLAY"); alpha.thumb:SetSize(sliderWidth + 4, 6); alpha.thumb:SetColorTexture(1,1,1,1)
    
    local function CreateInput(label, parent, x, w, boxW, maxChars)
        local container = CreateFrame("Frame", nil, parent); container:SetSize(w, 24); container:SetPoint("TOPLEFT", sv, "BOTTOMLEFT", x, -10)
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); lbl:SetText(label); lbl:SetPoint("LEFT", 0, 0); lbl:SetTextColor(0.6, 0.6, 0.6)
        local eb = CreateFrame("EditBox", nil, container, "BackdropTemplate"); eb:SetSize(boxW, 18); eb:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        eb:SetFontObject("GameFontHighlightSmall"); eb:SetAutoFocus(false); Skin:ApplyBackdrop(eb); eb:SetBackdropColor(0,0,0,0.5); eb:SetJustifyH("CENTER"); eb:SetMaxLetters(maxChars or 3)
        return eb
    end
    local ebR = CreateInput("R", f, 0, 42, 28, 3); local ebG = CreateInput("G", f, 45, 42, 28, 3); local ebB = CreateInput("B", f, 90, 42, 28, 3)
    local ebHex = CreateInput("#", f, 135, 70, 57, 7)
    
    local rightStart = 10 + (140 + 10 + sliderWidth + 10 + sliderWidth) + 20; local totalWidth = 350; local previewX = rightStart; local endX = totalWidth - 10; local previewW = endX - previewX; local previewH = 80
    local preview = f:CreateTexture(nil, "ARTWORK"); preview:SetSize(previewW, previewH); preview:SetPoint("TOPLEFT", f, "TOPLEFT", previewX, -40); preview:SetColorTexture(1,1,1,1)
    local previewLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); previewLabel:SetPoint("CENTER", preview, "CENTER", 0, 0); previewLabel:SetText("NEW"); previewLabel:SetShadowColor(0,0,0,1); previewLabel:SetShadowOffset(1,-1); previewLabel:SetTextColor(1,1,1)
    local previewOld = f:CreateTexture(nil, "ARTWORK"); previewOld:SetSize(previewW, previewH); previewOld:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10); previewOld:SetColorTexture(1,1,1,1)
    local previewOldLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); previewOldLabel:SetPoint("CENTER", previewOld, "CENTER", 0, 0); previewOldLabel:SetText("OLD"); previewOldLabel:SetShadowColor(0,0,0,1); previewOldLabel:SetShadowOffset(1,-1); previewOldLabel:SetTextColor(1,1,1)
    f.previewOld = previewOld
    
    local btnW, btnH = 70, 22; local bY = 10
    local btnCopy = Skin:CreateButton(f, "Copy", btnW, btnH); btnCopy:SetPoint("BOTTOMLEFT", 10, bY)
    local btnPaste = Skin:CreateButton(f, "Paste", btnW, btnH); btnPaste:SetPoint("LEFT", btnCopy, "RIGHT", 5, 0)
    local btnOk = Skin:CreateButton(f, "Okay", btnW, btnH); btnOk:SetPoint("BOTTOMRIGHT", -10, bY)
    local btnCancel = Skin:CreateButton(f, "Cancel", btnW, btnH); btnCancel:SetPoint("RIGHT", btnOk, "LEFT", -5, 0)
    
    f.h, f.s, f.v, f.a = 0, 1, 1, 1; local isUpdating = false
    local function UpdateColor(updateFields, sendCallback)
        if isUpdating then return end
        isUpdating = true
        local r, g, b = Skin:HSVToRGB(f.h, f.s, f.v)
        preview:SetColorTexture(r, g, b, f.a)
        if alpha.bg.SetGradient then alpha.bg:SetGradient("VERTICAL", CreateColor(r,g,b,0), CreateColor(r,g,b,1)) end
        local hr, hg, hb = Skin:HSVToRGB(f.h, 1, 1); sv.hueBg:SetColorTexture(hr, hg, hb, 1)
        local s = math.max(0, math.min(1, f.s)); local v = math.max(0, math.min(1, f.v))
        local h = math.max(0, math.min(1, f.h)); local a = math.max(0, math.min(1, f.a))
        sv.thumb:ClearAllPoints(); sv.thumb:SetPoint("CENTER", sv, "BOTTOMLEFT", s * pickerWidth, v * pickerHeight)
        hue.thumb:ClearAllPoints(); hue.thumb:SetPoint("CENTER", hue, "BOTTOMLEFT", sliderWidth/2, h * pickerHeight)
        alpha.thumb:ClearAllPoints(); alpha.thumb:SetPoint("CENTER", alpha, "BOTTOMLEFT", sliderWidth/2, a * pickerHeight)
        if updateFields then
            ebR:SetText(math.floor(r*255)); ebG:SetText(math.floor(g*255)); ebB:SetText(math.floor(b*255))
            ebHex:SetText(string.format("%02X%02X%02X", r*255, g*255, b*255))
        end
        if f.callback and sendCallback then f.callback({r, g, b, f.a}) end
        isUpdating = false
    end
    sv:SetScript("OnMouseDown", function() sv.down = true end); sv:SetScript("OnMouseUp", function() sv.down = false end)
    sv:SetScript("OnUpdate", function() if sv.down then local mx, my = GetCursorPosition(); local s = sv:GetEffectiveScale(); local x = (mx/s) - sv:GetLeft(); local y = (my/s) - sv:GetBottom(); f.s = math.max(0, math.min(1, x/pickerWidth)); f.v = math.max(0, math.min(1, y/pickerHeight)); UpdateColor(true, true) end end)
    hue:SetScript("OnMouseDown", function() hue.down = true end); hue:SetScript("OnMouseUp", function() hue.down = false end)
    hue:SetScript("OnUpdate", function() if hue.down then local _, my = GetCursorPosition(); local s = hue:GetEffectiveScale(); local y = (my/s) - hue:GetBottom(); f.h = math.max(0, math.min(1, y/pickerHeight)); UpdateColor(true, true) end end)
    alpha:SetScript("OnMouseDown", function() alpha.down = true end); alpha:SetScript("OnMouseUp", function() alpha.down = false end)
    alpha:SetScript("OnUpdate", function() if alpha.down then local _, my = GetCursorPosition(); local s = alpha:GetEffectiveScale(); local y = (my/s) - alpha:GetBottom(); f.a = math.max(0, math.min(1, y/pickerHeight)); UpdateColor(true, true) end end)
    local function OnInputChange()
        local r = tonumber(ebR:GetText()) or 0; local g = tonumber(ebG:GetText()) or 0; local b = tonumber(ebB:GetText()) or 0
        r = math.min(255, math.max(0, r)); g = math.min(255, math.max(0, g)); b = math.min(255, math.max(0, b))
        r, g, b = r/255, g/255, b/255; f.h, f.s, f.v = Skin:RGBToHSV(r, g, b); UpdateColor(true, true); ebR:ClearFocus(); ebG:ClearFocus(); ebB:ClearFocus()
    end
    ebR:SetScript("OnEnterPressed", OnInputChange); ebG:SetScript("OnEnterPressed", OnInputChange); ebB:SetScript("OnEnterPressed", OnInputChange)
    local function OnHexChange()
        local text = ebHex:GetText(); text = text:gsub("#", "")
        if #text == 6 then
            local r = tonumber(string.sub(text, 1, 2), 16); local g = tonumber(string.sub(text, 3, 4), 16); local b = tonumber(string.sub(text, 5, 6), 16)
            if r and g and b then f.h, f.s, f.v = Skin:RGBToHSV(r/255, g/255, b/255); UpdateColor(true, true) end
        end
        ebHex:ClearFocus()
    end
    ebHex:SetScript("OnEnterPressed", OnHexChange)
    btnOk:SetScript("OnClick", function() f:Hide() end)
    btnCancel:SetScript("OnClick", function() if f.cancelFunc then f.cancelFunc() end f:Hide() end)
    btnCopy:SetScript("OnClick", function() local r, g, b = Skin:HSVToRGB(f.h, f.s, f.v); Skin.Clipboard = {r, g, b, f.a}; print("|cff00ccffCopied color.|r") end)
    btnPaste:SetScript("OnClick", function() if not Skin.Clipboard then print("No color in clipboard.") return end local r, g, b, a = unpack(Skin.Clipboard); f.h, f.s, f.v = Skin:RGBToHSV(r, g, b); f.a = a; UpdateColor(true, true) end)
    f.UpdateColor = UpdateColor
    Skin.ColorPickerFrame = f
    return f
end

function Skin:ShowColorPicker(info)
    local f = self:GetColorPickerFrame()
    f.callback = info.swatchFunc; f.cancelFunc = info.cancelFunc
    local r, g, b, a = info.r, info.g, info.b, info.opacity or 1
    f.h, f.s, f.v = self:RGBToHSV(r, g, b); f.a = a
    if f.previewOld then f.previewOld:SetColorTexture(r, g, b, a) end
    f.UpdateColor(true, false); f:Show()
end

function Skin:CreateColorPicker(parent, label, defaultColor, callback, width)
    local cp = CreateFrame("Button", nil, parent); cp:SetSize(width or 460, 30); cp.colorData = defaultColor or {1, 1, 1, 1}
    local swatch = cp:CreateTexture(nil, "ARTWORK"); swatch:SetSize(40, 20); swatch:SetPoint("LEFT", 0, 0); swatch:SetColorTexture(unpack(cp.colorData))
    local border = CreateFrame("Frame", nil, cp, "BackdropTemplate"); border:SetAllPoints(swatch); self:ApplyBackdrop(border, 0, 1)
    local t = cp:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("LEFT", swatch, "RIGHT", 15, 0); t:SetText(label)
    cp:SetScript("OnClick", function()
        local r, g, b, a = unpack(cp.colorData)
        local info = {
            r = r, g = g, b = b, opacity = a,
            swatchFunc = function(c) local nr, ng, nb, na = unpack(c); cp.colorData = {nr, ng, nb, na}; swatch:SetColorTexture(nr, ng, nb, na); if callback then callback({nr, ng, nb, na}) end end,
            cancelFunc = function() cp.colorData = {r, g, b, a}; swatch:SetColorTexture(r, g, b, a); if callback then callback({r, g, b, a}) end end,
        }
        Skin:ShowColorPicker(info)
    end)
    return cp
end

function Skin:CreateSectionHeader(parent, text, width, showLine)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width or 450, 30)
    
    local t = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("BOTTOMLEFT", 0, 8) 
    t:SetText(string.upper(text))
    t:SetTextColor(unpack(Skin.Colors.accent))
    h.text = t
    
    local line = h:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(0.2, 0.2, 0.2, 1)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(1) 
    h.line = line
    
    if showLine == false then h.line:Hide() end
    
    return h
end

function Skin:CreateSeparator(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 610, 1)
    
    local tex = f:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0.2, 0.2, 0.2, 1)
    f.tex = tex
    
    return f
end

function Skin:CreateAccordion(parent, title, contentHeight, onToggle, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetWidth(width or 610) -- Exactly 594px to match lines
    frame:SetHeight(30) -- Initial collapsed height
    frame:SetClipsChildren(true)

    -- Header Button
    local header = CreateFrame("Button", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(30)
    
    -- Background
    Skin:ApplyBackdrop(header, 0.3, 0.5)
    header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    header:SetBackdropBorderColor(0, 0, 0, 1)

    -- Title
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", 10, 0)
    header.text:SetText(title)
    
    -- Arrow Icon
    header.arrow = header:CreateTexture(nil, "OVERLAY")
    header.arrow:SetSize(18, 18)
    header.arrow:SetPoint("RIGHT", -10, 0)
    header.arrow:SetTexture("Interface\\AddOns\\WidgetForge\\media\\plus.tga")
    header.arrow:SetVertexColor(1, 1, 1, 1)
    
    -- Content Frame
    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -5)
    content:SetHeight(contentHeight)
    content:Hide()
    
    frame.content = content
    frame.header = header
    frame.expanded = false
    
    local function UpdateArrow()
        if frame.expanded then
            header.arrow:SetTexture("Interface\\AddOns\\WidgetForge\\media\\minus.tga")
        else
            header.arrow:SetTexture("Interface\\AddOns\\WidgetForge\\media\\plus.tga")
        end
        header.arrow:SetVertexColor(1, 1, 1, 1)
    end

    -- Animation State
    frame.targetHeight = 30
    frame.currentHeight = 30
    frame.animSpeed = 15 -- Speed factor for interpolation
    
    frame:SetScript("OnUpdate", function(self, elapsed)
        if math.abs(self.currentHeight - self.targetHeight) > 0.5 then
            self.currentHeight = self.currentHeight + (self.targetHeight - self.currentHeight) * (self.animSpeed * elapsed)
            self:SetHeight(self.currentHeight)
            if self.onAnimUpdate then self.onAnimUpdate() end -- Optional callback for live layout updates
        elseif self.currentHeight ~= self.targetHeight then
            self.currentHeight = self.targetHeight
            self:SetHeight(self.currentHeight)
            if self.onAnimUpdate then self.onAnimUpdate() end
            if not self.expanded then content:Hide() end -- Fully hide only when animation finishes
        end
    end)

    header:SetScript("OnClick", function()
        frame.expanded = not frame.expanded
        
        if frame.expanded then
             content:Show()
             frame.targetHeight = 30 + 5 + contentHeight
             header:SetBackdropColor(0.2, 0.2, 0.2, 1)
        else
             frame.targetHeight = 30
             header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
             -- Note: content:Hide() happens in OnUpdate when fully closed for visual smoothness
        end
        UpdateArrow()
        
        if onToggle then onToggle(frame.expanded) end
    end)
    
    function frame:SetExpanded(expanded)
        frame.expanded = expanded
        if expanded then
             content:Show()
             frame.targetHeight = 30 + 5 + contentHeight
             frame.currentHeight = frame.targetHeight
             frame:SetHeight(frame.targetHeight)
        else
             content:Hide()
             frame.targetHeight = 30
             frame.currentHeight = frame.targetHeight
             frame:SetHeight(frame.targetHeight)
        end
        UpdateArrow()
    end
    
    function frame:SetContentHeight(height)
        contentHeight = height
        content:SetHeight(height)
        if frame.expanded then
             frame.targetHeight = 30 + 5 + height
             frame.currentHeight = frame.targetHeight
             frame:SetHeight(frame.targetHeight)
        end
    end
    
    return frame
end

function Skin:CreateTitleBar(parent, titleText, onClose)
    local tb = CreateFrame("Frame", nil, parent, "BackdropTemplate"); tb:SetPoint("TOPLEFT", 1, -1); tb:SetPoint("TOPRIGHT", -1, -1); tb:SetHeight(30)
    tb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, edgeSize = 1, insets = { left=0, right=0, top=0, bottom=0 }})
    tb:SetBackdropColor(unpack(Skin.Colors.titleBg)); tb:SetBackdropBorderColor(0, 0, 0, 1)
    local shadow = tb:CreateTexture(nil, "BACKGROUND"); shadow:SetPoint("TOPLEFT", tb, "BOTTOMLEFT", 0, 0); shadow:SetPoint("TOPRIGHT", tb, "BOTTOMRIGHT", 0, 0); shadow:SetHeight(8); shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    if shadow.SetGradient then shadow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0)) else shadow:SetColorTexture(0, 0, 0, 0.3) end
    local line = tb:CreateLine(); line:SetColorTexture(0, 0, 0, 1); line:SetStartPoint("BOTTOMLEFT", 0, 0); line:SetEndPoint("BOTTOMRIGHT", 0, 0); line:SetThickness(1)
    
    local t = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("LEFT", 10, 0)
    t:SetText(string.upper(titleText)) 
    t:SetTextColor(1, 1, 1, 1) 
    
    tb.text = t -- [GÜNCELLEME] Başlığı sonradan değiştirebilmek için referans eklendi
    
    if onClose then
        local cb = CreateFrame("Button", nil, tb, "BackdropTemplate")
        cb:SetSize(18, 18) 
        cb:SetPoint("RIGHT", -5, 0)
        
        cb:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1.5,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        cb:SetBackdropColor(0, 0, 0, 0) 
        cb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) 
        
        local innerBox = CreateFrame("Frame", nil, cb, "BackdropTemplate")
        innerBox:SetSize(8, 8) 
        innerBox:SetPoint("CENTER", 0, 0)
        
        innerBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1.5,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        local monoColor = {0.8, 0.8, 0.8, 1}
        innerBox:SetBackdropColor(0, 0, 0, 0) 
        innerBox:SetBackdropBorderColor(unpack(monoColor))
        innerBox:SetMouseClickEnabled(false)
        
        cb:SetScript("OnEnter", function(self) 
            innerBox:SetBackdropColor(unpack(monoColor)) 
            self:SetBackdropBorderColor(unpack(monoColor)) 
        end)
        
        cb:SetScript("OnLeave", function(self) 
            innerBox:SetBackdropColor(0, 0, 0, 0) 
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) 
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        
        cb:SetScript("OnMouseDown", function(self) 
            self:SetBackdropColor(unpack(monoColor)) 
            innerBox:SetBackdropColor(unpack(Skin.Colors.titleBg)) 
            innerBox:SetPoint("CENTER", 0, 0) 
        end)
        
        cb:SetScript("OnMouseUp", function(self) 
            if MouseIsOver(self) then
                self:SetBackdropColor(0, 0, 0, 0) 
                innerBox:SetBackdropColor(unpack(monoColor))
            else
                self:SetBackdropColor(0, 0, 0, 0)
                innerBox:SetBackdropColor(0, 0, 0, 0)
            end
        end)
        
        cb:SetScript("OnClick", onClose)
    end
    
    parent:SetMovable(true); parent:SetClampedToScreen(true); parent:SetToplevel(true); tb:EnableMouse(true); tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() parent:StartMoving() end); tb:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)
    return tb
end

function Skin:SetSmartBorder(parentFrame, thickness, color, position)
    if not parentFrame then return end
    
    if not thickness or thickness <= 0 then 
        if parentFrame.smartBorder then parentFrame.smartBorder:Hide() end
        return 
    end
    
    if not parentFrame.smartBorder then
        local b = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        b:SetFrameLevel(parentFrame:GetFrameLevel() + 5) 
        parentFrame.smartBorder = b
    end
    
    local b = parentFrame.smartBorder
    b:Show()
    b:SetFrameLevel(parentFrame:GetFrameLevel() + 5)
    b:ClearAllPoints()
    
    position = position or "OUTSIDE"
    local offset = 0
    
    if position == "OUTSIDE" then
        offset = thickness 
    elseif position == "CENTER" then
        offset = thickness / 2
    else 
        offset = 0
    end
    
    b:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -offset, offset)
    b:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", offset, -offset)
    
    b:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = thickness,
        bgFile = nil,
    })
    
    if color then
        b:SetBackdropBorderColor(color.r, color.g, color.b, color.a or 1)
    else
        b:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

-- =========================================================================
--  [YENİ] IMPORT / EXPORT WINDOW (SINGLETON + Z-INDEX FIX + CUSTOM SCROLL)
-- =========================================================================
function Skin:CreateTextWindow(title, defaultText, onAccept)
    if Skin.TextWindow then
        local f = Skin.TextWindow
        f:Show()
        if f.titleBar and f.titleBar.text then
            f.titleBar.text:SetText(string.upper(title))
        end
        
        f.editBox:SetText(defaultText or "")
        if defaultText then 
            f.editBox:HighlightText() 
            f.editBox:SetFocus() 
        else
            f.editBox:SetFocus() 
        end
        
        if onAccept then
            f.btnImport:Show()
            f.btnImport:SetScript("OnClick", function()
                local text = f.editBox:GetText()
                if text and text ~= "" then
                    onAccept(text)
                    f:Hide()
                end
            end)
            f.smartBorder:SetBackdropBorderColor(1, 0.5, 0, 1) 
        else
            f.btnImport:Hide()
            f.smartBorder:SetBackdropBorderColor(0, 0, 0, 1) 
        end
        return f
    end

    local f = CreateFrame("Frame", "ForgeTextWindow", UIParent, "BackdropTemplate")
    f:SetSize(500, 400)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG") 
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    self:ApplyBackdrop(f)
    f:SetBackdropColor(unpack(Skin.Colors.bg))
    
    Skin.TextWindow = f
    f.titleBar = Skin:CreateTitleBar(f, title, function() f:Hide() end)

    local scrollFrame, scrollChild = Skin:CreateScrollFrame(f, 460, 310)
    scrollFrame:SetPoint("TOPLEFT", 20, -40)
    
    local editBox = CreateFrame("EditBox", nil, scrollChild)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(430)
    editBox:SetPoint("TOPLEFT", 0, 0)
    editBox:SetAutoFocus(false)
    
    -- [CRITICAL FIX] "GetStringHeight" yerine gizli FontString kullanma
    local measure = f:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    measure:SetWidth(430) 
    measure:SetWordWrap(true)
    measure:Hide() -- Gizli kalacak
    
    editBox:SetScript("OnTextChanged", function(self)
        measure:SetText(self:GetText()) -- Gizli yazıya kopyala
        local h = measure:GetStringHeight() -- FontString'den yüksekliği al (Hata vermez)
        scrollChild:SetHeight(math.max(310, h + 20))
    end)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    
    f.editBox = editBox 
    
    if defaultText then
        editBox:SetText(defaultText)
        editBox:HighlightText()
        editBox:SetFocus()
    else
        editBox:SetText("")
        editBox:SetFocus() 
    end

    self:SetSmartBorder(f, 1)

    local btnClose = Skin:CreateButton(f, "Close", 100, 25)
    btnClose:SetPoint("BOTTOMRIGHT", -20, 15)
    btnClose:SetScript("OnClick", function() f:Hide() end)
    
    local btnImport = Skin:CreateButton(f, "Import", 100, 25)
    btnImport:SetPoint("RIGHT", btnClose, "LEFT", -10, 0)
    f.btnImport = btnImport 
    
    if onAccept then
        btnImport:SetScript("OnClick", function()
            local text = editBox:GetText()
            if text and text ~= "" then
                onAccept(text)
                f:Hide()
            end
        end)
        f.smartBorder:SetBackdropBorderColor(1, 0.5, 0, 1)
    else
        btnImport:Hide()
        f.smartBorder:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    f:Show()
    return f
end

-- =========================================================================
--  SIMPLE INPUT DIALOG (For preset names, confirmations, etc.)
-- =========================================================================
function Skin:CreateInputDialog(title, placeholder, onAccept, onCancel)
    -- [FIX: MEMORY LEAK] SINGLETON PATTERN
    -- Varsa mevcut olanı kullan
    if Skin.InputDialog then
        local f = Skin.InputDialog
        f:Show()
        -- Başlığı ve input'u sıfırla
        f.titleHeader.text:SetText(string.upper(title))
        f.inputBox:SetText(placeholder or "")
        f.inputBox:HighlightText()
        f.inputBox:SetFocus()
        
        -- Callbackleri güncelle
        f.onAccept = onAccept
        f.onCancel = onCancel
        return f
    end

    local f = CreateFrame("Frame", "ForgeInputDialog", UIParent, "BackdropTemplate")
    f:SetSize(350, 140)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    self:ApplyBackdrop(f)
    f:SetBackdropColor(unpack(Skin.Colors.bg))
    self:SetSmartBorder(f, 2, {r=0, g=0.8, b=1, a=1}, "OUTSIDE")
    
    -- Başlığı değişkene ata ki sonra değiştirebilelim
    f.titleHeader = Skin:CreateTitleBar(f, title, function() 
        if f.onCancel then f.onCancel() end
        f:Hide() 
    end)
    
    local inputFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    inputFrame:SetSize(310, 30)
    inputFrame:SetPoint("TOP", 0, -50)
    self:ApplyBackdrop(inputFrame)
    inputFrame:SetBackdropColor(0, 0, 0, 0.5)
    
    local input = CreateFrame("EditBox", nil, inputFrame)
    input:SetAllPoints()
    input:SetFont(Skin.Constants.FONT_NORMAL, 12, "OUTLINE")
    input:SetTextInsets(8, 8, 0, 0)
    input:SetAutoFocus(true)
    input:SetText(placeholder or "")
    input:HighlightText()
    f.inputBox = input -- Referans sakla
    
    local btnOk = Skin:CreateButton(f, "OK", 100, 25)
    btnOk:SetPoint("BOTTOMRIGHT", -20, 15)
    
    local btnCancel = Skin:CreateButton(f, "Cancel", 100, 25)
    btnCancel:SetPoint("RIGHT", btnOk, "LEFT", -10, 0)
    
    -- Buton Logic'i dinamik callback kullanacak şekilde
    btnOk:SetScript("OnClick", function()
        local text = input:GetText()
        if text and text ~= "" then
            if f.onAccept then f.onAccept(text) end
            f:Hide()
        end
    end)
    
    btnCancel:SetScript("OnClick", function()
        if f.onCancel then f.onCancel() end
        f:Hide()
    end)
    
    input:SetScript("OnEnterPressed", function() btnOk:Click() end)
    input:SetScript("OnEscapePressed", function() btnCancel:Click() end)
    
    -- Callbackleri ata
    f.onAccept = onAccept
    f.onCancel = onCancel

    Skin.InputDialog = f -- Frame'i cache'le
    f:Show()
    return f
end

-- =========================================================================
--  CONFIRMATION DIALOG
-- =========================================================================
function Skin:CreateConfirmDialog(title, message, onConfirm, onCancel)
    local f = CreateFrame("Frame", "ForgeConfirmDialog", UIParent, "BackdropTemplate")
    f:SetSize(400, 160)
    f:SetPoint("CENTER")
    f:SetFrameStrata("TOOLTIP") -- Higher than FULLSCREEN_DIALOG to appear above delete dialog
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    self:ApplyBackdrop(f)
    f:SetBackdropColor(unpack(Skin.Colors.bg))
    self:SetSmartBorder(f, 2, {r=1, g=0.3, b=0.3, a=1}, "OUTSIDE")
    
    Skin:CreateTitleBar(f, title, function() 
        if onCancel then onCancel() end
        f:Hide() 
    end)
    
    -- Message text
    local msgText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("TOP", 0, -55)
    msgText:SetWidth(360)
    msgText:SetText(message)
    msgText:SetFont(Skin.Constants.FONT_NORMAL, 13, "OUTLINE")
    msgText:SetTextColor(1, 1, 1, 1)
    msgText:SetJustifyH("CENTER")
    msgText:SetWordWrap(true)
    
    -- Buttons
    local btnConfirm = Skin:CreateButton(f, "Confirm", 120, 28)
    btnConfirm:SetPoint("BOTTOMRIGHT", -20, 15)
    btnConfirm:SetBackdropColor(0.8, 0.2, 0.2, 0.9)
    
    local btnCancel = Skin:CreateButton(f, "Cancel", 120, 28)
    btnCancel:SetPoint("RIGHT", btnConfirm, "LEFT", -10, 0)
    
    btnConfirm:SetScript("OnClick", function()
        if onConfirm then onConfirm() end
        f:Hide()
    end)
    
    btnCancel:SetScript("OnClick", function()
        if onCancel then onCancel() end
        f:Hide()
    end)
    
    f:Show()
    return f
end

-- =========================================================================
--  GRIP HANDLE (Standardized Drag Button)
-- =========================================================================
function Skin:CreateGripHandle(parent, width, height)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(width or 32, height or 32)
    
    d.lines = {}
    
    local function CreateLine(yOffset)
        local line = d:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 1) -- Proper pixel-perfect solid color
        
        -- CALCULATION: Enforce even width for perfect center alignment
        local w = math.ceil((width or 32) * 0.6)
        if w % 2 ~= 0 then w = w + 1 end
        
        line:SetSize(w, 2) -- 2px Height constant
        line:SetPoint("CENTER", d, "CENTER", 0, yOffset) -- Even offsets ensure pixel grid alignment
        line:SetVertexColor(unpack(Skin.Colors.accent)) -- Theme Blue
        table.insert(d.lines, line)
        return line
    end
    
    -- Exact pixel offsets (Even numbers for better alignment)
    CreateLine(4)
    CreateLine(0)
    CreateLine(-4)
    
    -- Standard Hover Effects
    d:SetScript("OnEnter", function(self)
        for _, l in ipairs(self.lines) do l:SetVertexColor(1, 1, 1, 1) end -- White
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end
    end)
    
    d:SetScript("OnLeave", function(self)
        for _, l in ipairs(self.lines) do l:SetVertexColor(unpack(Skin.Colors.accent)) end -- Blue
        GameTooltip:Hide()
    end)
    
    return d
end

-- =========================================================================
--  SLIDE-IN PANEL (Reusable Component)
-- =========================================================================
function Skin:CreateSlidePanel(parent, width, height, anchorInfo)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    
    -- Configurable sizes
    local w = width or 640
    local h = height or 550
    local targetW = w + 2 -- 2px wider (based on user request)
    local targetX = anchorInfo and anchorInfo.x or -9 
    local targetY = anchorInfo and anchorInfo.y or -40
    
    panel:SetSize(1, h) -- Start hidden/collapsed
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", targetX, targetY)
    
    -- Ensure on TOP of everything
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    
    -- Standard Backdrop
    Skin:ApplyBackdrop(panel, 0.1, 0.1) 
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.98) 
    
    -- Custom Border for visual control (User requested 60% alpha random colors)
    local cb = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    cb:SetFrameStrata("DIALOG")
    cb:SetFrameLevel(panel:GetFrameLevel() + 100)
    cb:SetAllPoints(panel)
    cb:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, bgFile = nil })
    cb:SetBackdropBorderColor(1, 1, 1, 0.5)
    panel.customBorder = cb
    
    -- Clipping
    if panel.SetClipsChildren then panel:SetClipsChildren(true) end
    
    -- Inner Container (Fixed Size)
    local inner = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    inner:SetSize(w, h - 2)
    inner:SetPoint("TOPRIGHT", -1, -1)
    
    Skin:ApplyBackdrop(inner, 0.1, 0.1) 
    inner:SetBackdropColor(0.05, 0.05, 0.05, 0.98) 
    Skin:SetSmartBorder(inner, 1)
    
    -- Header
    local header = CreateFrame("Frame", nil, inner, "BackdropTemplate")
    header:SetSize(w, 40)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    Skin:ApplyBackdrop(header); header:SetBackdropColor(0.15, 0.15, 0.15, 1)
    
    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.title:SetPoint("LEFT", 15, 0)
    header.title:SetText("Settings")
    
    -- Close Button (Red "Back")
    local btnClose = Skin:CreateButton(header, "Back", 80, 25)
    btnClose:SetPoint("RIGHT", -10, 0)
    
    local redColor = {0.8, 0.1, 0.1, 1}
    local redHover = {1, 0.2, 0.2, 1}
    btnClose:SetBackdropColor(unpack(redColor))
    btnClose:SetBackdropBorderColor(0.5, 0, 0, 1)
    btnClose:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(redHover)) end)
    btnClose:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(redColor)) end)
    
    btnClose:SetScript("OnClick", function() 
        if panel.onCloseHandler then
            panel.onCloseHandler(panel)
        else
            Skin:ToggleSlidePanel(panel, false) 
        end
    end)
    
    -- Content Container (Scrollable)
    local scroll, content = Skin:CreateScrollFrame(inner, w - 4, 10) -- Initial height 10, grows with content
    scroll:SetPoint("TOPLEFT", 0, -50)
    scroll:SetPoint("BOTTOMRIGHT", 0, 10)
    
    -- Fix ScrollBar visibility handling if needed or auto-managed by Skin
    -- Skin:CreateScrollFrame manages basic setup.
    
    -- ESC Handling (Animation support)
    panel:EnableKeyboard(true)
    panel:SetPropagateKeyboardInput(true)
    panel:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false) 
            if self.onCloseHandler then
                self.onCloseHandler(self)
            else
                Skin:ToggleSlidePanel(self, false)
            end
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    
    panel.header = header
    panel.inner = inner
    panel.scroll = scroll
    panel.content = content
    panel.targetWidth = targetW
    
    panel:Hide()
    return panel
end

function Skin:ToggleSlidePanel(panel, show)
    if not panel then return end
    
    if show then
        if panel.isSlideOpen then return end
        panel:Show()
        panel.isSlideOpen = true
        
        -- Animation: Grow
        local t = 0
        local duration = 0.35
        local startW = 1
        local endW = panel.targetWidth or 642
        
        -- Random Border Color (Alpha 0.5)
        local r, g, b = math.random(), math.random(), math.random()
        if panel.customBorder then
             panel.customBorder:SetBackdropBorderColor(r, g, b, 0.5)
        end
        
        panel:SetScript("OnUpdate", function(self, elapsed)
             t = t + elapsed
             if t >= duration then
                 self:SetWidth(endW)
                 self:SetScript("OnUpdate", nil)
                 return
             end
             local progress = 1 - math.pow(1 - t/duration, 3) -- Cubic Ease Out
             self:SetWidth(startW + (endW - startW) * progress)
        end)
    else
        if not panel.isSlideOpen then return end
        panel.isSlideOpen = false
        
        -- Main Frame ESC restore logic could be handled by caller if needed, 
        -- but since we consume ESC only when panel is focused, it should be fine.
        -- If specific main frame needs restoration to UISpecialFrames, caller should handle or we pass callback.
        
        -- Animation: Shrink
        local t = 0
        local duration = 0.25
        local startW = panel:GetWidth()
        local endW = 1
        
        panel:SetScript("OnUpdate", function(self, elapsed)
             t = t + elapsed
             if t >= duration then
                 self:Hide()
                 self:SetWidth(1)
                 self:SetScript("OnUpdate", nil)
                 return
             end
             local progress = (t/duration) * (t/duration) -- Quadratic Ease In
             self:SetWidth(startW + (endW - startW) * progress)
        end)
    end
end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    for name, path in pairs(Skin.Media.Fonts) do
        LSM:Register("font", name, path)
    end
    for _, name in ipairs(LSM:List("font")) do
        Skin.Media.Fonts[name] = LSM:Fetch("font", name)
    end
end

return ForgeSkin