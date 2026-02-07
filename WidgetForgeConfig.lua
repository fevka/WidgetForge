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
    "FPS", "MS", "Clock", "RAM", "Durability", "Bag Space", 
    "Stamina", "Main Stat", 
    "Crit", "Haste", "Mastery", "Versatility", 
    "Avoidance", "Leech", "Speed", "Dodge", "Parry",
    "Gold", "Zone", "Coords", "Item Level", "Combat Timer", "XP"
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
    }}
}

-- --- MAIN CONFIG WINDOW ---
function Config:OpenConfigWindow()
    if Config.Frame then Config.Frame:Show(); return end
    
    local f = CreateFrame("Frame", "EsrefConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(900, 600) 
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    Skin:ApplyBackdrop(f)
    
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

    local scrollDetails, contentDetails = Skin:CreateScrollFrame(mainPanel, 660, 510) 
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
    
    if WidgetForge.SetSelectedBar then WidgetForge:SetSelectedBar(index) end
    Config:RefreshBarList() 
    
    local content = Config.DetailsContent
    if not content then return end 
    content:HideAllChildren()
    
    if not index then return end
    local bar = WidgetForgeDB.bars[index]
    if not bar then return end
    
    local y = -10
    
    -- --- SECTION 1: BAR LAYOUT ---
    local hLayout = Skin:CreateSectionHeader(content, "Bar Layout: " .. bar.name, 620)
    hLayout:SetPoint("TOPLEFT", 10, y)
    
    -- [DUZELTME] Düğmeyi ve Dropdown'ı doğru sırayla oluşturuyoruz.
    -- Hedef: [Dropdown] [Güç Düğmesi(En Sağda)]
    
    -- 1. ENABLE / DISABLE TOGGLE BUTTON (En Sağa Yaslı)
    local btnEnable = Skin:CreateButton(content, "ENABLED", 80, 25)
    -- hLayout (Başlık Çizgisi) referans alınarak en sağa (-2 px boşlukla) yaslanır.
    btnEnable:SetPoint("TOPRIGHT", hLayout, "TOPRIGHT", -2, 2) 
    
    local function UpdateEnableButton()
        if bar.enabled then
            btnEnable:SetBackdropColor(0.5, 0.8, 0.5, 1)
            btnEnable:SetBackdropBorderColor(0, 1, 0, 1)
            btnEnable.text:SetText("ENABLED")
            btnEnable.text:SetTextColor(1, 1, 1, 1)
-- Hover: Hafif parlak
            btnEnable:SetScript("OnEnter", function() btnEnable:SetBackdropColor(0.65, 1.0, 0.65, 1) end)
            btnEnable:SetScript("OnLeave", function() btnEnable:SetBackdropColor(0.5, 0.8, 0.5, 1) end)
        else
            btnEnable:SetBackdropColor(0.7, 0, 0, 1) -- KIRMIZI
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
    -- Dropdown'ı Düğmenin SOLUNA (-5 px boşlukla) yaslıyoruz.
    ddScope:SetPoint("RIGHT", btnEnable, "LEFT", -5, 0)
    
    y = y - 40

    -- Row 1: Name, Title, Vertical
    local lblName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblName:SetPoint("TOPLEFT", 10, y - 8); lblName:SetText("Bar Name:"); lblName:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local ebNameFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ebNameFrame:SetSize(180, 25); ebNameFrame:SetPoint("TOPLEFT", 90, y)
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

    local chkTitle = Skin:CreateCheckbox(content, "Show Title Bar", bar.showTitle, function(v) bar.showTitle = v; WidgetForge:RebuildBarComponents(index) end)
    chkTitle:SetPoint("TOPLEFT", 290, y - 3)

    local chkLayout = Skin:CreateCheckbox(content, "Vertical Layout", bar.layout == "VERTICAL", function(v) bar.layout = v and "VERTICAL" or "HORIZONTAL"; Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end)
    chkLayout:SetPoint("TOPLEFT", 430, y - 3)
    y = y - 40

    -- Row 2: Alignment, Spacing, BG
    local lblJ = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblJ:SetPoint("TOPLEFT", 10, y - 8); lblJ:SetText("Alignment:"); lblJ:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local ddJustify = Skin:CreateDropdown(content, 120, { "LEFT", "CENTER", "RIGHT" }, bar.justify or "CENTER", function(v) bar.justify = v; WidgetForge:RebuildBarComponents(index) end)
    ddJustify:SetPoint("TOPLEFT", 90, y)

    local lblPad = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblPad:SetPoint("TOPLEFT", 230, y - 8); lblPad:SetText("Spacing:"); lblPad:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local slPad = Skin:CreateSlider(content, 0, 50, 1, bar.padding or 5, function(v) bar.padding = v; WidgetForge:UpdateAvailableBars() end, 120)
    slPad:SetPoint("TOPLEFT", 290, y)

    local lblBg = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblBg:SetPoint("TOPLEFT", 430, y - 8); lblBg:SetText("Bg Color:"); lblBg:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local btnBg = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBg:SetSize(20, 20); btnBg:SetPoint("TOPLEFT", 500, y - 3 ) 
    Skin:ApplyBackdrop(btnBg); local bg = bar.bgColor or {0, 0, 0, 0.5}; btnBg:SetBackdropColor(unpack(bg))
    btnBg:SetScript("OnClick", function()
        local info = { r=bg[1], g=bg[2], b=bg[3], opacity=bg[4], swatchFunc = function(c) bar.bgColor = c; btnBg:SetBackdropColor(unpack(c)); WidgetForge:UpdateAvailableBars() end }
        Skin:ShowColorPicker(info)
    end)
    
    y = y - 50

    -- --- SECTION 2: BAR SIZE ---
    local hSize = Skin:CreateSectionHeader(content, "Bar Size", 620); hSize:SetPoint("TOPLEFT", 10, y); y = y - 40
    local lblW = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblW:SetPoint("TOPLEFT", 10, y - 8); lblW:SetText("Bar Width:"); lblW:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local slW = Skin:CreateSlider(content, 50, 600, 5, bar.width, function(v) bar.width = v; WidgetForge:UpdateAvailableBars() end, 150); slW:SetPoint("TOPLEFT", 90, y)
    local lblH = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblH:SetPoint("TOPLEFT", 260, y - 8); lblH:SetText("Bar Height:"); lblH:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local slH = Skin:CreateSlider(content, 10, 200, 2, bar.height, function(v) bar.height = v; WidgetForge:UpdateAvailableBars() end, 150); slH:SetPoint("TOPLEFT", 340, y)
    y = y - 50

    -- --- SECTION 3: BORDER SETTINGS ---
    local hBorder = Skin:CreateSectionHeader(content, "Border Settings", 620); hBorder:SetPoint("TOPLEFT", 10, y); y = y - 40
    local lblBS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblBS:SetPoint("TOPLEFT", 10, y - 8); lblBS:SetText("Border Size:"); lblBS:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local slBS = Skin:CreateSlider(content, 1, 10, 1, bar.borderSize or 1, function(v) bar.borderSize = v; WidgetForge:UpdateAvailableBars() end, 150); slBS:SetPoint("TOPLEFT", 90, y)
    local lblBC = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblBC:SetPoint("TOPLEFT", 260, y - 8); lblBC:SetText("Border Color:"); lblBC:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    local btnBC = CreateFrame("Button", nil, content, "BackdropTemplate"); btnBC:SetSize(20, 20); btnBC:SetPoint("TOPLEFT", 340, y - 3); Skin:ApplyBackdrop(btnBC); local bc = bar.borderColor or {0.2, 0.2, 0.2, 1}; btnBC:SetBackdropColor(unpack(bc))
    btnBC:SetScript("OnClick", function() local info = { r=bc[1], g=bc[2], b=bc[3], opacity=bc[4], swatchFunc = function(c) bar.borderColor = c; btnBC:SetBackdropColor(unpack(c)); WidgetForge:UpdateAvailableBars() end }; Skin:ShowColorPicker(info) end)
    local chkBorder = Skin:CreateCheckbox(content, "Show", bar.showBorder, function(v) bar.showBorder = v; WidgetForge:UpdateAvailableBars() end); chkBorder:SetPoint("TOPLEFT", 430, y - 3)
    y = y - 60

    -- --- ELEMENTS ---
    local headEl = Skin:CreateSectionHeader(content, "Bar Elements", 620); headEl:SetPoint("TOPLEFT", 10, y); y = y - 40

    local gridX, gridY = 0, 0
    for i, typeName in ipairs(Config.ElementTypes) do
        local btn = Skin:CreateButton(content, typeName, 120, 20)
        btn:SetPoint("TOPLEFT", 10 + (gridX * 125), y - (gridY * 25))
        local exists = false
        for _, e in ipairs(bar.elements) do if e.type == typeName then exists = true; break end end
        if exists then
            btn:SetBackdropColor(unpack(Skin.Colors.accent)); btn:SetBackdropBorderColor(1, 1, 1, 1); btn.text:SetTextColor(1, 1, 1, 1); btn:SetScript("OnEnter", nil); btn:SetScript("OnLeave", nil)
            btn:SetScript("OnClick", function() for idx, e in ipairs(bar.elements) do if e.type == typeName then table.remove(bar.elements, idx); break end end; C_Timer.After(0.05, function() Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end) end)
        else
            btn:SetScript("OnClick", function() table.insert(bar.elements, { type = typeName, label = typeName, color = {1,1,1,1}, font = "Friz Quadrata", size = 14, outline = "OUTLINE" }); C_Timer.After(0.05, function() Config:SelectBar(index); WidgetForge:RebuildBarComponents(index) end) end)
        end
        gridX = gridX + 1; if gridX > 4 then gridX = 0; gridY = gridY + 1 end
    end
    y = y - (gridY * 25) - 40
    
    local fontList = {}; for k, v in pairs(Skin.Media.Fonts) do table.insert(fontList, {text=k, value=k, font=v}) end
    local outlineList = { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick", value="THICKOUTLINE"}, {text="Mono", value="MONOCHROME"}, {text="Mono+Out", value="MONOCHROME,OUTLINE"} }

    Config.ElementRows = {}
    for i, elem in ipairs(bar.elements) do
        local item = CreateFrame("Frame", nil, content, "BackdropTemplate")
        item:SetSize(620, 32); item:SetPoint("TOPLEFT", 10, y); Skin:ApplyBackdrop(item, 0.3, 0.5)
        item.txt = item:CreateFontString(nil, "OVERLAY", "GameFontNormal"); item.txt:SetPoint("LEFT", 8, 0); item.txt:SetText(i..". "..elem.type); item.txt:SetFont(Skin.Constants.FONT_NORMAL, 11, "OUTLINE"); item.txt:SetWidth(110); item.txt:SetJustifyH("LEFT")

        local btnRem = Skin:CreateButton(item, "X", 20, 20); btnRem:SetPoint("RIGHT", -10, 0); btnRem.text:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE")
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
        
        local slSz = Skin:CreateSlider(item, 8, 50, 1, elem.size, function(v) elem.size = v; WidgetForge:RebuildBarComponents(index) end, 70); slSz:SetPoint("RIGHT", btnCol, "LEFT", -15, 0)
        local ddOutline = Skin:CreateDropdown(item, 85, outlineList, elem.outline or "OUTLINE", function(v) elem.outline = v; WidgetForge:RebuildBarComponents(index) end); ddOutline:SetPoint("RIGHT", slSz, "LEFT", -10, 0) 
        local ddFont = Skin:CreateDropdown(item, 100, fontList, elem.font or "Standard", function(v) elem.font = v; WidgetForge:RebuildBarComponents(index) end); ddFont:SetPoint("RIGHT", ddOutline, "LEFT", -10, 0)
        local chkIcon = Skin:CreateCheckbox(item, "Icon", elem.showIcon, function(v) elem.showIcon = v; WidgetForge:RebuildBarComponents(index) end); chkIcon:SetWidth(45); chkIcon:SetPoint("RIGHT", ddFont, "LEFT", -5, 0); chkIcon.box:SetSize(14, 14); chkIcon.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE")
        local chkTip = Skin:CreateCheckbox(item, "Tip", elem.showTooltip, function(v) elem.showTooltip = v; WidgetForge:RebuildBarComponents(index) end); chkTip:SetWidth(40); chkTip:SetPoint("RIGHT", chkIcon, "LEFT", -5, 0); chkTip.box:SetSize(14, 14); chkTip.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "OUTLINE") 
        if elem.type == "Clock" then local fmtList = { {text="24h", value="24h"}, {text="12h", value="12h"} }; local ddFmt = Skin:CreateDropdown(item, 50, fmtList, elem.timeFormat or "24h", function(v) elem.timeFormat = v; WidgetForge:RebuildBarComponents(index) end); ddFmt:SetPoint("RIGHT", chkTip, "LEFT", -5, 0) end
        y = y - 36 
    end
    content:SetHeight(math.abs(y) + 20)
end

SLASH_WIDGETFORGE1 = "/wf"
SlashCmdList["WIDGETFORGE"] = function() 
    Config:OpenConfigWindow() 
    if #WidgetForgeDB.bars > 0 then Config:SelectBar(1) end
end