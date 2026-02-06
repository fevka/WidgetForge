ForgeConfig = {}
local Config = ForgeConfig
local Skin = ForgeSkin

-- Varsayılan Ayarlar (Infinite Bars Structure)
Config.DefaultSettings = {
    globalScale = 1.0,
    bars = {
        [1] = {
            name = "Main Info",
            enabled = true,
            width = 250, height = 30,
            point = "CENTER", x = 0, y = 150,
            bgColor = {0, 0, 0, 0.6},
            layout = "HORIZONTAL", 
            showBorder = true,
            borderSize = 1,
            borderColor = {0.2, 0.2, 0.2, 1},
            padding = 10,
            elements = {
                [1] = { type = "FPS", label = "FPS", color = {1,1,1,1}, font="Friz Quadrata", size=14, outline="OUTLINE" },
                [2] = { type = "MS", label = "MS", color = {1,1,1,1}, font="Friz Quadrata", size=14, outline="OUTLINE" },
                [3] = { type = "Clock", label = "Time", color = {1,0.8,0,1}, font="Friz Quadrata", size=14, outline="OUTLINE" }
            }
        }
    }
}

Config.ElementTypes = {
    "FPS", "MS", "Clock", "RAM", "Durability", "Bag Space", 
    "Stamina", "Strength", "Agility", "Intellect", 
    "Crit", "Haste", "Mastery", "Versatility", 
    "Avoidance", "Leech", "Speed", "Dodge", "Parry",
    "Gold", "Zone", "Coords", "Item Level", "Combat Timer", "XP"
}

Config.Presets = {
    { text = "System Stats", value = {
        name = "System", width = 200, height = 30, bgColor = {0,0,0,0.5}, layout="HORIZONTAL", padding=5,
        elements = {{type="FPS", size=12, color={1,1,1,1}}, {type="MS", size=12, color={1,1,1,1}}, {type="RAM", size=12, color={1,1,1,1}}}
    }},
    { text = "Healer Grid", value = {
        name = "Healer Stats", width = 100, height = 120, bgColor = {0,0,0,0.6}, layout="VERTICAL", padding=8,
        elements = {{type="Intellect", size=14, color={0,1,1,1}}, {type="Crit", size=12, color={1,0.5,0,1}}, {type="Haste", size=12, color={1,1,0,1}}, {type="Mastery", size=12, color={0.5,0,1,1}}}
    }},
    { text = "Tank Panel", value = {
        name = "Tank Details", width = 300, height = 40, bgColor = {0.1,0.1,0.1,0.8}, layout="HORIZONTAL", padding=15,
        elements = {{type="Stamina", size=16, color={1,1,1,1}}, {type="Versatility", size=14, color={1,1,1,1}}, {type="Avoidance", size=14, color={1,1,1,1}}, {type="Durability", size=14, color={0,1,0,1}}}
    }},
    { text = "World Info", value = {
        name = "Exploration", width = 250, height = 60, bgColor = {0,0,0,0.5}, layout="VERTICAL", padding=5,
        elements = {{type="Zone", size=14, color={1,0.8,0,1}}, {type="Coords", size=12, color={1,1,1,1}}, {type="Gold", size=12, color={1,1,0,1}}}
    }}
}

-- Serialization is now handled by WidgetForgeUtils module

-- --- MAIN CONFIG WINDOW ---
function Config:OpenConfigWindow()
    if Config.Frame then Config.Frame:Show(); return end
    
    local f = CreateFrame("Frame", "EsrefConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(900, 600) -- [FINAL] Comfortable Width
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetFrameStrata("HIGH")
    Skin:ApplyBackdrop(f)
    
    -- Title Bar with Close Button
    Skin:CreateTitleBar(f, "WidgetForge | Advanced Status Bars", function() f:Hide() end)
    
    -- Locking Logic
    f:SetScript("OnShow", function() WidgetForge:SetBarsLocked(false) end)
    f:SetScript("OnHide", function() WidgetForge:SetBarsLocked(true) end)
    WidgetForge:SetBarsLocked(false) -- Unlock immediately when opening
    
    -- Force Select First Bar (or last selected)
    if not Config.SelectedBarIndex or not WidgetForgeDB.bars[Config.SelectedBarIndex] then
        Config.SelectedBarIndex = 1
    end
    -- Call SelectBar to ensure UI updates and highlighting works
    C_Timer.After(0.1, function() Config:SelectBar(Config.SelectedBarIndex) end)

    
    -- --- SIDEBAR (Bar List) ---
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 10, -40)
    sidebar:SetPoint("BOTTOMLEFT", 10, 100) -- Increased bottom margin for preset area
    sidebar:SetWidth(200)
    Skin:ApplyBackdrop(sidebar, 0.4, 0.8)

    local sbHeader = Skin:CreateSectionHeader(sidebar, "Active Bars", 180)
    sbHeader:SetPoint("TOPLEFT", 10, -10) -- Aligned with Configuration header (y=-10)

    -- Adjusted scroll frame width/position for better alignment
    local scrollBarList, contentBarList = Skin:CreateScrollFrame(sidebar, 180, 430)
    scrollBarList:SetPoint("TOPLEFT", 15, -50) -- Increased gap from header line
    scrollBarList:SetPoint("BOTTOMRIGHT", 0, 10) -- Moved right (closer to edge)
    Config.BarListContent = contentBarList

    -- Add New Bar Button
    local btnAdd = Skin:CreateButton(f, "+ New Empty Bar", 200, 25)
    btnAdd:SetPoint("TOPLEFT", sidebar, "BOTTOMLEFT", 0, -10)
    btnAdd:SetScript("OnClick", function()
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(Config.DefaultSettings.bars[1])
        WidgetForgeDB.bars[newId].name = "New Bar " .. newId
        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
    end)
    
    -- Preset Dropdown (Moved to BOTTOM LEFT to align with Import/Export)
    local ddPreset -- Forward declare
    
    local lblPreset = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPreset:SetText("QUICK ADD PRESET")
    
    -- Function to get combined presets
    local function GetPresetList()
        local list = {}
        for _, p in ipairs(Config.Presets) do table.insert(list, {text="[Def] "..p.text, value=p.value}) end
        if WidgetForgeDB.presets then
            for name, pData in pairs(WidgetForgeDB.presets) do
                 table.insert(list, {text="[Cust] "..name, value=pData, isCustom=true, name=name})
            end
        end
        return list
    end

    -- Compact Preset UI: [Dropdown (143)] [+] [-]
    ddPreset = Skin:CreateDropdown(f, 143, GetPresetList(), function(val)
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(val)
        -- Ensure defaults
        WidgetForgeDB.bars[newId].enabled = true
        WidgetForgeDB.bars[newId].point = "CENTER"
        WidgetForgeDB.bars[newId].x = 0
        WidgetForgeDB.bars[newId].y = 0
        if WidgetForgeDB.bars[newId].showBorder == nil then WidgetForgeDB.bars[newId].showBorder = true end
        
        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
        
        -- Reset dropdown text to indicate action taken or just leave it
        -- For now, we leave it as the selected preset name
    end)
    
    -- Position at bottom left (align with Import/Export which are at y=10)
    ddPreset:SetPoint("BOTTOMLEFT", 10, 10)
    lblPreset:SetPoint("BOTTOMLEFT", ddPreset, "TOPLEFT", 0, 5)
    f.ddPreset = ddPreset -- Store ref
    
    -- Save Button [+]
    local btnSavePreset = Skin:CreateButton(f, "+", 25, 25)
    btnSavePreset.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "THICK")
    btnSavePreset:SetPoint("LEFT", ddPreset, "RIGHT", 5, 0)
    btnSavePreset:SetScript("OnClick", function()
        local selIndex = Config.SelectedBarIndex
        if not selIndex or not WidgetForgeDB.bars[selIndex] then print("Select a bar first."); return end
        
        Skin:CreateInputDialog("Save Preset", WidgetForgeDB.bars[selIndex].name, function(text)
            if not WidgetForgeDB.presets then WidgetForgeDB.presets = {} end
            WidgetForgeDB.presets[text] = CopyTable(WidgetForgeDB.bars[selIndex])
            -- Clean up positioning
            WidgetForgeDB.presets[text].point = nil
            WidgetForgeDB.presets[text].x = nil
            WidgetForgeDB.presets[text].y = nil
            
            print("|cff00ff00Preset '"..text.."' saved.|r")
            
            -- Refresh dropdown immediately
            ddPreset:SetList(GetPresetList())
            ddPreset:SetValue(nil, "[Cust] "..text) -- Auto-select/visualize the new preset
        end)
    end)
    
    -- Delete Button [-]
    local btnDelPreset = Skin:CreateButton(f, "-", 25, 25)

       btnDelPreset.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "THICK")
    btnDelPreset:SetPoint("LEFT", btnSavePreset, "RIGHT", 2, 0)
    btnDelPreset:SetScript("OnClick", function()
        if not WidgetForgeDB.presets or not next(WidgetForgeDB.presets) then
            print("|cffff0000No custom presets to delete.|r")
            return
        end
        
        -- Build custom preset list for dropdown
        local customList = {}
        for name, _ in pairs(WidgetForgeDB.presets) do
            table.insert(customList, {text = name, value = name})
        end
        
        -- Create dropdown dialog
        local deleteFrame = CreateFrame("Frame", "ForgeDeletePresetDialog", UIParent, "BackdropTemplate")
        deleteFrame:SetSize(350, 140)
        deleteFrame:SetPoint("CENTER")
        deleteFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        deleteFrame:EnableMouse(true)
        deleteFrame:SetMovable(true)
        deleteFrame:RegisterForDrag("LeftButton")
        deleteFrame:SetScript("OnDragStart", deleteFrame.StartMoving)
        deleteFrame:SetScript("OnDragStop", deleteFrame.StopMovingOrSizing)
        
        Skin:ApplyBackdrop(deleteFrame)
        deleteFrame:SetBackdropColor(unpack(Skin.Colors.bg))
        Skin:SetSmartBorder(deleteFrame, 2, {r=1, g=0.3, b=0.3, a=1}, "OUTSIDE")
        
        Skin:CreateTitleBar(deleteFrame, "Delete Preset", function() deleteFrame:Hide() end)
        
        local ddDelete = Skin:CreateDropdown(deleteFrame, 310, customList, function(presetName)
            Skin:CreateConfirmDialog(
                "Confirm Delete",
                "Are you sure you want to delete preset '" .. presetName .. "'?",
                function()
                    WidgetForgeDB.presets[presetName] = nil
                    print("|cffff0000Preset '"..presetName.."' deleted.|r")
                    
                    -- Refresh main dropdown
                    ddPreset:SetList(GetPresetList())
                    ddPreset:SetValue(nil, "Select...")
                    
                    deleteFrame:Hide()
                end
            )
        end)
        ddDelete:SetPoint("TOP", 0, -50)
        deleteFrame:Show()
    end)


    -- --- IMPORT / EXPORT BUTTONS ---
    local btnExport = Skin:CreateButton(f, "Export Profile", 100, 25)
    btnExport:SetPoint("BOTTOMRIGHT", -10, 10)
    btnExport:SetScript("OnClick", function()
        local str = WidgetForgeUtils:Serialize(WidgetForgeDB)
        Skin:CreateTextWindow("Export Profile Data", str, nil)
    end)
    
    local btnImport = Skin:CreateButton(f, "Import Profile", 100, 25)
    btnImport:SetPoint("RIGHT", btnExport, "LEFT", -10, 0)
    btnImport:SetScript("OnClick", function()
        Skin:CreateTextWindow("Import Profile Data", "", function(text)
            local t = WidgetForgeUtils:Deserialize(text)
            if t and t.bars then
                WidgetForgeDB = t
                Config:RefreshBarList()
                WidgetForge:UpdateAvailableBars()
                print("|cff00ff00WidgetForge:|r Profile imported successfully.")
                Config.DetailsContent:HideAllChildren()
            else
                print("|cffff0000WidgetForge:|r Invalid profile string!")
            end
        end)
    end)

    -- --- MAIN PANEL (Details) ---
    local mainPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    mainPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    mainPanel:SetPoint("BOTTOMRIGHT", -10, 50)
    Skin:ApplyBackdrop(mainPanel, 0.2, 0.5)

    local scrollDetails, contentDetails = Skin:CreateScrollFrame(mainPanel, 660, 510) -- [FINAL] Wider for comfortable layout
    scrollDetails:SetPoint("TOPLEFT", 0, 0)
    scrollDetails:SetPoint("BOTTOMRIGHT", 0, 0)
    
    -- Helper to clear children
    -- Helper to clear children
    function contentDetails:HideAllChildren()
        local kids = {self:GetChildren()}
        for _, k in ipairs(kids) do k:Hide() end
        local regions = {self:GetRegions()}
        for _, r in ipairs(regions) do r:Hide() end
    end
    Config.DetailsContent = contentDetails

    Config.Frame = f
    Config:RefreshBarList()
end

function Config:RefreshBarList()
    local content = Config.BarListContent
    if content.buttons then for _, b in pairs(content.buttons) do b:Hide() end end
    content.buttons = {}

    local y = -5
    local width = content:GetWidth()
    for i, bar in ipairs(WidgetForgeDB.bars) do
        -- Filter by Scope (Character)
        local showInList = true
        if bar.scope then
            local myName = UnitName("player") .. "-" .. GetRealmName()
            if bar.scope.type == "CHARACTER" then
                if bar.scope.value ~= myName then showInList = false end
            elseif bar.scope.type == "SPEC" and bar.scope.character then
                 if bar.scope.character ~= myName then showInList = false end
            end
        end

        if showInList then
            local btn = Skin:CreateButton(content, bar.name, 155, 30)
            btn:SetPoint("TOP", 0, y) -- Centered relative to content
            
            -- Highlight Selected
            if i == Config.SelectedBarIndex then
                 btn:SetBackdropColor(0, 0.7, 1, 0.4) -- Active Blue Highlight
                 btn:SetBackdropBorderColor(0, 0.8, 1, 1) -- Active Border
                 
                 -- [FIX] Disable default hover scripts to prevent color reset
                 btn:SetScript("OnEnter", nil)
                 btn:SetScript("OnLeave", nil)
            end
            
            btn:SetScript("OnClick", function() Config:SelectBar(i) end)
            
            -- Delete Button (Small X)
            local btnDel = Skin:CreateButton(btn, "X", 20, 20)
            btnDel:SetPoint("RIGHT", -5, 0)
            btnDel.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            btnDel:SetScript("OnClick", function() 
                table.remove(WidgetForgeDB.bars, i)
                Config:RefreshBarList()
                Config.DetailsContent:HideAllChildren()
                WidgetForge:UpdateAvailableBars()
            end)
            
            table.insert(content.buttons, btn)
            y = y - 35
        end
    end
end

function Config:SelectBar(index)
    Config.SelectedBarIndex = index
    
    -- Update Main Addon (for visual cues like Drag Button Scale)
    if WidgetForge.SetSelectedBar then
        WidgetForge:SetSelectedBar(index)
    end

    Config:RefreshBarList() -- Refresh list to update selection highlight
    
    local content = Config.DetailsContent
    if not content then return end -- Safety check: Config window not created yet
    content:HideAllChildren()
    
    local bar = WidgetForgeDB.bars[index]
    if not bar then return end
    
    local y = -10
    
    -- --- SECTION 1: BAR LAYOUT (Name, Scope, Title, Layout Type) ---
    local hLayout = Skin:CreateSectionHeader(content, "Bar Layout: " .. bar.name, 620)
    hLayout:SetPoint("TOPLEFT", 10, y)
    
    -- [NEW] Scope Dropdown - Positioned relative to header
    local scopeList = {
        {text = "Global (Account)", value = "GLOBAL"},
        {text = "This Character", value = "CHARACTER"},
        {text = "Current Spec", value = "SPEC"}
    }
    local currentScopeVal = "GLOBAL"
    if bar.scope then currentScopeVal = bar.scope.type end
    
    local ddScope = Skin:CreateDropdown(content, 150, scopeList, currentScopeVal, function(v)
        if v == "GLOBAL" then
            bar.scope = nil
        elseif v == "CHARACTER" then
            bar.scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }
        elseif v == "SPEC" then
            local spec = GetSpecialization()
            if spec then
                 bar.scope = { 
                    type = "SPEC", 
                    value = GetSpecializationInfo(spec),
                    character = UnitName("player") .. "-" .. GetRealmName()
                 }
            else
                 print("Error: No Spec active.")
                 return
            end
        end
        WidgetForge:UpdateAvailableBars()
    end)
    ddScope:SetPoint("TOPRIGHT", hLayout, "TOPRIGHT", 0, 2) 

    y = y - 40

    -- Row 1: Name (Label Left) | Show Title (Checkbox) | Vertical Layout (Checkbox)
    -- Col 1: Name
    local lblName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblName:SetPoint("TOPLEFT", 10, y - 8)
    lblName:SetText("Bar Name:")
    lblName:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local ebNameFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ebNameFrame:SetSize(180, 25) 
    ebNameFrame:SetPoint("TOPLEFT", 90, y)
    Skin:ApplyBackdrop(ebNameFrame); ebNameFrame:SetBackdropColor(0,0,0,0.5); ebNameFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    local ebName = CreateFrame("EditBox", nil, ebNameFrame)
    ebName:SetAllPoints(ebNameFrame)
    ebName:SetFont(Skin.Constants.FONT_NORMAL, 12, "OUTLINE")
    ebName:SetTextInsets(5, 5, 0, 0); ebName:SetAutoFocus(false); ebName:SetText(bar.name)
    ebName:SetScript("OnEnterPressed", function(self) 
        bar.name = self:GetText()
        if hLayout and hLayout.text then hLayout.text:SetText(string.upper("Bar Layout: " .. bar.name)) end
        Config:RefreshBarList()
        self:ClearFocus() 
    end)
    ebName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Col 2: Show Title
    local chkTitle = Skin:CreateCheckbox(content, "Show Title Bar", bar.showTitle, function(v) 
        bar.showTitle = v; WidgetForge:RebuildBarComponents(index) 
    end)
    chkTitle:SetPoint("TOPLEFT", 290, y - 3)

    -- Col 3: Vertical Layout
    local chkLayout = Skin:CreateCheckbox(content, "Vertical Layout", bar.layout == "VERTICAL", function(v) 
        bar.layout = v and "VERTICAL" or "HORIZONTAL"
        Config:SelectBar(index); WidgetForge:RebuildBarComponents(index)
    end)
    chkLayout:SetPoint("TOPLEFT", 430, y - 3)

    y = y - 40

    -- Row 2: Alignment | Spacing | Background
     -- Col 1: Alignment
    local lblJ = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblJ:SetPoint("TOPLEFT", 10, y - 8); lblJ:SetText("Alignment:")
    lblJ:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local justifyList = { "LEFT", "CENTER", "RIGHT" }
    local ddJustify = Skin:CreateDropdown(content, 120, justifyList, bar.justify or "CENTER", function(v)
        bar.justify = v; WidgetForge:RebuildBarComponents(index)
    end)
    ddJustify:SetPoint("TOPLEFT", 90, y)

    -- Col 2: Spacing
    local lblPad = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblPad:SetPoint("TOPLEFT", 230, y - 8); lblPad:SetText("Spacing:")
    lblPad:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local slPad = Skin:CreateSlider(content, 0, 50, 1, bar.padding or 5, function(v) bar.padding = v; WidgetForge:UpdateAvailableBars() end, 120)
    slPad:SetPoint("TOPLEFT", 290, y)

    -- Col 3: Background
    local lblBg = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblBg:SetPoint("TOPLEFT", 430, y - 8); lblBg:SetText("Background Color:")
    lblBg:SetFont(Skin.Constants.FONT_NORMAL, 11, "")

    local btnBg = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBg:SetSize(20, 20); btnBg:SetPoint("TOPLEFT", 540, y - 3 ) 
    Skin:ApplyBackdrop(btnBg)
    local bg = bar.bgColor or {0, 0, 0, 0.5} 
    btnBg:SetBackdropColor(unpack(bg))
    btnBg:SetScript("OnClick", function()
        local info = { r=bg[1], g=bg[2], b=bg[3], opacity=bg[4], swatchFunc = function(c) bar.bgColor = c; btnBg:SetBackdropColor(unpack(c)); WidgetForge:UpdateAvailableBars() end }
        Skin:ShowColorPicker(info)
    end)

    y = y - 50

    -- --- SECTION 2: BAR SIZE ---
    local hSize = Skin:CreateSectionHeader(content, "Bar Size", 620)
    hSize:SetPoint("TOPLEFT", 10, y)
    y = y - 40

    -- Col 1: Width
    local lblW = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblW:SetPoint("TOPLEFT", 10, y - 8); lblW:SetText("Bar Width:")
    lblW:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local slW = Skin:CreateSlider(content, 50, 600, 5, bar.width, function(v) bar.width = v; WidgetForge:UpdateAvailableBars() end, 150)
    slW:SetPoint("TOPLEFT", 90, y)
    
    -- Col 2: Height
    local lblH = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblH:SetPoint("TOPLEFT", 260, y - 8); lblH:SetText("Bar Height:")
    lblH:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local slH = Skin:CreateSlider(content, 10, 200, 2, bar.height, function(v) bar.height = v; WidgetForge:UpdateAvailableBars() end, 150)
    slH:SetPoint("TOPLEFT", 340, y)
    
    y = y - 50

    -- --- SECTION 3: BORDER SETTINGS ---
    local hBorder = Skin:CreateSectionHeader(content, "Border Settings", 620)
    hBorder:SetPoint("TOPLEFT", 10, y)
    y = y - 40

    -- Col 1: Border Size
    local lblBS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblBS:SetPoint("TOPLEFT", 10, y - 8); lblBS:SetText("Border Size:")
    lblBS:SetFont(Skin.Constants.FONT_NORMAL, 11, "")

    local slBS = Skin:CreateSlider(content, 1, 10, 1, bar.borderSize or 1, function(v) bar.borderSize = v; WidgetForge:UpdateAvailableBars() end, 150)
    slBS:SetPoint("TOPLEFT", 90, y)
    
    -- Col 2: Border Color
    local lblBC = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblBC:SetPoint("TOPLEFT", 260, y - 8); lblBC:SetText("Border Color:")
    lblBC:SetFont(Skin.Constants.FONT_NORMAL, 11, "")

    local btnBC = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBC:SetSize(20, 20); btnBC:SetPoint("TOPLEFT", 340, y - 3) 
    Skin:ApplyBackdrop(btnBC)
    local bc = bar.borderColor or {0.2, 0.2, 0.2, 1}
    btnBC:SetBackdropColor(unpack(bc))
    btnBC:SetScript("OnClick", function()
        local info = { r=bc[1], g=bc[2], b=bc[3], opacity=bc[4], swatchFunc = function(c) bar.borderColor = c; btnBC:SetBackdropColor(unpack(c)); WidgetForge:UpdateAvailableBars() end }
        Skin:ShowColorPicker(info)
    end)
    
    -- Col 3: Show Border (Checkbox)
    local chkBorder = Skin:CreateCheckbox(content, "Enable Border", bar.showBorder, function(v) 
        bar.showBorder = v; WidgetForge:UpdateAvailableBars() 
    end)
    chkBorder:SetPoint("TOPLEFT", 430, y - 3)

    y = y - 60

    -- --- ELEMENTS ---
    local headEl = Skin:CreateSectionHeader(content, "Bar Elements", 620)
    headEl:SetPoint("TOPLEFT", 10, y); y = y - 40

    -- Add Elements Grid
    local gridX, gridY = 0, 0
    for i, typeName in ipairs(Config.ElementTypes) do
        local btn = Skin:CreateButton(content, typeName, 120, 20)
        btn:SetPoint("TOPLEFT", 10 + (gridX * 125), y - (gridY * 25))
        
        -- STAT FILTERING
        if not WidgetForge:IsStatAllowed(typeName) then
            btn:Disable()
            btn:SetAlpha(0.5)
        else
            -- Check if already added
             local exists = false
            for _, e in ipairs(bar.elements) do
                if e.type == typeName then exists = true; break end
            end
    
            if exists then
                -- Selected Styling
                btn:SetBackdropColor(unpack(Skin.Colors.accent))
                btn:SetBackdropBorderColor(1, 1, 1, 1)
                btn.text:SetTextColor(1, 1, 1, 1) 
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                
                -- Toggle: Remove on Click
                btn:SetScript("OnClick", function()
                     for idx, e in ipairs(bar.elements) do
                         if e.type == typeName then
                             table.remove(bar.elements, idx)
                             break
                         end
                     end
                     C_Timer.After(0.05, function() Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
                end)
            else
                -- Not Selected: Add on Click
                btn:SetScript("OnClick", function()
                     table.insert(bar.elements, { 
                         type = typeName, 
                         label = typeName, 
                         color = {1,1,1,1}, 
                         font = "Friz Quadrata", 
                         size = 14, 
                         outline = "OUTLINE" 
                     })
                     C_Timer.After(0.05, function() Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
                end)
            end
        end

        gridX = gridX + 1
        if gridX > 4 then gridX = 0; gridY = gridY + 1 end
    end
    y = y - (gridY * 25) - 40
    
    -- Active Elements List
    local fontList = {}
    for k, v in pairs(Skin.Media.Fonts) do 
        table.insert(fontList, {text=k, value=k, font=v}) 
    end
    
    local outlineList = {
        {text="None", value=""},
        {text="Outline", value="OUTLINE"},
        {text="Thick", value="THICKOUTLINE"},
        {text="Mono", value="MONOCHROME"},
        {text="Mono+Out", value="MONOCHROME,OUTLINE"}
    }

    
    Config.ElementRows = {}  -- Clear before rebuilding
    
    for i, elem in ipairs(bar.elements) do
        local item = CreateFrame("Frame", nil, content, "BackdropTemplate")
        item:SetSize(620, 32) -- [FINAL] Increased width per user request
        item:SetPoint("TOPLEFT", 10, y)
        Skin:ApplyBackdrop(item, 0.3, 0.5)
        
        -- 1. Label (Kept on Left)
        item.txt = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        item.txt:SetPoint("LEFT", 8, 0)
        item.txt:SetText(i..". "..elem.type)
        item.txt:SetFont(Skin.Constants.FONT_NORMAL, 11, "OUTLINE")
        item.txt:SetWidth(110) -- Reduced from 150 to fit new controls
        item.txt:SetJustifyH("LEFT")

        -- RIGHT-ALIGNED FLOW
        -- Order from Right: [Delete] [Drag] [Color] [Size] [Outline] [Font] [Icon] [Tooltip] [Format]
        
        -- 6. Delete Button (Anchor)
        local btnRem = Skin:CreateButton(item, "X", 20, 20)
        btnRem:SetPoint("RIGHT", -10, 0)
        btnRem.text:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE")
        btnRem:SetScript("OnClick", function() table.remove(bar.elements, i); Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
        
        -- 7. Drag Handle (Standardized)
        local dragHandle = Skin:CreateGripHandle(item, 20, 20)
        dragHandle:SetPoint("RIGHT", btnRem, "LEFT", -4, 0)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        
        Config.ElementRows[i] = item
        item.rowIndex = i

        -- DRAG AND DROP - ULTRA SIMPLE VERSION
        dragHandle:SetScript("OnDragStart", function()
            -- Store which element we're dragging
            dragHandle.dragSourceIndex = i
            
            -- Green color
            for _, line in ipairs(dragHandle.lines) do
                line:SetVertexColor(0, 1, 0, 1)
            end
            
            -- Create ghost if needed
            if not Config.DragGhost then
                Config.DragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                Config.DragGhost:SetFrameStrata("TOOLTIP")
                Config.DragGhost:SetSize(100, 25)
                Config.DragGhost:EnableMouse(false)
                Skin:ApplyBackdrop(Config.DragGhost)
                Config.DragGhost.text = Config.DragGhost:CreateFontString(nil, "OVERLAY")
                Config.DragGhost.text:SetFont(Skin.Constants.FONT_NORMAL, 11, "OUTLINE")
                Config.DragGhost.text:SetPoint("CENTER")
            end
            
            Config.DragGhost.text:SetText(i .. ": " .. elem.type)
            Config.DragGhost:Show()
        end)
        
        dragHandle:SetScript("OnDragStop", function()
            if Config.DragGhost then
                Config.DragGhost:Hide()
            end
            
            -- Reset color
            for _, line in ipairs(dragHandle.lines) do
                line:SetVertexColor(unpack(Skin.Colors.accent))
            end
            
            if not dragHandle.dragSourceIndex then return end
            
            local sourceIdx = dragHandle.dragSourceIndex
            dragHandle.dragSourceIndex = nil
            
            -- Find target: Y koordinatına en yakın row
            local _, mouseY = GetCursorPosition()
            local closestIdx = sourceIdx
            local minDist = 999999
            
            for idx = 1, #Config.ElementRows do
                if idx ~= sourceIdx then
                    local row = Config.ElementRows[idx]
                    if row then
                        local rowScale = row:GetEffectiveScale()
                        local _, rowCenterY = row:GetCenter()
                        if rowCenterY then
                            local rowScreenY = rowCenterY * rowScale
                            local dist = math.abs(rowScreenY - mouseY)
                            if dist < minDist then
                                minDist = dist
                                closestIdx = idx
                            end
                        end
                    end
                end
            end
            
            -- SWAP (not insert!)
            if closestIdx ~= sourceIdx then
                -- Direct exchange: only these two positions change
                bar.elements[sourceIdx], bar.elements[closestIdx] = bar.elements[closestIdx], bar.elements[sourceIdx]
                Config:SelectBar(index)
                WidgetForge:RebuildBarComponents(index)
            end
        end)
        
        dragHandle:SetScript("OnUpdate", function()
            if dragHandle.dragSourceIndex and Config.DragGhost then
                -- Update ghost position
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                Config.DragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/scale, y/scale)
                
                -- Highlight target row
                local _, mouseY = GetCursorPosition()
                local targetIdx = dragHandle.dragSourceIndex
                local minDist = 999999
                
                for idx = 1, #Config.ElementRows do
                    if idx ~= dragHandle.dragSourceIndex then
                        local row = Config.ElementRows[idx]
                        if row then
                            local rowScale = row:GetEffectiveScale()
                            local _, rowCenterY = row:GetCenter()
                            if rowCenterY then
                                local rowScreenY = rowCenterY * rowScale
                                local dist = math.abs(rowScreenY - mouseY)
                                if dist < minDist then
                                    minDist = dist
                                    targetIdx = idx
                                end
                            end
                        end
                    end
                end
                
                -- Apply highlights
                for idx = 1, #Config.ElementRows do
                    local row = Config.ElementRows[idx]
                    if row then
                        if idx == targetIdx and idx ~= dragHandle.dragSourceIndex then
                            row:SetBackdropBorderColor(1, 0.8, 0, 1)
                        else
                            row:SetBackdropBorderColor(unpack(Skin.Colors.border))
                        end
                    end
                end
            end
        end)
        
        dragHandle:SetScript("OnEnter", function()
            if not dragHandle.dragSourceIndex then
                for _, line in ipairs(dragHandle.lines) do
                    line:SetVertexColor(1, 1, 1, 1)
                end
            end
        end)
        
        dragHandle:SetScript("OnLeave", function()
            if not dragHandle.dragSourceIndex then
                for _, line in ipairs(dragHandle.lines) do
                    line:SetVertexColor(unpack(Skin.Colors.accent))
                end
            end
            GameTooltip:Hide()
        end)

        -- 8. Color Button
        local btnCol = CreateFrame("Button", nil, item, "BackdropTemplate")
        btnCol:SetSize(20, 20)
        btnCol:SetPoint("RIGHT", dragHandle, "LEFT", -8, 0)
        Skin:ApplyBackdrop(btnCol); btnCol:SetBackdropColor(unpack(elem.color or {1, 1, 1, 1}))
        btnCol:SetScript("OnClick", function()
            local oldColor = elem.color or {1, 1, 1, 1}
            local info = { r=oldColor[1], g=oldColor[2], b=oldColor[3], opacity=oldColor[4], 
                swatchFunc = function(c) elem.color = c; btnCol:SetBackdropColor(unpack(c)); WidgetForge:RebuildBarComponents(index) end,
                cancelFunc = function() elem.color = oldColor; btnCol:SetBackdropColor(unpack(oldColor)); WidgetForge:RebuildBarComponents(index) end }
            Skin:ShowColorPicker(info)
        end)
        
        -- 5. Size Slider (Reduced Width: 70)
        local slSz = Skin:CreateSlider(item, 8, 50, 1, elem.size, function(v) elem.size = v; WidgetForge:RebuildBarComponents(index) end, 70)
        slSz:SetPoint("RIGHT", btnCol, "LEFT", -15, 0)

        -- 4. Outline (Reduced Width: 85)
        local ddOutline = Skin:CreateDropdown(item, 85, outlineList, elem.outline or "OUTLINE", function(v) elem.outline = v; WidgetForge:RebuildBarComponents(index) end)
        ddOutline:SetPoint("RIGHT", slSz, "LEFT", -10, 0) 

        -- 3. Font (Reduced Width: 100)
        local ddFont = Skin:CreateDropdown(item, 100, fontList, elem.font or "Standard", function(v) elem.font = v; WidgetForge:RebuildBarComponents(index) end)
        ddFont:SetPoint("RIGHT", ddOutline, "LEFT", -10, 0)

        -- 2. Icon Checkbox
        local chkIcon = Skin:CreateCheckbox(item, "Icon", elem.showIcon, function(v) elem.showIcon = v; WidgetForge:RebuildBarComponents(index) end)
        chkIcon:SetWidth(45) 
        chkIcon:SetPoint("RIGHT", ddFont, "LEFT", -5, 0)
        chkIcon.box:SetSize(14, 14) 
        chkIcon.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE")
        
        -- [NEW] Tooltip Checkbox
        local chkTip = Skin:CreateCheckbox(item, "Tip", elem.showTooltip, function(v) elem.showTooltip = v; WidgetForge:RebuildBarComponents(index) end)
        chkTip:SetWidth(40)
        chkTip:SetPoint("RIGHT", chkIcon, "LEFT", -5, 0)
        chkTip.box:SetSize(14, 14) 
        chkTip.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE") 
        
        -- [NEW] Clock Format (Conditional)
        if elem.type == "Clock" then
             local fmtList = { {text="24h", value="24h"}, {text="12h", value="12h"} }
             local ddFmt = Skin:CreateDropdown(item, 50, fmtList, elem.timeFormat or "24h", function(v) elem.timeFormat = v; WidgetForge:RebuildBarComponents(index) end)
             ddFmt:SetPoint("RIGHT", chkTip, "LEFT", -5, 0)
        end

        y = y - 36 
    end
    
    content:SetHeight(math.abs(y) + 20)
end

SLASH_WIDGETFORGE1 = "/wf"
SlashCmdList["WIDGETFORGE"] = function() 
    Config:OpenConfigWindow() 
    if #WidgetForgeDB.bars > 0 then Config:SelectBar(1) end
end
