ForgeConfig = {}
local Config = ForgeConfig
local Skin = ForgeSkin

-- Varsayılan Ayarlar
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
    "Divider", "FPS", "MS", "Clock", "RAM", "Durability", "Bag Space", 
    "Stamina", "Main Stat", 
    "Crit", "Haste", "Mastery", "Versatility", 
    "Avoidance", "Leech", "Speed", "Run Speed", "Dodge", "Parry", "Armor", "Max HP",
    "Gold", "Zone", "Coords", "Item Level", "Combat Timer", "XP",
    "Dragonriding", "Dummy"
}

Config.Presets = {
    { text = "General Stats", value = {
        name = "Essentials", width = 250, height = 30, bgColor = {0,0,0,0.5}, layout="HORIZONTAL", padding=8,
        elements = {
            {type="FPS", size=12, color={1,1,1,1}, showIcon=true}, 
            {type="MS", size=12, color={1,1,1,1}, showIcon=true}, 
            {type="Clock", size=12, color={1,0.8,0,1}, showIcon=true},
            {type="Durability", size=12, color={0,1,0,1}, showIcon=true}
        }
    }},
    { text = "DPS/Healer Core", value = {
        name = "Combat Stats", width = 120, height = 140, bgColor = {0,0,0,0.6}, layout="VERTICAL", padding=6,
        elements = {
            {type="Main Stat", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Crit", size=12, color={1,0.5,0,1}, showIcon=true}, 
            {type="Haste", size=12, color={1,1,0,1}, showIcon=true}, 
            {type="Mastery", size=12, color={0.5,0,1,1}, showIcon=true}
        }
    }},
    { text = "Tank Survivability", value = {
        name = "Tank Stats", width = 320, height = 40, bgColor = {0.1,0.1,0.1,0.8}, layout="HORIZONTAL", padding=12,
        elements = {
            {type="Stamina", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Versatility", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Avoidance", size=14, color={1,1,1,1}, showIcon=true},
            {type="Main Stat", size=14, color={1,1,1,1}, showIcon=true} 
        }
    }},
    { text = "Leveling & Farm", value = {
        name = "Adventure", width = 220, height = 80, bgColor = {0,0,0,0.5}, layout="VERTICAL", padding=5,
        elements = {
            {type="XP", size=12, color={0,0.8,1,1}, showIcon=true}, 
            {type="Gold", size=12, color={1,1,0,1}, showIcon=true}, 
            {type="Bag Space", size=12, color={1,1,1,1}, showIcon=true},
            {type="Item Level", size=12, color={1,0.5,1,1}, showIcon=true}
        }
    }},
    { text = "Dragonriding HUD", value = {
        name = "Skyriding", width = 320, height = 50, bgColor = {0,0,0,0}, layout="HORIZONTAL", padding=0,
        showBorder = false,
        elements = {
            {type="Dragonriding", size=14, color={1,1,1,1},
             vigorFillColor = {0, 0.85, 0.85, 1},
             vigorEmptyColor = {0.15, 0.15, 0.15, 1},
             speedBarColor = {0.7, 0, 0.7, 1},
             speedEmptyColor = {0.15, 0.15, 0.15, 1},
             speedTextColor = {1, 1, 1, 1},
             widgetWidth = 300, widgetHeight = 45
            }
        }
    }}
}

-- --- MAIN CONFIG WINDOW ---
function Config:OpenConfigWindow()
    if Config.Frame then Config.Frame:Show(); return end
    
    local f = CreateFrame("Frame", "EsrefConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(870, 600) 
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    Skin:ApplyBackdrop(f)
    tinsert(UISpecialFrames, "EsrefConfigFrame")
    
    Skin:CreateTitleBar(f, "WidgetForge | Advanced Status Bars", function() f:Hide() end)
    
    f:SetScript("OnShow", function() WidgetForge:SetBarsLocked(false) end)
    f:SetScript("OnHide", function() WidgetForge:SetBarsLocked(true) end)
    WidgetForge:SetBarsLocked(false) 
    
    -- [PRIORITY LOGIC]
    local needsNewSelection = false
    
    if not Config.SelectedBarIndex or not WidgetForgeDB.bars[Config.SelectedBarIndex] then
        needsNewSelection = true
    else
        if not WidgetForge:IsBarRelevant(WidgetForgeDB.bars[Config.SelectedBarIndex]) then
            needsNewSelection = true
        end
    end

    if needsNewSelection then
        local bestIndex = nil
        local bestPriority = -1 
        
        for i, bar in ipairs(WidgetForgeDB.bars) do
            if WidgetForge:IsBarRelevant(bar) then
                local priority = 0 
                
                if bar.scope then
                    if bar.scope.type == "CHARACTER" then priority = 10 
                    elseif bar.scope.type == "SPEC" then priority = 5 end
                end
                
                if priority > bestPriority then
                    bestPriority = priority
                    bestIndex = i
                end
            end
        end
        Config.SelectedBarIndex = bestIndex
    end

    C_Timer.After(0.1, function() Config:SelectBar(Config.SelectedBarIndex) end)

    
    -- --- SIDEBAR (Bar List) ---
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 10, -40)
    sidebar:SetPoint("BOTTOMLEFT", 10, 100) 
    sidebar:SetWidth(200)
    Skin:ApplyBackdrop(sidebar, 0.4, 0.8)

    local sbHeader = Skin:CreateSectionHeader(sidebar, "Active Bars", 180)
    sbHeader:SetPoint("TOPLEFT", 10, -10) 

    local scrollBarList, contentBarList = Skin:CreateScrollFrame(sidebar, 180, 430)
    scrollBarList:SetPoint("TOPLEFT", 15, -50) 
    scrollBarList:SetPoint("BOTTOMRIGHT", 0, 10) 
    Config.BarListContent = contentBarList

    -- Add New Bar Button
    local btnAdd = Skin:CreateButton(f, "+ New Empty Bar", 200, 25)
    btnAdd:SetPoint("TOPLEFT", sidebar, "BOTTOMLEFT", 0, -10)
    btnAdd:SetScript("OnClick", function()
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(Config.DefaultSettings.bars[1])
        WidgetForgeDB.bars[newId].name = "New Bar " .. newId
        WidgetForgeDB.bars[newId].scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }

        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
    end)
    
    -- Preset Dropdown 
    local ddPreset 
    local lblPreset = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPreset:SetText("QUICK ADD PRESET")
    
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

    ddPreset = Skin:CreateDropdown(f, 143, GetPresetList(), function(val)
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(val)
        WidgetForgeDB.bars[newId].enabled = true
        WidgetForgeDB.bars[newId].point = "CENTER"
        WidgetForgeDB.bars[newId].x = 0
        WidgetForgeDB.bars[newId].y = 0
        if WidgetForgeDB.bars[newId].showBorder == nil then WidgetForgeDB.bars[newId].showBorder = true end
        WidgetForgeDB.bars[newId].scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }

        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
    end)
    
    ddPreset:SetPoint("BOTTOMLEFT", 10, 10)
    lblPreset:SetPoint("BOTTOMLEFT", ddPreset, "TOPLEFT", 0, 5)
    f.ddPreset = ddPreset 
    
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
            WidgetForgeDB.presets[text].point = nil
            WidgetForgeDB.presets[text].x = nil
            WidgetForgeDB.presets[text].y = nil
            print("|cff00ff00Preset '"..text.."' saved.|r")
            ddPreset:SetList(GetPresetList())
            ddPreset:SetValue(nil, "[Cust] "..text) 
        end)
    end)
    
    -- Delete Button [-]
    local btnDelPreset = Skin:CreateButton(f, "-", 25, 25)
    btnDelPreset.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "THICK")
    btnDelPreset:SetPoint("LEFT", btnSavePreset, "RIGHT", 2, 0)
    btnDelPreset:SetScript("OnClick", function()
        if not WidgetForgeDB.presets or not next(WidgetForgeDB.presets) then print("|cffff0000No custom presets.|r"); return end
        local customList = {}
        for name, _ in pairs(WidgetForgeDB.presets) do table.insert(customList, {text = name, value = name}) end
        
        local deleteFrame = CreateFrame("Frame", "ForgeDeletePresetDialog", UIParent, "BackdropTemplate")
        deleteFrame:SetSize(350, 140)
        deleteFrame:SetPoint("CENTER")
        deleteFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        deleteFrame:EnableMouse(true); deleteFrame:SetMovable(true)
        deleteFrame:RegisterForDrag("LeftButton"); deleteFrame:SetScript("OnDragStart", deleteFrame.StartMoving); deleteFrame:SetScript("OnDragStop", deleteFrame.StopMovingOrSizing)
        Skin:ApplyBackdrop(deleteFrame); deleteFrame:SetBackdropColor(unpack(Skin.Colors.bg)); Skin:SetSmartBorder(deleteFrame, 2, {r=1, g=0.3, b=0.3, a=1}, "OUTSIDE")
        Skin:CreateTitleBar(deleteFrame, "Delete Preset", function() deleteFrame:Hide() end)
        
        local ddDelete = Skin:CreateDropdown(deleteFrame, 310, customList, function(presetName)
            Skin:CreateConfirmDialog("Confirm Delete", "Delete preset '" .. presetName .. "'?", function()
                    WidgetForgeDB.presets[presetName] = nil
                    print("|cffff0000Deleted.|r")
                    ddPreset:SetList(GetPresetList()); ddPreset:SetValue(nil, "Select...")
                    deleteFrame:Hide()
            end)
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
                print("|cff00ff00Profile imported.|r")
                Config.DetailsContent:HideAllChildren()
            else print("|cffff0000Invalid profile!|r") end
        end)
    end)

    -- --- MAIN PANEL (Details) ---
    local mainPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    mainPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    mainPanel:SetPoint("BOTTOMRIGHT", -10, 50)
    Skin:ApplyBackdrop(mainPanel, 0.2, 0.5)

    local scrollDetails, contentDetails = Skin:CreateScrollFrame(mainPanel, 630, 510) 
    scrollDetails:SetPoint("TOPLEFT", 0, 0)
    scrollDetails:SetPoint("BOTTOMRIGHT", 0, 0)
    
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
    for i, bar in ipairs(WidgetForgeDB.bars) do
        -- Sadece bu karakter için "ilgili" olanları göster
        local showInList = WidgetForge:IsBarRelevant(bar) 

        if showInList then
            -- [NEW] Suffix Tags
            local suffix = ""
            if not bar.scope then suffix = " |cffcccccc[Global]|r"
            elseif bar.scope.type == "CHARACTER" then suffix = " |cff00ff00[Char]|r"
            elseif bar.scope.type == "SPEC" then suffix = " |cffffaa00[Spec]|r" end
            
            local btn = Skin:CreateButton(content, bar.name .. suffix, 155, 30)
            btn:SetPoint("TOP", 0, y) 
            
            if i == Config.SelectedBarIndex then
                 btn:SetBackdropColor(0, 0.7, 1, 0.4) 
                 btn:SetBackdropBorderColor(0, 0.8, 1, 1) 
                 btn:SetScript("OnEnter", nil); btn:SetScript("OnLeave", nil)
            end
            
            btn:SetScript("OnClick", function() Config:SelectBar(i) end)
            
            local btnDel = CreateFrame("Button", nil, btn)
            btnDel:SetSize(20, 20)
            btnDel:SetPoint("RIGHT", -5, 0)
            
            local icon = btnDel:CreateTexture(nil, "OVERLAY")
            icon:SetSize(18, 18) -- Match Accordion Size
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\close.tga")
            icon:SetVertexColor(1, 1, 1, 1) -- Match Accordion Color (1.0)
            
            btnDel:SetScript("OnEnter", function() icon:SetVertexColor(1, 0.2, 0.2, 1) end) -- Hover: Red
            btnDel:SetScript("OnLeave", function() icon:SetVertexColor(1, 1, 1, 1) end)
            
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
    
    -- [FIX] Update Content Height so ScrollFrame works
    content:SetHeight(math.max(1, math.abs(y)))
end

function Config:SelectBar(index)
    Config.isUpdatingScale = false -- Reset stuck flag
    Config.SelectedBarIndex = index
    
    if WidgetForge.SetSelectedBar then WidgetForge:SetSelectedBar(index) end
    Config:RefreshBarList() 
    
    function Config:UpdateCoordinates(index)
    -- Only update if the dragged bar is the currently selected one
    if Config.SelectedBarIndex ~= index then return end
    if not Config.Frame or not Config.Frame:IsShown() then return end
    
    local bar = WidgetForgeDB.bars[index]
    if not bar then return end

    Config.isUpdatingScale = true -- Suppress callbacks
    if Config.slX then
        Config.slX:SetValue(bar.x)
        Config.slX.editBox:SetText(tostring(math.floor(bar.x)))
    end
    
    if Config.slY then
        Config.slY:SetValue(bar.y)
        Config.slY.editBox:SetText(tostring(math.floor(bar.y)))
    end
    Config.isUpdatingScale = false
end
    local content = Config.DetailsContent
    if not content then return end 
    content:HideAllChildren()
    
    if not index then return end
    local bar = WidgetForgeDB.bars[index]
    if not bar then return end
    
    if not bar.elements then bar.elements = {} end
    
    -- [ISOLATION CHECK]
    local isExclusive = false
    local exclusiveType = nil
    for _, e in ipairs(bar.elements) do
        if e.type == "Dragonriding" or e.type == "Cursor Ring" or e.type == "Retirement Home" or e.type == "Mythic+ Dashboard" then 
            isExclusive = true
            exclusiveType = e.type
            break 
        end
    end
    
    local y = -10
    
    -- --- SECTION 1: BAR LAYOUT ---
    local hLayout
    if not isExclusive then
        hLayout = Skin:CreateSectionHeader(content, "Bar Layout: " .. bar.name, 600)
    else
        hLayout = Skin:CreateSectionHeader(content, "Bar: " .. bar.name .. " LAYOUT LOCKED", 600)
        if hLayout.text then hLayout.text:SetTextColor(1, 0.3, 0.3, 1) end
    end
    hLayout:SetPoint("TOPLEFT", 10, y)
    
    -- 1. ENABLE / DISABLE TOGGLE BUTTON (En Sağa Yaslı)
    local btnEnable = Skin:CreateButton(content, "ENABLED", 80, 25)
    btnEnable:SetPoint("TOPRIGHT", hLayout, "TOPRIGHT", -2, 2) 
    
    local function UpdateEnableButton()
        if bar.enabled then
            btnEnable:SetBackdropColor(0.5, 0.8, 0.5, 1)
            btnEnable:SetBackdropBorderColor(0, 1, 0, 1)
            btnEnable.text:SetText("ENABLED")
            btnEnable.text:SetTextColor(1, 1, 1, 1)
            btnEnable:SetScript("OnEnter", function() btnEnable:SetBackdropColor(0.65, 1.0, 0.65, 1) end)
            btnEnable:SetScript("OnLeave", function() btnEnable:SetBackdropColor(0.5, 0.8, 0.5, 1) end)
        else
            btnEnable:SetBackdropColor(0.7, 0, 0, 1)
            btnEnable:SetBackdropBorderColor(1, 0, 0, 1)
            btnEnable.text:SetText("DISABLED")
            btnEnable.text:SetTextColor(1, 1, 1, 1)
            btnEnable:SetScript("OnEnter", function() btnEnable:SetBackdropColor(0.9, 0, 0, 1) end)
            btnEnable:SetScript("OnLeave", function() btnEnable:SetBackdropColor(0.7, 0, 0, 1) end)
        end
    end
    UpdateEnableButton() 
    
    btnEnable:SetScript("OnClick", function()
        bar.enabled = not bar.enabled 
        UpdateEnableButton()
        WidgetForge:UpdateAvailableBars() 
    end)
    
    local scopeList = {
        {text = "Global (Account)", value = "GLOBAL"},
        {text = "This Character", value = "CHARACTER"},
        {text = "Current Spec", value = "SPEC"}
    }
    local currentScopeVal = "GLOBAL"
    if bar.scope then currentScopeVal = bar.scope.type end
    
    -- 2. SCOPE DROPDOWN (Düğmenin Solunda)
    local ddScope = Skin:CreateDropdown(content, 150, scopeList, currentScopeVal, function(v)
        if v == "GLOBAL" then
            bar.scope = nil
        elseif v == "CHARACTER" then
            bar.scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }
        elseif v == "SPEC" then
            local spec = GetSpecialization()
            if spec then
                 bar.scope = { type = "SPEC", value = GetSpecializationInfo(spec), character = UnitName("player") .. "-" .. GetRealmName() }
            else print("Error: No Spec active."); return end
        end
        WidgetForge:UpdateAvailableBars()
        Config:RefreshBarList() 
    end)
    ddScope:SetPoint("RIGHT", btnEnable, "LEFT", -5, 0)
    
    y = y - 40

    -- Row 1: Name, Title, Vertical
    local lblName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblName:SetPoint("TOPLEFT", 10, y - 8); lblName:SetText("Bar Name:"); lblName:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local ebNameFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ebNameFrame:SetSize(150, 25); ebNameFrame:SetPoint("TOPLEFT", 90, y)
    Skin:ApplyBackdrop(ebNameFrame); ebNameFrame:SetBackdropColor(0,0,0,0.5); ebNameFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local ebName = CreateFrame("EditBox", nil, ebNameFrame)
    ebName:SetAllPoints(ebNameFrame); ebName:SetFont(Skin.Constants.FONT_NORMAL, 12, "OUTLINE")
    ebName:SetTextInsets(5, 5, 0, 0); ebName:SetAutoFocus(false); ebName:SetText(bar.name)
    ebName:SetMaxLetters(30) 
    ebName:SetScript("OnEnterPressed", function(self) 
        bar.name = self:GetText(); if hLayout.text then hLayout.text:SetText(string.upper("Bar Layout: " .. bar.name)) end
        Config:RefreshBarList(); self:ClearFocus() 
    end)
    ebName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    if not isExclusive then
        local chkTitle = Skin:CreateCheckbox(content, "Show Title Bar", bar.showTitle, function(v) bar.showTitle = v; WidgetForge:RebuildBarComponents(index) end)
        chkTitle:SetPoint("TOPLEFT", 260, y - 3)

        local chkLayout = Skin:CreateCheckbox(content, "Vertical Layout", bar.layout == "VERTICAL", function(v) bar.layout = v and "VERTICAL" or "HORIZONTAL"; Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
        chkLayout:SetPoint("TOPLEFT", 430, y - 3)
        y = y - 40

        -- Row 2: Alignment, Spacing, BG
        -- Row 2: Alignment, Spacing
        local lblJ = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblJ:SetPoint("TOPLEFT", 10, y - 8); lblJ:SetText("Alignment:"); lblJ:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        local ddJustify = Skin:CreateDropdown(content, 150, { "LEFT", "CENTER", "RIGHT" }, bar.justify or "CENTER", function(v) bar.justify = v; WidgetForge:RebuildBarComponents(index) end)
        ddJustify:SetPoint("TOPLEFT", 90, y)

        -- Spacing Slider (Aligned with Y slider at 260)
        local slPad = Skin:CreateSlider(content, -10, 50, 1, bar.padding or 5, function(v) bar.padding = v; WidgetForge:UpdateAvailableBars() end, 150)
        slPad:SetPoint("TOPLEFT", 260, y)
        local lblPad = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblPad:SetPoint("LEFT", slPad, "RIGHT", 5, 0); lblPad:SetText("Spacing"); lblPad:SetFont(Skin.Constants.FONT_NORMAL, 11, "")

        y = y - 40

    else
        y = y - 40 
    end

    -- Row 3: Position (Manual X/Y) - Hidden for Cursor Ring AND Retirement Home
    if exclusiveType ~= "Cursor Ring" and exclusiveType ~= "Retirement Home" then
        local lblPos = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblPos:SetPoint("TOPLEFT", 10, y - 8); lblPos:SetText("Position:"); lblPos:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        
        local slX = Skin:CreateSlider(content, -math.floor(GetScreenWidth()/2), math.floor(GetScreenWidth()/2), 1, bar.x or 0, function(v) 
            if Config.isUpdatingScale then return end
            bar.x = v; 
            WidgetForge:UpdateAvailableBars() 
        end, 150)
        slX:SetPoint("TOPLEFT", 90, y)
        local slXLabel = slX.track:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slXLabel:SetPoint("TOP", slX.track, "BOTTOM", 0, -12); slXLabel:SetText("X")
        Config.slX = slX
        
        local slY = Skin:CreateSlider(content, -math.floor(GetScreenHeight()/2), math.floor(GetScreenHeight()/2), 1, bar.y or 0, function(v) 
            if Config.isUpdatingScale then return end
            bar.y = v; 
            WidgetForge:UpdateAvailableBars() 
        end, 150)
        slY:SetPoint("TOPLEFT", 260, y)
        local slYLabel = slY.track:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        slYLabel:SetPoint("TOP", slY.track, "BOTTOM", 0, -12); slYLabel:SetText("Y")
        Config.slY = slY


    end

    -- Reduce gap for Cursor Ring (most controls hidden)
    if exclusiveType == "Cursor Ring" or exclusiveType == "Retirement Home" then
        y = y - 10
    else
        y = y - 50
    end

    -- --- SECTION 2: BACKGROUND BAR SETTINGS ---
    if not isExclusive then
        local hSize = Skin:CreateSectionHeader(content, "Background Bar Settings", 600); hSize:SetPoint("TOPLEFT", 10, y); y = y - 40
        -- Row 1: Width | Height 
        local lblW = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblW:SetPoint("TOPLEFT", 10, y - 8); lblW:SetText("Width:"); lblW:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        local slW = Skin:CreateSlider(content, 50, 600, 5, bar.width, function(v) bar.width = v; WidgetForge:UpdateAvailableBars() end, 150); slW:SetPoint("TOPLEFT", 90, y)
        
        local slH = Skin:CreateSlider(content, 10, 200, 2, bar.height, function(v) bar.height = v; WidgetForge:UpdateAvailableBars() end, 150); slH:SetPoint("TOPLEFT", 260, y)
        local lblH = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblH:SetPoint("LEFT", slH, "RIGHT", 5, 0); lblH:SetText("Height"); lblH:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        
        y = y - 40

        -- Row 2: Bg Color

        -- [NEW] Bg Color (Moved Here - Next Row)
        local lblBg = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblBg:SetPoint("TOPLEFT", 10, y - 8); lblBg:SetText("Bg Color:"); lblBg:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        local btnBg = CreateFrame("Button", nil, content, "BackdropTemplate")
        btnBg:SetSize(20, 20); btnBg:SetPoint("TOPLEFT", 90, y - 3 ) 
        Skin:ApplyBackdrop(btnBg); local bg = bar.bgColor or {0, 0, 0, 0.5}; btnBg:SetBackdropColor(unpack(bg))
        
        btnBg:SetScript("OnClick", function()
            local oldColor = {bg[1], bg[2], bg[3], bg[4]} 
            local info = { 
                r=bg[1], g=bg[2], b=bg[3], opacity=bg[4], 
                swatchFunc = function(c) 
                    bar.bgColor = c; 
                    btnBg:SetBackdropColor(unpack(c)); 
                    WidgetForge:UpdateAvailableBars() 
                end,
                cancelFunc = function()
                    bar.bgColor = oldColor 
                    btnBg:SetBackdropColor(unpack(oldColor))
                    WidgetForge:UpdateAvailableBars()
                end
            }
            Skin:ShowColorPicker(info)
        end)

        -- [Moved Here] Click Through
        local chkClick = Skin:CreateCheckbox(content, "Click Through (Non-Interactive)", bar.clickThrough, function(v) 
            bar.clickThrough = v
            WidgetForge:SetBarsLocked(false) 
            C_Timer.After(0.05, function() Config:SelectBar(index) end)
        end)
        chkClick:SetPoint("TOPLEFT", 260, y - 3) -- Next column at 260

        y = y - 40
    end

    -- --- SECTION 3: BORDER SETTINGS ---
    -- [FIX] Hide Global Border Settings if Exclusive Widget is present
    -- Check is already done via isExclusive
    if not isExclusive then
        local hBorder = Skin:CreateSectionHeader(content, "Border Settings", 600); hBorder:SetPoint("TOPLEFT", 10, y); y = y - 40
        local lblBS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblBS:SetPoint("TOPLEFT", 10, y - 8); lblBS:SetText("Border Size:"); lblBS:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        local slBS = Skin:CreateSlider(content, 1, 10, 1, bar.borderSize or 1, function(v) bar.borderSize = v; WidgetForge:UpdateAvailableBars() end, 150); slBS:SetPoint("TOPLEFT", 90, y)
        local lblBC = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblBC:SetPoint("TOPLEFT", 260, y - 8); lblBC:SetText("Border Color:"); lblBC:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
        local btnBC = CreateFrame("Button", nil, content, "BackdropTemplate"); btnBC:SetSize(20, 20); btnBC:SetPoint("TOPLEFT", 340, y - 3); Skin:ApplyBackdrop(btnBC); local bc = bar.borderColor or {0.2, 0.2, 0.2, 1}; btnBC:SetBackdropColor(unpack(bc))
        
        btnBC:SetScript("OnClick", function() 
            local oldColor = {bc[1], bc[2], bc[3], bc[4]} 
            local info = { 
                r=bc[1], g=bc[2], b=bc[3], opacity=bc[4], 
                swatchFunc = function(c) 
                    bar.borderColor = c; 
                    btnBC:SetBackdropColor(unpack(c)); 
                    WidgetForge:UpdateAvailableBars() 
                end,
                cancelFunc = function()
                    bar.borderColor = oldColor 
                    btnBC:SetBackdropColor(unpack(oldColor))
                    WidgetForge:UpdateAvailableBars()
                end
            }; 
            Skin:ShowColorPicker(info) 
        end)

        local chkBorder = Skin:CreateCheckbox(content, "Show", bar.showBorder, function(v) bar.showBorder = v; WidgetForge:UpdateAvailableBars() end); chkBorder:SetPoint("TOPLEFT", 430, y - 3)
        y = y - 40
    end

    -- --- ELEMENTS ---
    local headEl = Skin:CreateSectionHeader(content, "Bar Elements", 600); headEl:SetPoint("TOPLEFT", 10, y); y = y - 40
    
    -- [ISOLATION CHECK]
    local barMode = "EMPTY" -- EMPTY, STANDARD, OVERLAY, STRICT
    local OverlayTypes = { ["Cursor Ring"] = true, ["Retirement Home"] = true } -- Removed Mythic+ Dashboard from OverlayTypes
    
    if bar.elements and #bar.elements > 0 then
        barMode = "STANDARD" -- Default
        for _, e in ipairs(bar.elements) do
            if e.type == "Dragonriding" or e.type == "Mythic+ Dashboard" then 
                barMode = "STRICT"
                break 
            elseif OverlayTypes[e.type] then
                barMode = "OVERLAY"
                -- Don't break yet, ensure no mixed states (though blocked by logic)
            end
        end
        -- Safety: If mixed Standard + Overlay found (shouldn't happen), Standard takes precedence logic? 
        -- Actually we enforce isolation on add, so this check is just detection.
    end
    
    -- [CATEGORIES DATA]
    local categories = {
        { name = "System & Performance", elements = { "FPS", "MS", "Clock" } },
        { name = "Player Stats", elements = { "Main Stat", "Stamina", "Crit", "Haste", "Mastery", "Versatility", "Avoidance", "Leech", "Speed", "Run Speed", "Dodge", "Parry", "Armor", "Max HP" } },
        { name = "Progression & Goods", elements = { "XP", "Gold", "Bag Space", "Item Level", "Durability" } },
        { name = "Navigation", elements = { "Zone", "Coords" } },
        { name = "Dungeon & Raid", elements = { "Mythic+ Dashboard" } },
        { name = "Utils", elements = { "Dragonriding", "Cursor Ring", "Combat Timer", "Retirement Home", "Dummy" } }
    }
    
    -- [ACCORDION RENDERING & FILTER LOGIC]
    Config.AccordionStates = Config.AccordionStates or {} 
    
    local accFrameList = {}
    local activeElementsFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    activeElementsFrame:SetWidth(600)
    activeElementsFrame:SetHeight(1) 
    
    -- Separator Line (Standardized via ForgeSkin)
    local listSeparator = Skin:CreateSeparator(content, 600) 

    -- Capture starting Y to prevent closure issues if 'y' is modified later in SelectBar
    local accordionStartY = y 
    
    local function UpdateAccordionLayout()
        local currentY = accordionStartY
        for _, acc in ipairs(accFrameList) do
            if acc:IsShown() then
                acc:SetPoint("TOPLEFT", 10, currentY)
                currentY = currentY - acc:GetHeight() - 5
            end
        end
        
        -- Position Separator (Start and End match standard widths)
        local sepY = currentY - 10
        listSeparator:ClearAllPoints()
        listSeparator:SetPoint("TOPLEFT", 10, sepY)
        
        -- Move Active Elements List below separator
        activeElementsFrame:SetPoint("TOPLEFT", 0, currentY - 25)
        
        local totalH = math.abs(accordionStartY) + math.abs(currentY - accordionStartY) + activeElementsFrame:GetHeight() + 100
        content:SetHeight(totalH) 
    end

    -- [FILTER DROPDOWN] (Multi-Select)
    -- Initialize selection state if missing
    if not Config.SelectedElementCategories then
        Config.SelectedElementCategories = { ["ALL"] = true }
        for _, c in ipairs(categories) do Config.SelectedElementCategories[c.name] = true end
    end
    
    local filterList = { {text="Show All", value="ALL"} }
    for _, c in ipairs(categories) do table.insert(filterList, {text=c.name, value=c.name}) end
    
    local ddFilter = Skin:CreateMultiDropdown(content, 180, filterList, Config.SelectedElementCategories, function(val, newState)
        -- Update Accordion Visibility In-Place
        for _, acc in ipairs(accFrameList) do
            local isVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[acc.catName]
            acc:SetShown(isVisible)
        end
        UpdateAccordionLayout()
    end)
    
    -- Align Dropdown
    ddFilter:SetPoint("TOPRIGHT", headEl, "TOPLEFT", 600, 5) 

    for _, cat in ipairs(categories) do
        -- Create ALL accordions, assume hidden initially then set state based on filter

        -- Prepend Divider via new table to avoid mutating original 'categories'
        local displayElements = { "Divider" }
        for _, e in ipairs(cat.elements) do table.insert(displayElements, e) end
        
        -- Calculate rows (5 per row)
        local numRows = math.ceil(#displayElements / 5)
        local contentH = numRows * 30 + 10 
        
        local acc = Skin:CreateAccordion(content, cat.name, contentH, function(expanded) 
            Config.AccordionStates[cat.name] = expanded
            UpdateAccordionLayout() 
        end)
        acc.catName = cat.name  -- Store for filtering
        table.insert(accFrameList, acc)
        
        -- Initial State
        local isInitialVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[cat.name]
        acc:SetShown(isInitialVisible)
        
        if Config.AccordionStates[cat.name] then acc:SetExpanded(true) end

        -- Create Buttons
        local btnX, btnY = 5, -5
        for i, typeName in ipairs(displayElements) do
            local isDragonBtn = (typeName == "Dragonriding")
            local isDivider = (typeName == "Divider")
            
            -- Check if active
            local isActive = false
            for _, e in ipairs(bar.elements) do 
                if e.type == typeName then isActive = true; break end 
            end
            
            local btn = Skin:CreateButton(acc.content, typeName, 110, 25) -- Reduced width slightly
            btn:SetPoint("TOPLEFT", btnX, btnY)
            
            -- Styling Helper
            local function UpdateButtonStyle()
                if isDivider then
                    btn:SetBackdropColor(1, 0.8, 0, 1)
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn:SetBackdropBorderColor(0, 0, 0, 1)
                elseif isDragonBtn then
                    if isActive then
                       btn:SetBackdropColor(0, 0.7, 0.7, 1); btn:SetBackdropBorderColor(0, 1, 1, 1)
                    else
                       btn:SetBackdropColor(unpack(Skin.Colors.button)); btn:SetBackdropBorderColor(unpack(Skin.Colors.border))
                    end
                    btn.text:SetTextColor(1, 1, 1, 1)
                elseif isActive then
                    btn:SetBackdropColor(0, 0.7, 1, 0.8) -- Active Blue
                    btn:SetBackdropBorderColor(0, 0.8, 1, 1)
                    btn.text:SetTextColor(1, 1, 1, 1)
                else
                    btn:SetBackdropColor(unpack(Skin.Colors.button)) -- Default Dark
                    btn:SetBackdropBorderColor(unpack(Skin.Colors.border)) -- Default Border
                    btn.text:SetTextColor(1, 1, 1, 1)
                end
            end
            UpdateButtonStyle()
            
            -- Hover Effects
            btn:SetScript("OnEnter", function(self)
                if not self:IsEnabled() then return end
                
                if isDivider then
                    self:SetBackdropColor(1, 0.9, 0.2, 1)
                elseif isDragonBtn then
                    if isActive then self:SetBackdropColor(0, 0.8, 0.8, 1)
                    else 
                        self:SetBackdropColor(unpack(Skin.Colors.buttonHover))
                        self:SetBackdropBorderColor(unpack(Skin.Colors.accent)) -- Blue Border on Hover
                    end
                elseif isActive then
                    self:SetBackdropColor(0.2, 0.8, 1, 0.9)
                else
                    -- Standard Button Hover: Darker BG + Blue Border
                    self:SetBackdropColor(unpack(Skin.Colors.buttonHover))
                    self:SetBackdropBorderColor(unpack(Skin.Colors.accent)) 
                end
            end)
            
            btn:SetScript("OnLeave", function(self)
                UpdateButtonStyle()
            end)
            
            -- Isolation Logic
            local canAdd = true
            local btnIsStrict = (typeName == "Dragonriding" or typeName == "Mythic+ Dashboard")
            local btnIsOverlay = OverlayTypes[typeName]
            local btnIsDivider = (typeName == "Divider")
            
            if barMode == "STRICT" then
                 if typeName ~= exclusiveType then canAdd = false end
            elseif barMode == "OVERLAY" then
                 -- Allow other overlays, Block Standard/Strict/Divider
                 if not btnIsOverlay then canAdd = false end
            elseif barMode == "STANDARD" then
                 -- Block Strict/Overlay
                 if btnIsStrict or btnIsOverlay then canAdd = false end
            end
            
            if not canAdd then
                btn:SetEnabled(false)
                btn:SetAlpha(0.5)
            else
                btn:SetEnabled(true)
                btn:SetAlpha(1)
            end
            
            btn:SetScript("OnClick", function()
                if not canAdd then return end
                
                -- Toggle Logic
                if isActive then
                    -- Remove
                    for idx, el in ipairs(bar.elements) do
                        if el.type == typeName then
                             table.remove(bar.elements, idx)
                             break
                        end
                    end
                else
                    -- Add
                    local newEl = { type = typeName, size = 14, color = {1, 1, 1, 1}, showIcon = true }
                    if isDragonBtn then
                         newEl.widgetWidth = 300; newEl.widgetHeight = 45
                         newEl.vigorFillColor = {0, 0.85, 0.85, 1}
                         newEl.speedBarColor = {0.7, 0, 0.7, 1}
                         newEl.speedTextColor = {1, 1, 1, 1}
                    elseif btnIsOverlay then
                         newEl.size = 32 -- Default for overlay
                         if typeName == "Mythic+ Dashboard" then
                             newEl.widgetWidth = 350
                             newEl.widgetHeight = 150
                         end
                    elseif btnIsDivider then
                         newEl.size = 20; newEl.thickness = 2; newEl.dividerMode = "LINE"; newEl.dividerStyle = "VERTICAL"; newEl.offset = 0
                    end
                    
                    table.insert(bar.elements, newEl)
                end
                
                -- Refresh UI
                Config:SelectBar(index)
                WidgetForge:UpdateAvailableBars()
                Config:SelectBar(index) 
            end)
            
            btnX = btnX + 115 -- 110 + 5 pad
            if i % 5 == 0 then
                btnX = 5
                btnY = btnY - 30
            end
        end
    end
    
    activeElementsFrame:SetHeight(math.max(1, #bar.elements * 35 + 10))
    UpdateAccordionLayout() -- Initial Layout Call with correct height
    
    local fontList = {}; for k, v in pairs(Skin.Media.Fonts) do table.insert(fontList, {text=k, value=k, font=v}) end
    local outlineList = { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick", value="THICKOUTLINE"}, {text="Mono", value="MONOCHROME"}, {text="Mono+Out", value="MONOCHROME,OUTLINE"} }

    Config.ElementRows = {}
    for i, elem in ipairs(bar.elements) do
        local item = CreateFrame("Frame", nil, activeElementsFrame, "BackdropTemplate")
        item:SetSize(600, 32); item:SetPoint("TOPLEFT", 10, -((i-1) * 35))
        Skin:ApplyBackdrop(item, 0.3, 0.5)
        item.txt = item:CreateFontString(nil, "OVERLAY", "GameFontNormal"); item.txt:SetPoint("LEFT", 8, 0); item.txt:SetText(i..". "..elem.type); item.txt:SetFont(Skin.Constants.FONT_NORMAL, 11, "OUTLINE"); item.txt:SetWidth(110); item.txt:SetJustifyH("LEFT")

        local btnRem = CreateFrame("Button", nil, item)
        btnRem:SetSize(20, 20); btnRem:SetPoint("RIGHT", -10, 0)
        
        local icon = btnRem:CreateTexture(nil, "OVERLAY")
        icon:SetSize(18, 18); icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\close.tga")
        icon:SetVertexColor(1, 1, 1, 1)
        
        btnRem:SetScript("OnEnter", function() icon:SetVertexColor(1, 0.2, 0.2, 1) end)
        btnRem:SetScript("OnLeave", function() icon:SetVertexColor(1, 1, 1, 1) end)
        
        btnRem:SetScript("OnClick", function() table.remove(bar.elements, i); Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
        
        local dragHandle = Skin:CreateGripHandle(item, 20, 20); dragHandle:SetPoint("RIGHT", btnRem, "LEFT", -4, 0); dragHandle:EnableMouse(true); dragHandle:RegisterForDrag("LeftButton")
        Config.ElementRows[i] = item; item.rowIndex = i
        
        dragHandle:SetScript("OnDragStart", function() 
            dragHandle.dragSourceIndex = i
            for _, line in ipairs(dragHandle.lines) do line:SetVertexColor(0, 1, 0, 1) end
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
            if Config.DragGhost then Config.DragGhost:Hide() end
            
            -- Reset Colors
            for _, line in ipairs(dragHandle.lines) do line:SetVertexColor(unpack(Skin.Colors.accent)) end
            for idx = 1, #Config.ElementRows do
                local row = Config.ElementRows[idx]
                if row then row:SetBackdropBorderColor(unpack(Skin.Colors.border)) end
            end

            if not dragHandle.dragSourceIndex then return end
            
            local sourceIdx = dragHandle.dragSourceIndex
            dragHandle.dragSourceIndex = nil
            
            -- Find target
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
            
            if closestIdx ~= sourceIdx then 
                bar.elements[sourceIdx], bar.elements[closestIdx] = bar.elements[closestIdx], bar.elements[sourceIdx]
                Config:SelectBar(index)
                WidgetForge:RebuildBarComponents(index) 
            end 
        end)
        
        dragHandle:SetScript("OnUpdate", function()
            if dragHandle.dragSourceIndex and Config.DragGhost then
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                Config.DragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/scale, y/scale)
                
                local _, mouseY = GetCursorPosition()
                local minDist = 999999
                local closestRow = nil
                
                -- Clear borders
                for idx = 1, #Config.ElementRows do
                    local row = Config.ElementRows[idx]
                    if row then row:SetBackdropBorderColor(unpack(Skin.Colors.border)) end
                end
                
                -- Find and highlight
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
                                    closestRow = row
                                end
                            end
                        end
                    end
                end
                
                if closestRow then
                    closestRow:SetBackdropBorderColor(1, 0.8, 0, 1) -- Highlight Color
                end
            end
        end)
        
        local btnCol = CreateFrame("Button", nil, item, "BackdropTemplate"); btnCol:SetSize(20, 20); btnCol:SetPoint("RIGHT", dragHandle, "LEFT", -8, 0); Skin:ApplyBackdrop(btnCol); btnCol:SetBackdropColor(unpack(elem.color or {1, 1, 1, 1}))
        btnCol:SetScript("OnClick", function() local oldColor = elem.color or {1, 1, 1, 1}; local info = { r=oldColor[1], g=oldColor[2], b=oldColor[3], opacity=oldColor[4], swatchFunc = function(c) elem.color = c; btnCol:SetBackdropColor(unpack(c)); WidgetForge:RebuildBarComponents(index) end, cancelFunc = function() elem.color = oldColor; btnCol:SetBackdropColor(unpack(oldColor)); WidgetForge:RebuildBarComponents(index) end }; Skin:ShowColorPicker(info) end)
        
        if elem.type == "Divider" then
             -- Hide Color Button in main row (moved to settings) 
             -- Actually, user asked to move everything to settings. 
             -- But keeping Color here is standard.  User said "Settings diye bi dugme etkle oraya renk ve vertical horziantel ayarı dahil herseyii diverde aryar kısmıan tası"
             -- So I will HIDE the color button here and move it inside Settings.
             btnCol:Hide()

             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             -- Place 'Settings' button where controls usually go
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenElementSettings(index, i, elem) end)
        elseif elem.type == "Dragonriding" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenDragonridingSettings(index, i, elem) end)
        elseif elem.type == "Cursor Ring" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCursorRingSettings(index, i, elem) end)
        elseif elem.type == "Retirement Home" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenRetirementHomeSettings(index, i, elem) end)

        elseif elem.type == "Mythic+ Dashboard" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() 
                print("DEBUG: Clicked M+ Settings Button")
                print("DEBUG: Config.OpenMythicPlusSettings exists:", Config.OpenMythicPlusSettings ~= nil)
                if Config.OpenMythicPlusSettings then Config:OpenMythicPlusSettings(index, i, elem) end 
             end)
        elseif elem.type == "Dummy" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenDummySettings(index, i, elem) end)
        else
            -- STANDARD CONTROLS
            -- Color Button is visible (already created above)
            
            local slSz = Skin:CreateSlider(item, 8, 50, 1, elem.size, function(v) elem.size = v; WidgetForge:RebuildBarComponents(index) end, 70); slSz:SetPoint("RIGHT", btnCol, "LEFT", -15, 0)
            local ddOutline = Skin:CreateDropdown(item, 85, outlineList, elem.outline or "OUTLINE", function(v) elem.outline = v; WidgetForge:RebuildBarComponents(index) end); ddOutline:SetPoint("RIGHT", slSz, "LEFT", -10, 0) 
            local ddFont = Skin:CreateDropdown(item, 100, fontList, elem.font or "Standard", function(v) elem.font = v; WidgetForge:RebuildBarComponents(index) end); ddFont:SetPoint("RIGHT", ddOutline, "LEFT", -10, 0)
            local chkIcon = Skin:CreateCheckbox(item, "Icon", elem.showIcon, function(v) elem.showIcon = v; WidgetForge:RebuildBarComponents(index) end); chkIcon:SetWidth(45); chkIcon:SetPoint("RIGHT", ddFont, "LEFT", -5, 0); chkIcon.box:SetSize(14, 14); chkIcon.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE")
            local chkTip = Skin:CreateCheckbox(item, "Tip", elem.showTooltip, function(v) elem.showTooltip = v; WidgetForge:RebuildBarComponents(index) end); chkTip:SetWidth(40); chkTip:SetPoint("RIGHT", chkIcon, "LEFT", -5, 0); chkTip.box:SetSize(14, 14); chkTip.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE") 
            
            -- [DISABLE TIP IF CLICKTHROUGH]
            if bar.clickThrough then
                chkTip:SetAlpha(0.5)
                chkTip.box:EnableMouse(false)
                chkTip.label:SetTextColor(0.5, 0.5, 0.5)
            end
            
            if elem.type == "Clock" then local fmtList = { {text="24h", value="24h"}, {text="12h", value="12h"} }; local ddFmt = Skin:CreateDropdown(item, 50, fmtList, elem.timeFormat or "24h", function(v) elem.timeFormat = v; WidgetForge:RebuildBarComponents(index) end); ddFmt:SetPoint("RIGHT", chkTip, "LEFT", -5, 0) end
        end
        y = y - 36 
    end
    content:SetHeight(math.abs(y) + 20)
end



function Config:OpenElementSettings(barIndex, elemIndex, elem)
    local f = Config.ElementSettingsFrame
    if not f then
        f = CreateFrame("Frame", "ForgeElementSettings", UIParent, "BackdropTemplate")
        f:SetSize(250, 310) -- Reduced Width to 250, Height to 310 or keep 290? user said 20px smaller previously.
        -- User said "ui alt kısmı uzun 20 px ufalt" (bottom part is long, shorten 20px). I did that to 290. 
        -- Now user says "ayarlar kısmında solda olan bosşuk kadar sagda bosluk kalsın" (let right whitespace = left whitespace).
        -- So narrowing the frame makes sense.
        f:SetSize(250, 290)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG") -- Set to DIALOG. High enough to be above Main Menu, and ColorPicker should handle itself (usually popups are smart).
        f:EnableMouse(true); f:SetMovable(true)
        Skin:ApplyBackdrop(f); f:SetBackdropColor(0.1, 0.1, 0.1, 0.95); Skin:SetSmartBorder(f, 2, {r=1, g=0.7, b=0, a=1}, "OUTSIDE")
        
        -- Title Bar (Draggable)
        local title = Skin:CreateTitleBar(f, "Divider Settings", function() f:Hide() end)
        title:RegisterForDrag("LeftButton")
        title:SetScript("OnDragStart", function() f:StartMoving() end)
        title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    
        Config.ElementSettingsFrame = f
    else
        f:Show()
    end

    -- Use a dedicated content frame to easily clear children
    if not f.content then 
        f.content = CreateFrame("Frame", nil, f)
        f.content:SetAllPoints(f)
    else
        -- Clear existing children AND regions to rebuild UI
        local kids = { f.content:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        
        -- Fix for overlapping text labels (FontStrings are Regions, not Children)
        local regions = { f.content:GetRegions() }
        for _, rgn in ipairs(regions) do rgn:Hide() end
    end
    
    local y = -50 
    local content = f.content

    -- 1. Mode Select
    local lblMode = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblMode:SetPoint("TOPLEFT", 20, y-5); lblMode:SetText("Mode:")
    local modeList = { {text="Graphic Line", value="LINE"}, {text="Text Character", value="TEXT"} }
    local ddMode = Skin:CreateDropdown(content, 120, modeList, elem.dividerMode or "LINE", function(v) 
        elem.dividerMode = v; 
        WidgetForge:RebuildBarComponents(barIndex)
        Config:OpenElementSettings(barIndex, elemIndex, elem) 
    end)
    ddMode:SetPoint("TOPLEFT", 100, y)
    
    -- Removed Color Picker from here
    
    y = y - 40

    -- 2. Style (Vertical/Horizontal) & Color
    local lblStyle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblStyle:SetPoint("TOPLEFT", 20, y-5); lblStyle:SetText("Style:")
    local styleList = { {text="Vertical", value="VERTICAL"}, {text="Horizontal", value="HORIZONTAL"} }
    
    -- Shorten Style Dropdown for Color Picker
    local ddStyle = Skin:CreateDropdown(content, 85, styleList, elem.dividerStyle or "VERTICAL", function(v) 
        elem.dividerStyle = v 
        WidgetForge:RebuildBarComponents(barIndex)
    end)
    ddStyle:SetPoint("TOPLEFT", 100, y)

    -- Disable Style Dropdown if Mode is TEXT
    if elem.dividerMode == "TEXT" then
        ddStyle:SetAlpha(0.5)
        ddStyle:EnableMouse(false) -- Fixed: ddStyle is the button itself
        lblStyle:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Color Picker Button (Moved here, right of Style)
    local btnCol = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnCol:SetSize(30, 20); btnCol:SetPoint("LEFT", ddStyle, "RIGHT", 10, 0)
    Skin:ApplyBackdrop(btnCol); btnCol:SetBackdropColor(unpack(elem.color or {1, 1, 1, 1}))
    btnCol:SetScript("OnClick", function() 
        local oldColor = elem.color or {1, 1, 1, 1}
        local info = { 
            r=oldColor[1], g=oldColor[2], b=oldColor[3], opacity=oldColor[4], 
            swatchFunc = function(c) elem.color = c; btnCol:SetBackdropColor(unpack(c)); WidgetForge:RebuildBarComponents(barIndex) end, 
            cancelFunc = function() elem.color = oldColor; btnCol:SetBackdropColor(unpack(oldColor)); WidgetForge:RebuildBarComponents(barIndex) end 
        }
        Skin:ShowColorPicker(info) 
    end)
    btnCol:SetFrameStrata("FULLSCREEN_DIALOG") -- Ensure it's on top if needed, though parent is dialog.
    btnCol:SetFrameLevel(ddStyle:GetFrameLevel() + 5) -- Boost level just in case

    y = y - 40

    if elem.dividerMode == "TEXT" then
        -- Character Input
        local lblTxt = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblTxt:SetPoint("TOPLEFT", 20, y-5); lblTxt:SetText("Text:")
        local ebFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        ebFrame:SetSize(120, 25); ebFrame:SetPoint("TOPLEFT", 100, y)
        Skin:ApplyBackdrop(ebFrame); ebFrame:SetBackdropColor(0,0,0,0.5)
        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetAllPoints(ebFrame); eb:SetFont(Skin.Constants.FONT_NORMAL, 12, ""); eb:SetTextInsets(5,5,0,0); eb:SetAutoFocus(false)
        eb:SetText(elem.dividerText or "|")
        eb:SetScript("OnTextChanged", function(self) elem.dividerText = self:GetText(); WidgetForge:RebuildBarComponents(barIndex) end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        y = y - 40
        
        -- Size
        local lblSz = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblSz:SetPoint("TOPLEFT", 20, y-5); lblSz:SetText("Size:")
        local slSz = Skin:CreateSlider(content, 8, 72, 1, elem.size or 12, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slSz:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    else
        -- Line Settings
        local lblLen = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblLen:SetPoint("TOPLEFT", 20, y-5); lblLen:SetText("Length:")
        local slLen = Skin:CreateSlider(content, 5, 200, 1, elem.size or 20, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slLen:SetPoint("TOPLEFT", 100, y)
        y = y - 40

        local lblThk = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblThk:SetPoint("TOPLEFT", 20, y-5); lblThk:SetText("Thickness:")
        local slThk = Skin:CreateSlider(content, 1, 20, 1, elem.thickness or 2, function(v) elem.thickness = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slThk:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    end

     -- OFFSET (Common)
    local lblOff = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblOff:SetPoint("TOPLEFT", 20, y-5); lblOff:SetText("Offset:")
    local slOff = Skin:CreateSlider(content, -50, 50, 1, elem.offset or 0, function(v) elem.offset = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
    slOff:SetPoint("TOPLEFT", 100, y)
    y = y - 40
    
    local txtHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtHelp:SetPoint("TOP", 0, y - 5)
    txtHelp:SetText("Use Offset to nudge the Divider pos.")
    
    f:Show()
end

-- =========================================================================
--  DRAGONRIDING SETTINGS POPUP
-- =========================================================================
-- Old Dragonriding Settings Popup Removed (Migrated to Slide-In Panel)



-- =========================================================================
--  SLIDE-IN SETTINGS PANEL ARCHITECTURE
-- =========================================================================
function Config:GetSlidePanel()
    if Config.SlidePanel then return Config.SlidePanel end
    
    local Skin = _G.ForgeSkin
    local parent = Config.Frame
    local panel = Skin:CreateSlidePanel(parent, 640, 550, {x = -9, y = -40})
    
    -- Assign Application-Level Handler
    panel.onCloseHandler = function(self)
        Config:ToggleSlidePanel(false)
    end
    
    Config.SlidePanel = panel
    return panel
end

function Config:ToggleSlidePanel(show)
    local panel = Config:GetSlidePanel()
    local Skin = _G.ForgeSkin
    
    -- App-Specific ESC Management Logic (Wrapper)
    if show then
        -- Remove Main Frame from ESC list so ESC only closes the SlidePanel
        local mainFrameName = Config.Frame and Config.Frame:GetName()
        if mainFrameName then
             for i=#UISpecialFrames, 1, -1 do
                 if UISpecialFrames[i] == mainFrameName then
                     table.remove(UISpecialFrames, i)
                 end
             end
        end
    else
        -- Add Main Frame back to ESC list if valid
        if Config.Frame then
            local mainFrameName = Config.Frame:GetName()
            if mainFrameName and not tContains(UISpecialFrames, mainFrameName) then
                table.insert(UISpecialFrames, mainFrameName)
            end
        end
        
        -- Execute Widget-Specific Cleanup if exists
        if panel.onCloseWidgetSpecific then
            panel.onCloseWidgetSpecific()
            panel.onCloseWidgetSpecific = nil
        end
    end
    
    -- Delegate Animation to Skin
    Skin:ToggleSlidePanel(panel, show)
end


function Config:OpenDragonridingSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    
    -- If switching contexts while open, ensure cleanup runs
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    
    Config:ToggleSlidePanel(true)
    
    -- Setup Panel basic properties
    panel.header.title:SetText("Dragonriding Settings")
    panel.config = elem
    
    -- Reset Scroll only on fresh open
    if not wasShown and panel.scroll then 
        panel.scroll:SetVerticalScroll(0) 
    end
    
    -- Clear content frame
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    -- Reset Builder if exists
    if panel.builder then 
        if panel.builder.Release then panel.builder:Release() end
        panel.builder = nil 
    end
    
    -- Delegate to Widget's own settings generator
    if _G.WidgetForge and _G.WidgetForge.Dragonriding and _G.WidgetForge.Dragonriding.CreateSettings then
        _G.WidgetForge.Dragonriding:CreateSettings(panel)
    end
end

function Config:OpenCursorRingSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    
    -- If switching contexts while open, ensure cleanup runs
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    
    Config:ToggleSlidePanel(true)
    
    -- Setup Panel basic properties
    panel.header.title:SetText("Cursor Ring Settings")
    panel.config = elem
    panel.barIndex = barIndex -- Context for finding widget instance
    
    -- Reset Scroll only on fresh open
    if not wasShown and panel.scroll then 
        panel.scroll:SetVerticalScroll(0) 
    end
    
    -- Clear content frame
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    -- Reset Builder if exists
    if panel.builder then 
        if panel.builder.Release then panel.builder:Release() end
        panel.builder = nil 
    end
    
    -- Delegate to Widget's own settings generator
    if _G.WidgetForge and _G.WidgetForge.CursorRing and _G.WidgetForge.CursorRing.CreateSettings then
        _G.WidgetForge.CursorRing:CreateSettings(panel)
    end
end

function Config:OpenRetirementHomeSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    
    -- If switching contexts while open, ensure cleanup runs
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    
    Config:ToggleSlidePanel(true)
    
    -- Setup Panel basic properties
    panel.header.title:SetText("Retirement Home Settings")
    panel.config = elem
    panel.barIndex = barIndex
    
    -- Reset Scroll only on fresh open
    if not wasShown and panel.scroll then 
        panel.scroll:SetVerticalScroll(0) 
    end
    
    -- Clear content frame
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    -- Reset Builder if exists
    if panel.builder then 
        if panel.builder.Release then panel.builder:Release() end
        panel.builder = nil 
    end
    
    -- Delegate to Widget's own settings generator
    if _G.WidgetForge and _G.WidgetForge.RetirementHome and _G.WidgetForge.RetirementHome.CreateSettings then
        _G.WidgetForge.RetirementHome:CreateSettings(panel)
    end
end

function Config:OpenMythicPlusSettings(barIndex, elemIndex, elem)
    print("DEBUG: Config:OpenMythicPlusSettings Called")
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    
    -- If switching contexts while open, ensure cleanup runs
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    
    Config:ToggleSlidePanel(true)
    
    -- Setup Panel basic properties
    panel.header.title:SetText("Mythic+ Dashboard Settings")
    panel.config = elem
    panel.barIndex = barIndex
    
    -- Reset Scroll only on fresh open
    if not wasShown and panel.scroll then 
        panel.scroll:SetVerticalScroll(0) 
    end
    
    -- Clear content frame
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    -- Reset Builder if exists
    if panel.builder then 
        if panel.builder.Release then panel.builder:Release() end
        panel.builder = nil 
    end
    
    -- Delegate to Widget's own settings generator
    if _G.WidgetForge and _G.WidgetForge.MythicPlus and _G.WidgetForge.MythicPlus.CreateSettings then
        _G.WidgetForge.MythicPlus:CreateSettings(panel)
    end
end


function Config:OpenDummySettings(barIndex, elemIndex, elem)
    Config:ToggleSlidePanel(true)
    local panel = Config:GetSlidePanel()
    local content = panel.content
    
    -- Clear Content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    -- Setup Settings UI for Dummy
    panel.header.title:SetText("Dummy Widget Settings")
    
    local Skin = _G.ForgeSkin
    
    -- Example Controls
    local y = -20
    Skin:CreateSectionHeader(content, "Test Controls", 600):SetPoint("TOPLEFT", 10, y)
    y = y - 40
    
    -- Text Input
    local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 20, y+5)
    lbl:SetText("Display Text:")
    
    local ebFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ebFrame:SetSize(200, 30)
    ebFrame:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
    Skin:ApplyBackdrop(ebFrame)
    
    local eb = CreateFrame("EditBox", nil, ebFrame)
    eb:SetAllPoints(ebFrame); eb:SetTextInsets(5,5,0,0); eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetText(elem.text or "DUMMY WIDGET")
    eb:SetScript("OnTextChanged", function(self) 
        elem.text = self:GetText()
        WidgetForge:RebuildBarComponents(barIndex)
    end)
    
    y = y - 50
    
    -- Color
    local lblC = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblC:SetPoint("TOPLEFT", 20, y+5)
    lblC:SetText("Background Color:")
    
    local btnC = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnC:SetSize(30, 30)
    btnC:SetPoint("LEFT", lblC, "RIGHT", 10, 0)
    Skin:ApplyBackdrop(btnC)
    local col = elem.color or {0.5, 0.5, 0.5, 0.5}
    btnC:SetBackdropColor(unpack(col))
    
    btnC:SetScript("OnClick", function()
        Skin:ShowColorPicker({
            r=col[1], g=col[2], b=col[3], opacity=col[4],
            swatchFunc = function(c) 
                elem.color = c
                btnC:SetBackdropColor(unpack(c))
                WidgetForge:RebuildBarComponents(barIndex)
            end,
            cancelFunc = function()
                 btnC:SetBackdropColor(unpack(col))
                 elem.color = col
                 WidgetForge:RebuildBarComponents(barIndex)
            end
        })
    end)
    
    y = y - 60
    
    local txt = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("TOPLEFT", 20, y)
    txt:SetWidth(500)
    txt:SetJustifyH("LEFT")
    txt:SetText("This panel slides in from the right side, covering the main configuration area without being a separate popup window. This allows for a more integrated settings experience.")
    
    -- Update Content Height for Scrolling
    if content.SetHeight then content:SetHeight(math.abs(y) + 100) end
end

SLASH_WIDGETFORGE1 = "/wf"
SlashCmdList["WIDGETFORGE"] = function() 
    Config:OpenConfigWindow() 
end