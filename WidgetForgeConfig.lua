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
            visibility = "ALWAYS",
            width = 250, height = 30,
            point = "CENTER", x = 0, y = 150,
            bgColor = {0, 0, 0, 0.6},
            layout = "HORIZONTAL", 
            showBorder = true,
            borderSize = 1,
            borderColor = {0.2, 0.2, 0.2, 1},
            padding = 10,
            elements = {
                [1] = { type = "FPS", label = "FPS", color = {1,1,1,1}, font="Righteous", size=14, outline="OUTLINE" },
                [2] = { type = "MS", label = "MS", color = {1,1,1,1}, font="Righteous", size=14, outline="OUTLINE" },
                [3] = { type = "Clock", label = "Time", color = {1,0.8,0,1}, font="Righteous", size=14, outline="OUTLINE" }
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
    "Dragonriding", "Skill Stream", "Guild", "Friends", "Difficulty", "Target Castbar", "Talent Loadout", "Custom Code", 
    "Interrupt Sync", "VaultEye", "CCPartySync", "PrepChecker", "Move Widget", "Level Up Tracker"
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

function Config:OpenConfigWindow()
    if Config.Frame then Config.Frame:Show(); return end
    
    local f = CreateFrame("Frame", "EsrefConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(870, 600) 
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    Skin:ApplyBackdrop(f)
    tinsert(UISpecialFrames, "EsrefConfigFrame")

    -- Yeniden boyutlandırma desteği
    f:SetResizable(true)
    f:SetResizeBounds(870, 600)

    -- Sağ alt köşe: resize handle (media/resize.tga)
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(13, 13)
    resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    resizeBtn:SetFrameLevel(f:GetFrameLevel() + 10)

    local triTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    triTex:SetAllPoints(resizeBtn)
    triTex:SetTexture("Interface\\AddOns\\WidgetForge\\media\\resize.tga")
    triTex:SetAlpha(0.7)

    resizeBtn:SetScript("OnEnter", function() triTex:SetAlpha(1) end)
    resizeBtn:SetScript("OnLeave", function() triTex:SetAlpha(0.7) end)

    resizeBtn:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
    end)

    Skin:CreateTitleBar(f, "WidgetForge | Advanced Status Bars", function() f:Hide() end)
    
    f:SetScript("OnShow", function() WidgetForge:SetBarsLocked(false) end)
    f:SetScript("OnHide", function() 
        WidgetForge:SetBarsLocked(true) 
        Config:ToggleSlidePanel(false) 
    end)
    WidgetForge:SetBarsLocked(false) 
    
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

    local btnAdd = Skin:CreateButton(f, "+ New Empty Bar", 200, 25)
    btnAdd:SetPoint("TOPLEFT", sidebar, "BOTTOMLEFT", 0, -10)
    btnAdd:SetScript("OnClick", function()
        Config:ToggleSlidePanel(false) 
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(Config.DefaultSettings.bars[1])
        WidgetForgeDB.bars[newId].name = "New Bar " .. newId
        WidgetForgeDB.bars[newId].scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }

        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
    end)
    
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
        Config:ToggleSlidePanel(false) 
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
    
    local btnSavePreset = CreateFrame("Button", nil, f)
    btnSavePreset:SetSize(25, 25)
    btnSavePreset:SetPoint("LEFT", ddPreset, "RIGHT", 5, 0)
    local plusIcon = btnSavePreset:CreateTexture(nil, "OVERLAY")
    plusIcon:SetSize(18, 18)
    plusIcon:SetPoint("CENTER")
    plusIcon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\plus.tga")
    plusIcon:SetVertexColor(1, 1, 1, 1)
    btnSavePreset:SetScript("OnEnter", function()
        plusIcon:SetVertexColor(0, 0.8, 1, 1)
    end)
    btnSavePreset:SetScript("OnLeave", function()
        plusIcon:SetVertexColor(1, 1, 1, 1)
    end)
    btnSavePreset:SetScript("OnMouseDown", function() plusIcon:SetPoint("CENTER", 1, -1) end)
    btnSavePreset:SetScript("OnMouseUp", function() plusIcon:SetPoint("CENTER", 0, 0) end)
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
    
    local btnDelPreset = CreateFrame("Button", nil, f)
    btnDelPreset:SetSize(25, 25)
    btnDelPreset:SetPoint("LEFT", btnSavePreset, "RIGHT", 2, 0)
    local minusIcon = btnDelPreset:CreateTexture(nil, "OVERLAY")
    minusIcon:SetSize(18, 18)
    minusIcon:SetPoint("CENTER")
    minusIcon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\minus.tga")
    minusIcon:SetVertexColor(1, 1, 1, 1)
    btnDelPreset:SetScript("OnEnter", function()
        minusIcon:SetVertexColor(1, 0.2, 0.2, 1)
    end)
    btnDelPreset:SetScript("OnLeave", function()
        minusIcon:SetVertexColor(1, 1, 1, 1)
    end)
    btnDelPreset:SetScript("OnMouseDown", function() minusIcon:SetPoint("CENTER", 1, -1) end)
    btnDelPreset:SetScript("OnMouseUp", function() minusIcon:SetPoint("CENTER", 0, 0) end)
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
                Config:ToggleSlidePanel(false) 
                WidgetForgeDB = t
                Config:RefreshBarList()
                WidgetForge:UpdateAvailableBars()
                print("|cff00ff00Profile imported.|r")
                Config.DetailsContent:HideAllChildren()
            else print("|cffff0000Invalid profile!|r") end
        end)
    end)

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
        local showInList = WidgetForge:IsBarRelevant(bar) 

        if showInList then
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
            icon:SetSize(18, 18)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\close.tga")
            icon:SetVertexColor(1, 1, 1, 1)
            
            btnDel:SetScript("OnEnter", function() icon:SetVertexColor(1, 0.2, 0.2, 1) end)
            btnDel:SetScript("OnLeave", function() icon:SetVertexColor(1, 1, 1, 1) end)
            
            btnDel:SetScript("OnClick", function() 
                Config:ToggleSlidePanel(false) 
                table.remove(WidgetForgeDB.bars, i)
                Config.SelectedBarIndex = nil 
                Config:RefreshBarList()
                Config.DetailsContent:HideAllChildren()
                WidgetForge:UpdateAvailableBars()
            end)
            
            table.insert(content.buttons, btn)
            y = y - 35
        end
    end
    
    content:SetHeight(math.max(1, math.abs(y)))
end

function Config:SelectBar(index)
    if Config.SelectedBarIndex ~= index then
        Config:ToggleSlidePanel(false)
    end

    Config.isUpdatingScale = false
    Config.SelectedBarIndex = index
    
    if WidgetForge.SetSelectedBar then WidgetForge:SetSelectedBar(index) end
    Config:RefreshBarList() 
    
    function Config:UpdateCoordinates(index)
        if Config.SelectedBarIndex ~= index then return end
        if not Config.Frame or not Config.Frame:IsShown() then return end
        
        local bar = WidgetForgeDB.bars[index]
        if not bar then return end

        Config.isUpdatingScale = true
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
    
    local isExclusive = false
    local exclusiveType = nil
    for _, e in ipairs(bar.elements) do
        if e.type == "Dragonriding" or e.type == "Cursor Ring" or e.type == "Retirement Home" or e.type == "Mythic+ Dashboard" or e.type == "Skill Stream" or e.type == "Target Castbar" or e.type == "Interrupt Sync" or e.type == "VaultEye" or e.type == "CCPartySync" or e.type == "PrepChecker" or e.type == "Move Widget" or e.type == "Level Up Tracker" then 
            isExclusive = true
            exclusiveType = e.type
            break 
        end
    end
    
    local y = -10
    
    local hLayout
    if not isExclusive then
        hLayout = Skin:CreateSectionHeader(content, "Bar Layout: " .. bar.name, 610)
    else
        hLayout = Skin:CreateSectionHeader(content, "Bar: " .. bar.name .. " LAYOUT LOCKED", 610)
        if hLayout.text then hLayout.text:SetTextColor(1, 0.3, 0.3, 1) end
    end
    hLayout:SetPoint("TOPLEFT", 10, y)
    
    local btnEnable = Skin:CreateSwitch(content, "", bar.enabled, function(val)
        bar.enabled = val
        WidgetForge:UpdateAvailableBars() 
    end, "ON", "OFF")
    btnEnable:SetWidth(54)
    btnEnable:SetPoint("TOPRIGHT", hLayout, "TOPRIGHT", -2, 2) 
    
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
                 bar.scope = { type = "SPEC", value = GetSpecializationInfo(spec), character = UnitName("player") .. "-" .. GetRealmName() }
            else print("Error: No Spec active."); return end
        end
        WidgetForge:UpdateAvailableBars()
        Config:RefreshBarList() 
    end)
    ddScope:SetPoint("RIGHT", btnEnable, "LEFT", -5, 0)
    
    y = y - 40

    local rowStartX = 10   -- align with section separators (left edge)
    local rowEndX = 620    -- 10 + 610 separator width (right edge)
    local rowTop = y - 4
    local colGap = 14
    local labelGap = 6
    local nameLabelW = 42
    local visLabelW = 70
    local layerLabelW = 42
    local nameW = 180
    local visW = 110
    local boxH = 25

    local nameLabelX = rowStartX
    local nameBoxX = nameLabelX + nameLabelW + labelGap
    local visLabelX = nameBoxX + nameW + colGap
    local visBoxX = visLabelX + visLabelW + labelGap
    local layerLabelX = visBoxX + visW + colGap
    local layerBoxX = layerLabelX + layerLabelW + labelGap
    local layerW = rowEndX - layerBoxX

    local ebNameFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    ebNameFrame:SetSize(nameW, boxH); ebNameFrame:SetPoint("TOPLEFT", nameBoxX, rowTop)
    Skin:ApplyBackdrop(ebNameFrame); ebNameFrame:SetBackdropColor(0,0,0,0.5); ebNameFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local ebName = CreateFrame("EditBox", nil, ebNameFrame)
    ebName:SetAllPoints(ebNameFrame); ebName:SetFont(Skin.Constants.FONT_NORMAL, 12, "")
    ebName:SetTextInsets(5, 5, 0, 0); ebName:SetAutoFocus(false); ebName:SetText(bar.name)
    ebName:SetMaxLetters(40) 
    ebName:SetScript("OnEnterPressed", function(self) 
        bar.name = self:GetText(); if hLayout.text then hLayout.text:SetText(string.upper("Bar Layout: " .. bar.name)) end
        Config:RefreshBarList(); self:ClearFocus() 
    end)
    ebName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local lblName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblName:SetWidth(nameLabelW)
    lblName:SetJustifyH("LEFT")
    lblName:SetPoint("LEFT", ebNameFrame, "LEFT", -(nameLabelW + labelGap), 0)
    lblName:SetText("NAME:")
    lblName:SetFont(Skin.Constants.FONT_NORMAL, 11, "")

    local lblVis = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblVis:SetWidth(visLabelW)
    lblVis:SetJustifyH("RIGHT")
    lblVis:SetText("VISIBILITY:")
    lblVis:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local visList = {
        {text = "Always Show", value = "ALWAYS"},
        {text = "Combat Only", value = "COMBAT"},
        {text = "Out of Combat", value = "OUT_OF_COMBAT"}
    }
    local currentVisVal = bar.visibility or "ALWAYS"
    
    local ddVis = Skin:CreateDropdown(content, visW, visList, currentVisVal, function(v)
        bar.visibility = v
        if WidgetForge.UpdateBarVisibilityStates then WidgetForge:UpdateBarVisibilityStates() end
    end)
    ddVis:SetPoint("TOPLEFT", visBoxX, rowTop)
    lblVis:SetPoint("RIGHT", ddVis, "LEFT", -labelGap, 0)

    local lblLayer = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblLayer:SetWidth(layerLabelW)
    lblLayer:SetJustifyH("RIGHT")
    lblLayer:SetText("LAYER:")
    lblLayer:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
    
    local layerList = {
        {text = "Background", value = "BACKGROUND"},
        {text = "Low", value = "LOW"},
        {text = "Medium", value = "MEDIUM"},
        {text = "High", value = "HIGH"},
        {text = "Dialog", value = "DIALOG"},
        {text = "Fullscreen", value = "FULLSCREEN"},
        {text = "Tooltip", value = "TOOLTIP"}
    }
    local currentLayerVal = bar.layer or "DIALOG"
    
    local ddLayer = Skin:CreateDropdown(content, layerW, layerList, currentLayerVal, function(v)
        bar.layer = v
        WidgetForge:UpdateAvailableBars()
    end)
    ddLayer:SetPoint("TOPLEFT", layerBoxX, rowTop)
    lblLayer:SetPoint("RIGHT", ddLayer, "LEFT", -labelGap, 0)

    local settingsContentH = 550
    if isExclusive then settingsContentH = 150 end
    
    local settingsAcc = Skin:CreateAccordion(content, "BAR CONFIGURATION", settingsContentH, function(expanded)
        Config.SettingsAccordionExpanded = expanded
        if Config.UpdateAccordionLayout then Config.UpdateAccordionLayout() end
    end)
    settingsAcc.onAnimUpdate = function() if Config.UpdateAccordionLayout then Config.UpdateAccordionLayout() end end
    if Config.SettingsAccordionExpanded == nil then Config.SettingsAccordionExpanded = false end
    settingsAcc:SetExpanded(Config.SettingsAccordionExpanded)
    
    -- Exclisive widget'larda BAR CONFIGURATION kısmını Cursor Ring ve Retirement Home için tamamen gizle
    if exclusiveType == "Cursor Ring" or exclusiveType == "Retirement Home" or exclusiveType == "Move Widget" then
        settingsAcc:Hide()
    end
    
    local settingsSep = Skin:CreateSeparator(content, 610)
    settingsSep:Hide()
    
    if Config.mainBuilder then Config.mainBuilder:Release() end
    local sb = WidgetForgeUtils:CreateSettingsBuilder(settingsAcc.content)
    Config.mainBuilder = sb
    sb.y = -10 

    if not isExclusive then
        sb:AddHeader("Bar Layout & Styling")
        sb:AddSwitch("showTitle", "Show Title Bar", false, bar, function(v) WidgetForge:RebuildBarComponents(index) end)
        bar.isVertical = (bar.layout == "VERTICAL")
        sb:AddSwitch("isVertical", "Vertical Layout", false, bar, function(v) 
             bar.layout = v and "VERTICAL" or "HORIZONTAL"
            WidgetForge:UpdateAvailableBars()
        end)
        sb:AddDropdown("justify", "Alignment", { "LEFT", "CENTER", "RIGHT" }, "CENTER", bar, function(v) WidgetForge:RebuildBarComponents(index) end)
        sb:AddSlider("padding", "Spacing", -10, 50, 1, 5, bar, function(v) WidgetForge:UpdateAvailableBars() end)
    end

    if exclusiveType ~= "Cursor Ring" and exclusiveType ~= "Retirement Home" and exclusiveType ~= "Move Widget" then
        sb:AddHeader("Position")
        sb:AddSlider("x", "X Offset", -math.floor(GetScreenWidth()/2), math.floor(GetScreenWidth()/2), 1, 0, bar, function(v) 
            if Config.isUpdatingScale then return end
            WidgetForge:UpdateAvailableBars() 
        end)
        Config.slX = sb.controls[#sb.controls] -- capture the slider ref
        
        sb:AddSlider("y", "Y Offset", -math.floor(GetScreenHeight()/2), math.floor(GetScreenHeight()/2), 1, 0, bar, function(v) 
            if Config.isUpdatingScale then return end
            WidgetForge:UpdateAvailableBars() 
        end)
        Config.slY = sb.controls[#sb.controls] -- capture the slider ref
    end

    if not isExclusive then
        sb:AddHeader("Background Settings")
        sb:AddSlider("width", "Width", 50, 600, 5, 250, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddSlider("height", "Height", 10, 200, 2, 30, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddColor("bgColor", "Background Color", {0, 0, 0, 0.5}, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddSwitch("clickThrough", "Click Through (Non-Interactive)", false, bar, function(v) 
            WidgetForge:SetBarsLocked(false) 
            WidgetForge:SetBarsLocked(WidgetForge.BarsLocked)
            Config:ApplyClickThroughToElementRows(bar)
        end)

        sb:AddHeader("Border Settings")
        sb:AddSwitch("showBorder", "Show Border", true, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddSlider("borderSize", "Border Size", 1, 10, 1, 1, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddColor("borderColor", "Border Color", {0.2, 0.2, 0.2, 1}, bar, function(v) WidgetForge:UpdateAvailableBars() end)
    end

    sb:Finish()
    settingsAcc:SetContentHeight(settingsAcc.content:GetHeight())
    
    -- Now fix the layout dynamically
    local MasterY = y - 40
    local headEl = Skin:CreateSectionHeader(content, "Bar Elements", 610)
    
    local barMode = "EMPTY"
    local OverlayTypes = { ["Cursor Ring"] = true, ["Retirement Home"] = true }
    
    if bar.elements and #bar.elements > 0 then
        barMode = "STANDARD"
        for _, e in ipairs(bar.elements) do
            if e.type == "Dragonriding" or e.type == "Mythic+ Dashboard" or e.type == "Skill Stream" or e.type == "Target Castbar" or e.type == "Interrupt Sync" or e.type == "VaultEye" or e.type == "CCPartySync" or e.type == "PrepChecker" or e.type == "Move Widget" or e.type == "Level Up Tracker" then 
                barMode = "STRICT"
                break 
            elseif OverlayTypes[e.type] then
                barMode = "OVERLAY"
            end
        end
    end
    
    local categories = {
        { name = "System & Performance", elements = { "FPS", "MS", "Clock" } },
        { name = "Player Stats", elements = { "Main Stat", "Stamina", "Crit", "Haste", "Mastery", "Versatility", "Avoidance", "Leech", "Speed", "Run Speed", "Dodge", "Parry", "Armor", "Max HP" } },
        { name = "Progression & Goods", elements = { "XP", "Gold", "Bag Space", "Item Level", "Durability" } },
        { name = "Navigation", elements = { "Zone", "Coords" } },
        { name = "Social", elements = { "Guild", "Friends" } },
        { name = "Dungeon & Raid", elements = { "Mythic+ Dashboard", "Target Castbar", "Interrupt Sync", "CCPartySync", "PrepChecker", "Combat Timer", "Difficulty" } },
        { name = "Utils", elements = { "Dragonriding", "Cursor Ring", "Retirement Home", "Skill Stream", "VaultEye", "Move Widget", "Level Up Tracker", "Talent Loadout", "Custom Code" } }
    }
    
    Config.AccordionStates = Config.AccordionStates or {} 
    
    local accFrameList = {}
    local activeElementsFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    activeElementsFrame:SetWidth(610)
    activeElementsFrame:SetHeight(1) 
    
    local listSeparator = Skin:CreateSeparator(content, 610) 
    local ddFilter
    
    Config.UpdateAccordionLayout = function()
        local currentY = MasterY
        
        settingsAcc:SetPoint("TOPLEFT", 10, currentY)
        currentY = currentY - settingsAcc:GetHeight() - 10
        
        if Config.SettingsAccordionExpanded then
            settingsSep:ClearAllPoints()
            settingsSep:SetPoint("TOPLEFT", 10, currentY)
            settingsSep:Show()
            currentY = currentY - 15
        else
            settingsSep:Hide()
        end
        
        headEl:SetPoint("TOPLEFT", 10, currentY)
        if ddFilter then ddFilter:SetPoint("TOPRIGHT", headEl, "TOPLEFT", 610, 5) end
        currentY = currentY - 40
        
        for _, acc in ipairs(accFrameList) do
            if acc:IsShown() then
                acc:SetPoint("TOPLEFT", 10, currentY)
                currentY = currentY - acc:GetHeight() - 5
            end
        end
        
        local sepY = currentY - 10
        listSeparator:ClearAllPoints()
        listSeparator:SetPoint("TOPLEFT", 10, sepY)
        
        activeElementsFrame:SetPoint("TOPLEFT", 0, currentY - 25)
        
        local totalH = math.abs(MasterY) + math.abs(currentY - MasterY) + activeElementsFrame:GetHeight() + 100
        content:SetHeight(totalH) 
    end

    if not Config.SelectedElementCategories then
        Config.SelectedElementCategories = { ["ALL"] = true }
        for _, c in ipairs(categories) do Config.SelectedElementCategories[c.name] = true end
    end
    
    local filterList = { {text="Show All", value="ALL"} }
    for _, c in ipairs(categories) do table.insert(filterList, {text=c.name, value=c.name}) end
    
    local ddFilter = Skin:CreateMultiDropdown(content, 180, filterList, Config.SelectedElementCategories, function(val, newState)
        for _, acc in ipairs(accFrameList) do
            local isVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[acc.catName]
            acc:SetShown(isVisible)
        end
        Config.UpdateAccordionLayout()
    end)
    
    ddFilter:SetPoint("TOPRIGHT", headEl, "TOPLEFT", 610, 5) 

    for _, cat in ipairs(categories) do
        local displayElements = { "Divider" }
        for _, e in ipairs(cat.elements) do table.insert(displayElements, e) end
        
        local numRows = math.ceil(#displayElements / 5)
        local contentH = numRows * 30 + 10 
        
        local acc = Skin:CreateAccordion(content, cat.name, contentH, function(expanded) 
            Config.AccordionStates[cat.name] = expanded
            Config.UpdateAccordionLayout() 
        end)
        acc.onAnimUpdate = Config.UpdateAccordionLayout
        acc.catName = cat.name 
        table.insert(accFrameList, acc)
        
        local isInitialVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[cat.name]
        acc:SetShown(isInitialVisible)
        
        if Config.AccordionStates[cat.name] then acc:SetExpanded(true) end

        local btnX, btnY = 5, -5
        for i, typeName in ipairs(displayElements) do
            local isDragonBtn = (typeName == "Dragonriding")
            local isSkillStreamBtn = (typeName == "Skill Stream")
            local isTargetCastBtn = (typeName == "Target Castbar")
            local isDivider = (typeName == "Divider")
            local isBigWidget = (typeName == "Dragonriding" or typeName == "Skill Stream" or typeName == "Target Castbar" or typeName == "Mythic+ Dashboard" or typeName == "Interrupt Sync" or typeName == "VaultEye" or typeName == "Cursor Ring" or typeName == "Retirement Home" or typeName == "Custom Code" or typeName == "CCPartySync" or typeName == "PrepChecker" or typeName == "Move Widget" or typeName == "Level Up Tracker")
            
            local isActive = false
            for _, e in ipairs(bar.elements) do 
                if e.type == typeName then isActive = true; break end 
            end
            
            local buttonLabel = typeName
            if typeName == "Mythic+ Dashboard" then
                buttonLabel = "M+ Dashboard"
            elseif typeName == "PrepChecker" then
                buttonLabel = "Preep Checker"
            elseif typeName == "CCPartySync" then
                buttonLabel = "CC Sync"
            end
            local btn = Skin:CreateButton(acc.content, buttonLabel, 115, 25) 
            btn:SetPoint("TOPLEFT", btnX, btnY)
            
            local function UpdateButtonStyle()
                if isDivider then
                    btn:SetBackdropColor(1, 0.8, 0, 1)
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn:SetBackdropBorderColor(0, 0, 0, 1)
                elseif isBigWidget then
                    if isActive then
                       btn:SetBackdropColor(0, 0.7, 0.7, 1); btn:SetBackdropBorderColor(0, 1, 1, 1)
                    else
                       btn:SetBackdropColor(unpack(Skin.Colors.button)); btn:SetBackdropBorderColor(unpack(Skin.Colors.border))
                    end
                    btn.text:SetTextColor(1, 1, 1, 1)
                elseif isActive then
                    btn:SetBackdropColor(0, 0.7, 1, 0.8) 
                    btn:SetBackdropBorderColor(0, 0.8, 1, 1)
                    btn.text:SetTextColor(1, 1, 1, 1)
                else
                    btn:SetBackdropColor(unpack(Skin.Colors.button)) 
                    btn:SetBackdropBorderColor(unpack(Skin.Colors.border)) 
                    btn.text:SetTextColor(1, 1, 1, 1)
                end
            end
            UpdateButtonStyle()
            
            btn:SetScript("OnEnter", function(self)
                if not self:IsEnabled() then return end
                
                if isDivider then
                    self:SetBackdropColor(1, 0.9, 0.2, 1)
                elseif isBigWidget then
                    if isActive then self:SetBackdropColor(0, 0.8, 0.8, 1)
                    else 
                        self:SetBackdropColor(unpack(Skin.Colors.buttonHover))
                        self:SetBackdropBorderColor(unpack(Skin.Colors.accent)) 
                    end
                elseif isActive then
                    self:SetBackdropColor(0.2, 0.8, 1, 0.9)
                else
                    self:SetBackdropColor(unpack(Skin.Colors.buttonHover))
                    self:SetBackdropBorderColor(unpack(Skin.Colors.accent)) 
                end
            end)
            
            btn:SetScript("OnLeave", function(self) UpdateButtonStyle() end)
            
            local canAdd = true
            local btnIsStrict = (typeName == "Dragonriding" or typeName == "Mythic+ Dashboard" or typeName == "Skill Stream" or typeName == "Target Castbar" or typeName == "Interrupt Sync" or typeName == "VaultEye" or typeName == "CCPartySync" or typeName == "PrepChecker" or typeName == "Move Widget" or typeName == "Level Up Tracker")
            local btnIsOverlay = OverlayTypes[typeName]
            local btnIsDivider = (typeName == "Divider")
            
            if barMode == "STRICT" then
                 if typeName ~= exclusiveType then canAdd = false end
            elseif barMode == "OVERLAY" then
                 if not btnIsOverlay then canAdd = false end
            elseif barMode == "STANDARD" then
                 if btnIsStrict or btnIsOverlay then canAdd = false end
            end
            
            if not canAdd then
                btn:SetEnabled(false); btn:SetAlpha(0.5)
            else
                btn:SetEnabled(true); btn:SetAlpha(1)
            end
            
            btn:SetScript("OnClick", function()
                if not canAdd then return end
                
                -- Divider için istisna eklendi (Toggle yapmaz, her zaman yeni ekler)
                if isActive and not isDivider then
                    for idx, el in ipairs(bar.elements) do
                        if el.type == typeName then
                             table.remove(bar.elements, idx)
                             break
                        end
                    end
                else
                    local newEl = { type = typeName, size = 14, color = {1, 1, 1, 1}, showIcon = true }
                    if isDragonBtn then
                         newEl.widgetWidth = 300; newEl.widgetHeight = 45
                         newEl.vigorFillColor = {0, 0.85, 0.85, 1}
                         newEl.speedBarColor = {0.7, 0, 0.7, 1}
                         newEl.speedTextColor = {1, 1, 1, 1}
                    elseif isSkillStreamBtn then
                         newEl.iconLimit = 5
                         newEl.iconSize = 32
                         newEl.spacing = 5
                         newEl.speed = 8
                         newEl.direction = "RIGHT_TO_LEFT"
                    elseif isTargetCastBtn then
                         newEl.widgetHeight = 30
                         newEl.colorReady = {1, 0.5, 0, 1}
                         newEl.colorCooldown = {1, 0, 0, 1}
                         newEl.colorShielded = {0.5, 0.5, 0.5, 1}
                         newEl.colorInterrupted = {0, 1, 0, 1}
                    elseif btnIsOverlay then
                         newEl.size = 32 
                    elseif typeName == "Mythic+ Dashboard" then
                         newEl.widgetWidth = 340
                         newEl.widgetHeight = 260
                    elseif typeName == "Custom Code" then
                         newEl.widgetWidth = 100
                         newEl.widgetHeight = 30
                         newEl.code = "return 'Hello World'"
                    elseif typeName == "Interrupt Sync" then
                         newEl.barWidth = 220
                         newEl.barHeight = 30
                         newEl.iconSize = 30
                         newEl.spacing = 5
                         newEl.barColor = {0, 1, 0, 1}
                         newEl.colorReady = {1.0, 0.72, 0.04, 1}
                         newEl.fontOutline = "OUTLINE"
                         newEl.announceInterrupts = false
                         newEl.announceChannel = "PARTY"
                    elseif typeName == "CCPartySync" then
                         newEl.barWidth = 220
                         newEl.barHeight = 30
                         newEl.iconSize = 30
                         newEl.spacing = 5
                         newEl.showIcon = true
                         newEl.colorReady = {0.2, 0.8, 1.0, 1}
                         newEl.colorOnCD = {1.0, 0.5, 0.0, 1}
                    elseif typeName == "VaultEye" then
                         newEl.widgetWidth = 250
                         newEl.widgetHeight = 150
                         newEl.trackMythicPlus = true
                         newEl.trackDelves = true
                         newEl.trackRaid = true
                         newEl.trackCurrencies = true
                          newEl.hoverExpand = true
                     elseif typeName == "PrepChecker" then
                          newEl.iconSize = 32
                          newEl.spacing = 4
                          newEl.direction = "LEFT_TO_RIGHT"
                          newEl.showFlask = true
                          newEl.showFood = true
                          newEl.showRune = true
                          newEl.showPotion = true
                          newEl.showHealthstone = true
                          newEl.showTrinket1 = true
                          newEl.showTrinket2 = true
                          newEl.showBorder = true
                          newEl.borderSize = 1
                          newEl.showCount = true
                          newEl.showLabel = false
                          newEl.iconZoom = 0.07
                          newEl.potionWarnBelow = 1
                          newEl.colorOk = {0.0, 1.0, 0.2, 1}
                          newEl.colorWarn = {1.0, 0.15, 0.15, 1}
                          newEl.colorNeutral = {0.4, 0.4, 0.8, 1}
                     elseif typeName == "Move Widget" then
                          newEl.savePosition = true
                     elseif typeName == "Level Up Tracker" then
                          newEl.widgetWidth = 320
                          newEl.widgetHeight = 64
                          newEl.fontSize = 12
                          newEl.font = "Righteous"
                          newEl.fontOutline = "OUTLINE"
                          newEl.textLayout = "SPLIT"
                          newEl.line1Role = "AUTO_TOP"
                          newEl.line2Role = "AUTO_BOTTOM"
                          newEl.textAnchorSpace = "PANEL"
                          newEl.topTextAnchor = "TOPLEFT"
                          newEl.topTextOffsetX = 0
                          newEl.topTextOffsetY = 0
                          newEl.bottomTextAnchor = "BOTTOMLEFT"
                          newEl.bottomTextOffsetX = 0
                          newEl.bottomTextOffsetY = 0
                          newEl.texture = "2. Smooth"
                          newEl.barHeight = 16
                          newEl.barOffsetY = 0
                          newEl.panelBgAlpha = 0
                          newEl.barBgAlpha = 0.12
                          newEl.showPanelBorder = true
                          newEl.panelBorderSize = 1
                          newEl.panelBorderColor = {0.18, 0.18, 0.18, 1}
                          newEl.showBarBorder = true
                          newEl.barBorderSize = 1
                          newEl.barBorderColor = {0.15, 0.15, 0.15, 1}
                          newEl.compactMode = false
                          newEl.showPercent = true
                          newEl.showRemainingXP = true
                          newEl.showRestedXP = true
                          newEl.showSessionTime = false
                          newEl.showTimeToLevel = false
                          newEl.showLastLevelUp = true
                          newEl.playSoundOnLevelUp = true
                          newEl.announceInChat = "OFF"
                          newEl.milestoneLevels = "10,20,30,40,50,60,70,80"
                          newEl.xpBarColor = {0.1, 0.7, 1.0, 1}
                          newEl.textColor = {1, 1, 1, 1}
                          newEl.flashColor = {1.0, 0.85, 0.2, 1}
                     elseif isDivider then
                          newEl.size = 20; newEl.thickness = 2; newEl.dividerMode = "LINE"; newEl.dividerStyle = "VERTICAL"; newEl.offset = 0
                    end
                    
                    table.insert(bar.elements, newEl)
                end
                
                Config:SelectBar(index)
                WidgetForge:UpdateAvailableBars()
                Config:SelectBar(index) 
            end)
            
            btnX = btnX + 121
            if i % 5 == 0 then
                btnX = 5
                btnY = btnY - 30
            end
        end
    end
    
    activeElementsFrame:SetHeight(math.max(1, #bar.elements * 35 + 10))
    Config.UpdateAccordionLayout() 
    
    local fontList = {}
    for k, v in pairs(Skin.Media.Fonts) do
        table.insert(fontList, {text = k, value = k, font = v})
    end
    local outlineList = { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick", value="THICKOUTLINE"}, {text="Mono", value="MONOCHROME"}, {text="Mono+Out", value="MONOCHROME,OUTLINE"} }

    Config.ElementRows = {}
    for i, elem in ipairs(bar.elements) do
        local displayType = elem.type
        if elem.type == "Mythic+ Dashboard" then
            displayType = "M+ Dashboard"
        elseif elem.type == "PrepChecker" then
            displayType = "Preep Checker"
        elseif elem.type == "CCPartySync" then
            displayType = "CC Sync"
        end
        local item = CreateFrame("Frame", nil, activeElementsFrame, "BackdropTemplate")
        item:SetSize(610, 32); item:SetPoint("TOPLEFT", 10, -((i-1) * 35))
        Skin:ApplyBackdrop(item, 0.3, 0.5)
        item.txt = item:CreateFontString(nil, "OVERLAY", "GameFontNormal"); item.txt:SetPoint("LEFT", 8, 0); item.txt:SetText(i..". "..displayType); item.txt:SetFont(Skin.Constants.FONT_NORMAL, 11, ""); item.txt:SetWidth(110); item.txt:SetJustifyH("LEFT")

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
                Config.DragGhost.text:SetFont(Skin.Constants.FONT_NORMAL, 11, "")
                Config.DragGhost.text:SetPoint("CENTER") 
            end
            Config.DragGhost.text:SetText(i .. ": " .. displayType)
            Config.DragGhost:Show() 
        end)

        dragHandle:SetScript("OnDragStop", function() 
            if Config.DragGhost then Config.DragGhost:Hide() end
            
            for _, line in ipairs(dragHandle.lines) do line:SetVertexColor(unpack(Skin.Colors.accent)) end
            for idx = 1, #Config.ElementRows do
                local row = Config.ElementRows[idx]
                if row then row:SetBackdropBorderColor(unpack(Skin.Colors.border)) end
            end

            if not dragHandle.dragSourceIndex then return end
            
            local sourceIdx = dragHandle.dragSourceIndex
            dragHandle.dragSourceIndex = nil
            
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
                
                for idx = 1, #Config.ElementRows do
                    local row = Config.ElementRows[idx]
                    if row then row:SetBackdropBorderColor(unpack(Skin.Colors.border)) end
                end
                
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
                    closestRow:SetBackdropBorderColor(1, 0.8, 0, 1) 
                end
            end
        end)
        
        local btnCol = CreateFrame("Button", nil, item, "BackdropTemplate"); btnCol:SetSize(20, 20); btnCol:SetPoint("RIGHT", dragHandle, "LEFT", -8, 0); Skin:ApplyBackdrop(btnCol); btnCol:SetBackdropColor(unpack(elem.color or {1, 1, 1, 1}))
        btnCol:SetScript("OnClick", function() local oldColor = elem.color or {1, 1, 1, 1}; local info = { r=oldColor[1], g=oldColor[2], b=oldColor[3], opacity=oldColor[4], swatchFunc = function(c) elem.color = c; btnCol:SetBackdropColor(unpack(c)); WidgetForge:RebuildBarComponents(index) end, cancelFunc = function() elem.color = oldColor; btnCol:SetBackdropColor(unpack(oldColor)); WidgetForge:RebuildBarComponents(index) end }; Skin:ShowColorPicker(info) end)
        
        local slSz, ddOutline, ddFont, chkIcon, chkTip, ddFmt, ddSep
        
        if elem.type == "Divider" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenElementSettings(index, i, elem) end)
        elseif elem.type == "Dragonriding" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenDragonridingSettings(index, i, elem) end)
        elseif elem.type == "Skill Stream" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenSkillStreamSettings(index, i, elem) end)
        elseif elem.type == "Target Castbar" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenTargetCastbarSettings(index, i, elem) end)
        elseif elem.type == "Custom Code" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCustomCodeSettings(index, i, elem) end)
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
                if Config.OpenMythicPlusSettings then Config:OpenMythicPlusSettings(index, i, elem) end 
             end)
        elseif elem.type == "Interrupt Sync" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenInterruptSyncSettings(index, i, elem) end)
        elseif elem.type == "VaultEye" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenVaultEyeSettings(index, i, elem) end)
        elseif elem.type == "CCPartySync" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCCPartySyncSettings(index, i, elem) end)
        elseif elem.type == "PrepChecker" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenPrepCheckerSettings(index, i, elem) end)
        elseif elem.type == "Level Up Tracker" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, "Settings", 80, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenLevelUpTrackerSettings(index, i, elem) end)
        elseif elem.type == "Move Widget" then
             btnCol:Hide()
             local btnReset = Skin:CreateButton(item, "Reset", 80, 22)
             btnReset:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnReset:SetScript("OnClick", function()
                 local ref = (_G.WidgetForge and _G.WidgetForge.MoveWidget)
                 if ref and ref.ResetPositions then
                     ref:ResetPositions()
                 end
             end)

             local chkSave = Skin:CreateCheckbox(item, "Save Position", elem.savePosition ~= false, function(v)
                  elem.savePosition = v
              end)
             chkSave:SetWidth(90)
             chkSave:SetPoint("RIGHT", btnReset, "LEFT", -8, 0)
             chkSave.box:SetSize(14, 14)
             chkSave.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "")
        else
            slSz = Skin:CreateSlider(item, 8, 50, 1, elem.size, function(v) elem.size = v; WidgetForge:RebuildBarComponents(index) end, 70); slSz:SetPoint("RIGHT", btnCol, "LEFT", -15, 0)
            ddOutline = Skin:CreateDropdown(item, 85, outlineList, elem.outline or "OUTLINE", function(v) elem.outline = v; WidgetForge:RebuildBarComponents(index) end); ddOutline:SetPoint("RIGHT", slSz, "LEFT", -10, 0) 
            local currentFontVal = elem.font or "Righteous"
            if Skin.Media and Skin.Media.Fonts and not Skin.Media.Fonts[currentFontVal] then
                for fontName, fontPath in pairs(Skin.Media.Fonts) do
                    if fontPath == currentFontVal then
                        currentFontVal = fontName
                        break
                    end
                end
            end
            ddFont = Skin:CreateDropdown(item, 100, fontList, currentFontVal, function(v)
                elem.font = v
                WidgetForge:RebuildBarComponents(index)
            end)
            ddFont:SetPoint("RIGHT", ddOutline, "LEFT", -10, 0)
            chkIcon = Skin:CreateCheckbox(item, "Icon", elem.showIcon, function(v) elem.showIcon = v; WidgetForge:RebuildBarComponents(index) end); chkIcon:SetWidth(45); chkIcon:SetPoint("RIGHT", ddFont, "LEFT", -5, 0); chkIcon.box:SetSize(14, 14); chkIcon.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "")
            chkTip = Skin:CreateCheckbox(item, "Tip", elem.showTooltip, function(v) elem.showTooltip = v; WidgetForge:RebuildBarComponents(index) end); chkTip:SetWidth(40); chkTip:SetPoint("RIGHT", chkIcon, "LEFT", -5, 0); chkTip.box:SetSize(14, 14); chkTip.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "") 
            item.chkIcon = chkIcon
            item.chkTip = chkTip
            Config:SetElementCheckboxDisabledVisual(chkTip, not not bar.clickThrough)
            
            if elem.type == "Clock" then 
                local fmtList = { {text="24h", value="24h"}, {text="12h", value="12h"} }; 
                ddFmt = Skin:CreateDropdown(item, 50, fmtList, elem.timeFormat or "24h", function(v) elem.timeFormat = v; WidgetForge:RebuildBarComponents(index) end); 
                ddFmt:SetPoint("RIGHT", chkTip, "LEFT", -5, 0) 
            elseif elem.type == "Gold" then
                local sepList = { {text="10,000", value="COMMA"}, {text="10.000", value="DOT"}, {text="10 000", value="SPACE"}, {text="10000", value="NONE"} }
                ddSep = Skin:CreateDropdown(item, 70, sepList, elem.separator or "COMMA", function(v) elem.separator = v; WidgetForge:RebuildBarComponents(index) end)
                ddSep:SetPoint("RIGHT", chkTip, "LEFT", -5, 0)
            end
        end
        y = y - 36 
    end
content:SetHeight(math.abs(y) + 20)
end

function Config:SetElementCheckboxDisabledVisual(chk, disabled)
    if not chk then return end
    if disabled then
        chk:SetAlpha(0.35)
        if chk.box then
            chk.box:EnableMouse(false)
            chk.box:SetBackdropColor(0.08, 0.08, 0.08, 1)
            chk.box:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        end
        if chk.check then chk.check:SetVertexColor(0.45, 0.45, 0.45, 1) end
        if chk.label then chk.label:SetTextColor(0.55, 0.55, 0.55, 1) end
    else
        chk:SetAlpha(1)
        if chk.box then
            chk.box:EnableMouse(true)
            chk.box:SetBackdropColor(0.15, 0.15, 0.15, 1)
            chk.box:SetBackdropBorderColor(unpack(Skin.Colors.border))
        end
        if chk.check then chk.check:SetVertexColor(unpack(Skin.Colors.accent)) end
        if chk.label then chk.label:SetTextColor(unpack(Skin.Colors.text)) end
    end
end

function Config:ApplyClickThroughToElementRows(bar)
    if not self.ElementRows or not bar then return end
    local disabled = not not bar.clickThrough
    for _, row in ipairs(self.ElementRows) do
        if row then
            self:SetElementCheckboxDisabledVisual(row.chkTip, disabled)
        end
    end
end

function Config:OpenElementSettings(barIndex, elemIndex, elem)
    local f = Config.ElementSettingsFrame
    if not f then
        f = CreateFrame("Frame", "ForgeElementSettings", UIParent, "BackdropTemplate")
        f:SetSize(250, 290)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG") 
        f:EnableMouse(true); f:SetMovable(true)
        Skin:ApplyBackdrop(f); f:SetBackdropColor(0.1, 0.1, 0.1, 0.95); Skin:SetSmartBorder(f, 2, {r=1, g=0.7, b=0, a=1}, "OUTSIDE")
        
        local title = Skin:CreateTitleBar(f, "Divider Settings", function() f:Hide() end)
        title:RegisterForDrag("LeftButton")
        title:SetScript("OnDragStart", function() f:StartMoving() end)
        title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    
        Config.ElementSettingsFrame = f
    else
        f:Show()
    end

    if not f.content then 
        f.content = CreateFrame("Frame", nil, f)
        f.content:SetAllPoints(f)
    else
        local kids = { f.content:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        
        local regions = { f.content:GetRegions() }
        for _, rgn in ipairs(regions) do rgn:Hide() end
    end
    
    local y = -50 
    local content = f.content

    local lblMode = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblMode:SetPoint("TOPLEFT", 20, y-5); lblMode:SetText("Mode:")
    local modeList = { {text="Graphic Line", value="LINE"}, {text="Text Character", value="TEXT"} }
    local ddMode = Skin:CreateDropdown(content, 120, modeList, elem.dividerMode or "LINE", function(v) 
        elem.dividerMode = v; 
        WidgetForge:RebuildBarComponents(barIndex)
        Config:OpenElementSettings(barIndex, elemIndex, elem) 
    end)
    ddMode:SetPoint("TOPLEFT", 100, y)
    
    y = y - 40

    local lblStyle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblStyle:SetPoint("TOPLEFT", 20, y-5); lblStyle:SetText("Style:")
    local styleList = { {text="Vertical", value="VERTICAL"}, {text="Horizontal", value="HORIZONTAL"} }
    
    local ddStyle = Skin:CreateDropdown(content, 85, styleList, elem.dividerStyle or "VERTICAL", function(v) 
        elem.dividerStyle = v 
        WidgetForge:RebuildBarComponents(barIndex)
    end)
    ddStyle:SetPoint("TOPLEFT", 100, y)

    if elem.dividerMode == "TEXT" then
        ddStyle:SetAlpha(0.5)
        ddStyle:EnableMouse(false) 
        lblStyle:SetTextColor(0.5, 0.5, 0.5)
    end

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
    btnCol:SetFrameStrata("FULLSCREEN_DIALOG") 
    btnCol:SetFrameLevel(ddStyle:GetFrameLevel() + 5) 

    y = y - 40

    if elem.dividerMode == "TEXT" then
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
        
        local lblSz = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblSz:SetPoint("TOPLEFT", 20, y-5); lblSz:SetText("Size:")
        local slSz = Skin:CreateSlider(content, 8, 72, 1, elem.size or 12, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slSz:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    else
        local lblLen = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblLen:SetPoint("TOPLEFT", 20, y-5); lblLen:SetText("Length:")
        local slLen = Skin:CreateSlider(content, 5, 200, 1, elem.size or 20, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slLen:SetPoint("TOPLEFT", 100, y)
        y = y - 40

        local lblThk = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblThk:SetPoint("TOPLEFT", 20, y-5); lblThk:SetText("Thickness:")
        local slThk = Skin:CreateSlider(content, 1, 20, 1, elem.thickness or 2, function(v) elem.thickness = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slThk:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    end

    local lblOff = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblOff:SetPoint("TOPLEFT", 20, y-5); lblOff:SetText("Offset:")
    local slOff = Skin:CreateSlider(content, -50, 50, 1, elem.offset or 0, function(v) elem.offset = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
    slOff:SetPoint("TOPLEFT", 100, y)
    y = y - 40
    
    local txtHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtHelp:SetPoint("TOP", 0, y - 5)
    txtHelp:SetText("Use Offset to nudge the Divider pos.")
    
    f:Show()
end

function Config:GetSlidePanel()
    if Config.SlidePanel then return Config.SlidePanel end
    
    local Skin = _G.ForgeSkin
    local parent = Config.Frame
    local panel = Skin:CreateSlidePanel(parent, 640, 550, {x = -9, y = -40})
    
    panel.onCloseHandler = function(self)
        Config:ToggleSlidePanel(false)
    end
    
    Config.SlidePanel = panel
    return panel
end

function Config:ToggleSlidePanel(show)
    local panel = Config:GetSlidePanel()
    local Skin = _G.ForgeSkin
    
    if show then
        local mainFrameName = Config.Frame and Config.Frame:GetName()
        if mainFrameName then
             for i=#UISpecialFrames, 1, -1 do
                 if UISpecialFrames[i] == mainFrameName then
                     table.remove(UISpecialFrames, i)
                 end
             end
        end
    else
        if Config.Frame then
            local mainFrameName = Config.Frame:GetName()
            if mainFrameName and not tContains(UISpecialFrames, mainFrameName) then
                table.insert(UISpecialFrames, mainFrameName)
            end
        end
        
        if panel.onCloseWidgetSpecific then
            panel.onCloseWidgetSpecific()
            panel.onCloseWidgetSpecific = nil
        end
    end
    
    Skin:ToggleSlidePanel(panel, show)
end

function Config:OpenCustomCodeSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Custom Code Settings")
    panel.config = elem
    panel.barIndex = barIndex
    
    if not wasShown and panel.scroll then panel.scroll:SetVerticalScroll(0) end
    
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    
    if panel.builder then 
        if panel.builder.Release then panel.builder:Release() end
        panel.builder = nil 
    end
    
    if _G.WidgetForge and _G.WidgetForge.CustomCode and _G.WidgetForge.CustomCode.CreateSettings then
        _G.WidgetForge.CustomCode:CreateSettings(panel)
    end
end

function Config:OpenDragonridingSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Dragonriding Settings")
    panel.config = elem
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.Dragonriding and _G.WidgetForge.Dragonriding.CreateSettings then
        _G.WidgetForge.Dragonriding:CreateSettings(panel)
    end
end

function Config:OpenSkillStreamSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Skill Stream Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.SkillStream and _G.WidgetForge.SkillStream.CreateSettings then
        _G.WidgetForge.SkillStream:CreateSettings(panel)
    end
end

function Config:OpenTargetCastbarSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Target Castbar Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.TargetCastbar and _G.WidgetForge.TargetCastbar.CreateSettings then
        _G.WidgetForge.TargetCastbar:CreateSettings(panel)
    end
end

function Config:OpenCursorRingSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Cursor Ring Settings")
    panel.config = elem
    panel.barIndex = barIndex 
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.CursorRing and _G.WidgetForge.CursorRing.CreateSettings then
        _G.WidgetForge.CursorRing:CreateSettings(panel)
    end
end

function Config:OpenRetirementHomeSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Retirement Home Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.RetirementHome and _G.WidgetForge.RetirementHome.CreateSettings then
        _G.WidgetForge.RetirementHome:CreateSettings(panel)
    end
end

function Config:OpenMythicPlusSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Mythic+ Dashboard Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.MythicPlus and _G.WidgetForge.MythicPlus.CreateSettings then
        _G.WidgetForge.MythicPlus:CreateSettings(panel)
    end
end

function Config:OpenInterruptSyncSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Interrupt Sync Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, rgn in ipairs(regions) do rgn:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.InterruptSync and _G.WidgetForge.InterruptSync.CreateSettings then
        _G.WidgetForge.InterruptSync:CreateSettings(panel)
    end
end

function Config:OpenVaultEyeSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("VaultEye Settings")
    panel.config = elem
    panel.barIndex = barIndex 
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.VaultEye and _G.WidgetForge.VaultEye.CreateSettings then
        _G.WidgetForge.VaultEye:CreateSettings(panel)
    end
end

function Config:OpenCCPartySyncSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("CC Party Sync Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.CCSync and _G.WidgetForge.CCSync.CreateSettings then
        _G.WidgetForge.CCSync:CreateSettings(panel)
    end
end

function Config:OpenPrepCheckerSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Prep Checker Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.PrepChecker and _G.WidgetForge.PrepChecker.CreateSettings then
        _G.WidgetForge.PrepChecker:CreateSettings(panel)
    end
end

function Config:OpenLevelUpTrackerSettings(barIndex, elemIndex, elem)
    local panel = Config:GetSlidePanel()
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText("Level Up Tracker Settings")
    panel.config = elem
    panel.barIndex = barIndex
    local content = panel.content
    local kids = {content:GetChildren()}
    for _, k in ipairs(kids) do k:Hide() end
    local regions = {content:GetRegions()}
    for _, r in ipairs(regions) do r:Hide() end
    if panel.builder then if panel.builder.Release then panel.builder:Release() end panel.builder = nil end
    if _G.WidgetForge and _G.WidgetForge.LevelUpTracker and _G.WidgetForge.LevelUpTracker.CreateSettings then
        _G.WidgetForge.LevelUpTracker:CreateSettings(panel)
    end
end

function Config:RegisterAddonSettingsPanel()
    if self.AddonSettingsPanel then return end

    local panel = CreateFrame("Frame", "WidgetForgeAddonSettingsPanel", UIParent)
    panel.name = "WidgetForge"
    self.AddonSettingsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("WidgetForge")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(620)
    desc:SetText("Commands:\n/wf - Opens WidgetForge config window.\n/wf help - Shows command help.")

    local minimapCheck = CreateFrame("CheckButton", "WidgetForgeMinimapToggle", panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    _G[minimapCheck:GetName() .. "Text"]:SetText("Enable minimap icon")

    local function refreshState()
        minimapCheck:SetChecked(WidgetForgeDB and WidgetForgeDB.showMinimapButton ~= false)
    end

    minimapCheck:SetScript("OnShow", refreshState)
    minimapCheck:SetScript("OnClick", function(self)
        if WidgetForge and WidgetForge.SetMinimapButtonEnabled then
            WidgetForge:SetMinimapButtonEnabled(self:GetChecked())
        else
            WidgetForgeDB.showMinimapButton = self:GetChecked() and true or false
        end
    end)

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(140, 24)
    openButton:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -10)
    openButton:SetText("Open WidgetForge")
    openButton:SetScript("OnClick", function()
        Config:OpenConfigWindow()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "WidgetForge")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

SLASH_WIDGETFORGE1 = "/wf"
SlashCmdList["WIDGETFORGE"] = function(msg)
    local input = string.lower((msg or ""):match("^%s*(.-)%s*$"))

    if input == "help" or input == "?" then
        print("|cff00ccffWidgetForge Commands|r")
        print("  |cff00ccff/wf|r - Open config window")
        print("  |cff00ccff/wf help|r - Show this help")
        print("  |cff00ccff/wf minimap on|r - Enable minimap icon")
        print("  |cff00ccff/wf minimap off|r - Disable minimap icon")
        return
    end

    if input == "minimap on" then
        if WidgetForge and WidgetForge.SetMinimapButtonEnabled then
            WidgetForge:SetMinimapButtonEnabled(true)
        end
        print("|cff00ccffWidgetForge|r minimap icon: |cff00ff00ON|r")
        return
    end

    if input == "minimap off" then
        if WidgetForge and WidgetForge.SetMinimapButtonEnabled then
            WidgetForge:SetMinimapButtonEnabled(false)
        end
        print("|cff00ccffWidgetForge|r minimap icon: |cffff0000OFF|r")
        return
    end

    Config:OpenConfigWindow()
end
