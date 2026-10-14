ForgeConfig = {}
local Config = ForgeConfig
local Skin = ForgeSkin
local L = WFL
local LE = WFL_ELEMENT
Config.Layout = {
    MAIN_DEFAULT_WIDTH = 1180,
    MAIN_DEFAULT_HEIGHT = 770,
    MAIN_MIN_WIDTH = 1140,
    MAIN_MIN_HEIGHT = 730,
    SIDEBAR_WIDTH = 250,
    MAIN_SECTION_WIDTH = 852,
    MAIN_SCROLL_WIDTH = 882,
    MAIN_SCROLL_HEIGHT = 646,
    SLIDE_PANEL_WIDTH = 882,
    SLIDE_PANEL_HEIGHT = 650,
}
function Config:GetSavedWindowSize()
    local layout = self.Layout
    local saved = WidgetForgeDB and WidgetForgeDB.configWindowSize
    if type(saved) ~= "table" then
        return layout.MAIN_DEFAULT_WIDTH, layout.MAIN_DEFAULT_HEIGHT
    end
    local width = tonumber(saved.width) or layout.MAIN_DEFAULT_WIDTH
    local height = tonumber(saved.height) or layout.MAIN_DEFAULT_HEIGHT
    width = math.max(layout.MAIN_MIN_WIDTH, math.floor(width + 0.5))
    height = math.max(layout.MAIN_MIN_HEIGHT, math.floor(height + 0.5))
    return width, height
end
function Config:SaveWindowSize(width, height)
    if not WidgetForgeDB then return end
    local layout = self.Layout
    WidgetForgeDB.configWindowSize = WidgetForgeDB.configWindowSize or {}
    WidgetForgeDB.configWindowSize.width = math.max(layout.MAIN_MIN_WIDTH, math.floor((tonumber(width) or layout.MAIN_DEFAULT_WIDTH) + 0.5))
    WidgetForgeDB.configWindowSize.height = math.max(layout.MAIN_MIN_HEIGHT, math.floor((tonumber(height) or layout.MAIN_DEFAULT_HEIGHT) + 0.5))
end
function Config:GetDetailsSectionWidth()
    local content = self.DetailsContent
    local measured = content and content.GetWidth and content:GetWidth() or 0
    if measured and measured > 200 then
        return math.max(720, math.floor(measured - 32))
    end
    return self.Layout.MAIN_SECTION_WIDTH
end
function Config:RefreshTourTargetButtons()
    local targets = {
        { self.TourAddBarButton, "BUTTON_NEW_EMPTY_BAR" },
        { self.TourImportButton, "BUTTON_IMPORT_PROFILE" },
        { self.TourExportButton, "BUTTON_EXPORT_PROFILE" },
    }
    for _, info in ipairs(targets) do
        local button, key = info[1], info[2]
        if button and button.text then
            button.text:SetText(L(key))
            button.text:SetTextColor(unpack(Skin.Colors.text))
            button.text:SetAlpha(1)
            button.text:Show()
            if button.RefreshFont then
                button:RefreshFont()
            end
        end
    end
end
function Config:QueueTourTargetButtonRefresh()
    if not C_Timer then
        self:RefreshTourTargetButtons()
        return
    end
    local refreshDelays = { 0, 0.10, 0.35, 0.60 }
    for _, delay in ipairs(refreshDelays) do
        C_Timer.After(delay, function()
            if Config.Frame and Config.Frame.IsShown and Config.Frame:IsShown() then
                Config:RefreshTourTargetButtons()
            end
        end)
    end
end
function Config:RefreshWindowLayout()
    if self.BarListScroll and self.BarListScroll.RefreshLayout then
        self.BarListScroll:RefreshLayout()
    end
    if self.DetailsScroll and self.DetailsScroll.RefreshLayout then
        self.DetailsScroll:RefreshLayout()
    end
    if self.SlidePanel and self.MainPanel then
        self.SlidePanel:SetContentBounds(
            self.MainPanel:GetWidth(),
            self.MainPanel:GetHeight(),
            self.MainPanel,
            0,
            0
        )
        self:ScheduleSlidePanelRefresh()
    end
    self:ScheduleSelectedBarRefresh()
end
Config.DefaultSettings = {
    globalScale = 1.0,
    bars = {
        [1] = {
            name = L("DEFAULT_BAR_MAIN_INFO"),
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
                [3] = { type = "Clock", label = L("DEFAULT_LABEL_TIME"), color = {1,0.8,0,1}, font="Righteous", size=14, outline="OUTLINE" }
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
    "Dragonriding", "Skill Stream", "Guild", "Friends", "Difficulty", "Target Castbar", "Castbar", "Talent Loadout", "Custom Code", 
    "Interrupt Sync", "VaultEye", "CCPartySync", "Party Defensives & Utility", "PrepChecker", "Move Widget", "Level Up Tracker"
}
Config.Presets = {
    { text = L("PRESET_GENERAL_STATS"), value = {
        name = L("PRESET_ESSENTIALS"), width = 250, height = 30, bgColor = {0,0,0,0.5}, layout="HORIZONTAL", padding=8,
        elements = {
            {type="FPS", size=12, color={1,1,1,1}, showIcon=true}, 
            {type="MS", size=12, color={1,1,1,1}, showIcon=true}, 
            {type="Clock", size=12, color={1,0.8,0,1}, showIcon=true},
            {type="Durability", size=12, color={0,1,0,1}, showIcon=true}
        }
    }},
    { text = L("PRESET_DPS_HEALER_CORE"), value = {
        name = L("PRESET_COMBAT_STATS"), width = 120, height = 140, bgColor = {0,0,0,0.6}, layout="VERTICAL", padding=6,
        elements = {
            {type="Main Stat", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Crit", size=12, color={1,0.5,0,1}, showIcon=true}, 
            {type="Haste", size=12, color={1,1,0,1}, showIcon=true}, 
            {type="Mastery", size=12, color={0.5,0,1,1}, showIcon=true}
        }
    }},
    { text = L("PRESET_TANK_SURVIVABILITY"), value = {
        name = L("PRESET_TANK_STATS"), width = 320, height = 40, bgColor = {0.1,0.1,0.1,0.8}, layout="HORIZONTAL", padding=12,
        elements = {
            {type="Stamina", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Versatility", size=14, color={1,1,1,1}, showIcon=true}, 
            {type="Avoidance", size=14, color={1,1,1,1}, showIcon=true},
            {type="Main Stat", size=14, color={1,1,1,1}, showIcon=true} 
        }
    }},
    { text = L("PRESET_LEVELING_FARM"), value = {
        name = L("PRESET_ADVENTURE"), width = 220, height = 80, bgColor = {0,0,0,0.5}, layout="VERTICAL", padding=5,
        elements = {
            {type="XP", size=12, color={0,0.8,1,1}, showIcon=true}, 
            {type="Gold", size=12, color={1,1,0,1}, showIcon=true}, 
            {type="Bag Space", size=12, color={1,1,1,1}, showIcon=true},
            {type="Item Level", size=12, color={1,0.5,1,1}, showIcon=true}
        }
    }}
}
function Config:OpenConfigWindow()
    if Config.Frame then
        Config.Frame:Show()
        Config:QueueTourTargetButtonRefresh()
        if _G.WidgetForgeTour and _G.WidgetForgeTour.HandleConfigOpened then
            C_Timer.After(0.2, function()
                if _G.WidgetForgeTour then
                    _G.WidgetForgeTour:HandleConfigOpened()
                end
            end)
        end
        return
    end
    local layout = Config.Layout
    local savedWidth, savedHeight = Config:GetSavedWindowSize()
    local f = CreateFrame("Frame", "EsrefConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(savedWidth, savedHeight)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    Skin:ApplyBackdrop(f)
    tinsert(UISpecialFrames, "EsrefConfigFrame")
    f:SetResizable(true)
    f:SetResizeBounds(layout.MAIN_MIN_WIDTH, layout.MAIN_MIN_HEIGHT)
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
        Config:SaveWindowSize(f:GetWidth(), f:GetHeight())
        Config:RefreshWindowLayout()
        if Config.SelectedBarIndex then
            Config:SelectBar(Config.SelectedBarIndex)
        end
    end)
    Skin:CreateTitleBar(f, L("CONFIG_TITLE"), function() f:Hide() end)
    f:SetScript("OnShow", function() WidgetForge:SetBarsLocked(false) end)
    f:SetScript("OnHide", function() 
        WidgetForge:SetBarsLocked(true) 
        Config:ToggleSlidePanel(false) 
        if _G.WidgetForgeTour and _G.WidgetForgeTour.HandleConfigClosed then
            _G.WidgetForgeTour:HandleConfigClosed()
        end
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
    local outerPad = 12
    local panelGap = 12
    local sidebarBottomInset = 93
    local mainPanelBottomInset = 58
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", outerPad, -42)
    sidebar:SetPoint("BOTTOMLEFT", outerPad, sidebarBottomInset) 
    sidebar:SetWidth(layout.SIDEBAR_WIDTH)
    Skin:ApplyBackdrop(sidebar, 0.4, 0.8)
    Config.TourSidebar = sidebar
    local sbHeader = Skin:CreateSectionHeader(sidebar, L("SECTION_ACTIVE_BARS"), layout.SIDEBAR_WIDTH - 20)
    sbHeader:SetPoint("TOPLEFT", 12, -12) 
    local scrollBarList, contentBarList = Skin:CreateScrollFrame(sidebar, layout.SIDEBAR_WIDTH - 20, 500)
    scrollBarList:SetPoint("TOPLEFT", 12, -52) 
    scrollBarList:SetPoint("BOTTOMRIGHT", -4, 12) 
    Config.BarListContent = contentBarList
    Config.BarListScroll = scrollBarList
    local btnAdd = Skin:CreateButton(f, L("BUTTON_NEW_EMPTY_BAR"), layout.SIDEBAR_WIDTH, 25)
    btnAdd:SetPoint("TOPLEFT", sidebar, "BOTTOMLEFT", 0, -10)
    Config.TourAddBarButton = btnAdd
    btnAdd:SetScript("OnClick", function()
        Config:ToggleSlidePanel(false) 
        local newId = #WidgetForgeDB.bars + 1
        WidgetForgeDB.bars[newId] = CopyTable(Config.DefaultSettings.bars[1])
        WidgetForgeDB.bars[newId].name = L("NEW_BAR_NAME", newId)
        WidgetForgeDB.bars[newId].scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }
        Config:RefreshBarList()
        Config:SelectBar(newId)
        WidgetForge:UpdateAvailableBars()
    end)
    local ddPreset 
    local lblPreset = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPreset:SetText(L("LABEL_QUICK_ADD_PRESET"))
    lblPreset:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
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
    ddPreset = Skin:CreateDropdown(f, 193, GetPresetList(), function(val)
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
    ddPreset:SetPoint("TOPLEFT", btnAdd, "BOTTOMLEFT", 0, -19)
    lblPreset:SetPoint("BOTTOMLEFT", ddPreset, "TOPLEFT", 0, 3)
    f.ddPreset = ddPreset 
    Config.TourPresetDropdown = ddPreset
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
        Skin:CreateInputDialog(L("DIALOG_SAVE_PRESET_TITLE"), WidgetForgeDB.bars[selIndex].name, function(text)
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
        if not WidgetForgeDB.presets or not next(WidgetForgeDB.presets) then print("|cffff0000" .. L("MSG_NO_CUSTOM_PRESETS") .. "|r"); return end
        local customList = {}
        for name, _ in pairs(WidgetForgeDB.presets) do table.insert(customList, {text = name, value = name}) end
        local deleteFrame = CreateFrame("Frame", "ForgeDeletePresetDialog", UIParent, "BackdropTemplate")
        deleteFrame:SetSize(350, 140)
        deleteFrame:SetPoint("CENTER")
        deleteFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        deleteFrame:EnableMouse(true); deleteFrame:SetMovable(true)
        deleteFrame:RegisterForDrag("LeftButton"); deleteFrame:SetScript("OnDragStart", deleteFrame.StartMoving); deleteFrame:SetScript("OnDragStop", deleteFrame.StopMovingOrSizing)
        Skin:ApplyBackdrop(deleteFrame); deleteFrame:SetBackdropColor(unpack(Skin.Colors.bg)); Skin:SetSmartBorder(deleteFrame, 2, {r=1, g=0.3, b=0.3, a=1}, "OUTSIDE")
        Skin:CreateTitleBar(deleteFrame, L("DIALOG_DELETE_PRESET_TITLE"), function() deleteFrame:Hide() end)
        local ddDelete = Skin:CreateDropdown(deleteFrame, 310, customList, function(presetName)
            Skin:CreateConfirmDialog(L("DIALOG_CONFIRM_DELETE_TITLE"), L("DIALOG_CONFIRM_DELETE_PRESET", presetName), function()
                    WidgetForgeDB.presets[presetName] = nil
                    print("|cffff0000" .. L("MSG_PRESET_DELETED") .. "|r")
                    ddPreset:SetList(GetPresetList()); ddPreset:SetValue(nil, L("SELECT_GENERIC"))
                    deleteFrame:Hide()
            end)
        end)
        ddDelete:SetPoint("TOP", 0, -50)
        deleteFrame:Show()
    end)
    local btnExport = Skin:CreateButton(f, L("BUTTON_EXPORT_PROFILE"), 128, 25)
    btnExport:SetPoint("BOTTOMRIGHT", -outerPad, 14)
    Config.TourExportButton = btnExport
    btnExport:SetScript("OnClick", function()
        local str = WidgetForgeUtils:Serialize(WidgetForgeDB)
        Skin:CreateTextWindow(L("WINDOW_EXPORT_PROFILE_DATA"), str, nil)
    end)
    local btnImport = Skin:CreateButton(f, L("BUTTON_IMPORT_PROFILE"), 128, 25)
    btnImport:SetPoint("RIGHT", btnExport, "LEFT", -10, 0)
    Config.TourImportButton = btnImport
    btnImport:SetScript("OnClick", function()
        Skin:CreateTextWindow(L("WINDOW_IMPORT_PROFILE_DATA"), "", function(text)
            local t = WidgetForgeUtils:Deserialize(text)
            if t and t.bars then
                Config:ToggleSlidePanel(false) 
                WidgetForgeDB = t
                Config:RefreshBarList()
                WidgetForge:UpdateAvailableBars()
                print("|cff00ff00" .. L("MSG_PROFILE_IMPORTED") .. "|r")
                Config.DetailsContent:HideAllChildren()
            else print("|cffff0000" .. L("MSG_PROFILE_INVALID") .. "|r") end
        end)
    end)
    local mainPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    mainPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", panelGap, 0)
    mainPanel:SetPoint("BOTTOMRIGHT", -outerPad, mainPanelBottomInset)
    Skin:ApplyBackdrop(mainPanel, 0.2, 0.5)
    Config.MainPanel = mainPanel
    Config.TourMainPanel = mainPanel
    local scrollDetails, contentDetails = Skin:CreateScrollFrame(mainPanel, layout.MAIN_SCROLL_WIDTH, layout.MAIN_SCROLL_HEIGHT)
    scrollDetails:SetPoint("TOPLEFT", 12, -12)
    scrollDetails:SetPoint("BOTTOMRIGHT", -7, 12)
    Config.DetailsScroll = scrollDetails
    function contentDetails:HideAllChildren()
        local kids = {self:GetChildren()}
        for _, k in ipairs(kids) do k:Hide() end
        local regions = {self:GetRegions()}
        for _, r in ipairs(regions) do r:Hide() end
    end
    Config.DetailsContent = contentDetails
    Config.Frame = f
    f:SetScript("OnSizeChanged", function()
        Config:RefreshWindowLayout()
    end)
    Config:RefreshWindowLayout()
    Config:RefreshBarList()
    Config:QueueTourTargetButtonRefresh()
    if _G.WidgetForgeTour and _G.WidgetForgeTour.HandleConfigOpened then
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour then
                _G.WidgetForgeTour:HandleConfigOpened()
            end
        end)
    end
end
function Config:RefreshBarList()
    local content = Config.BarListContent
    if content.buttons then for _, b in pairs(content.buttons) do b:Hide() end end
    content.buttons = {}
    local y = -5
    local listWidth = (content.GetWidth and content:GetWidth() or 0)
    if not listWidth or listWidth <= 0 then
        listWidth = Config.Layout.SIDEBAR_WIDTH - 40
    end
    local buttonWidth = math.max(180, math.floor(listWidth - 8))
    local textWidth = math.max(120, buttonWidth - 36)
    for i, bar in ipairs(WidgetForgeDB.bars) do
        local showInList = WidgetForge:IsBarRelevant(bar) 
        if showInList then
            local suffix = ""
            if not bar.scope then suffix = " |cffcccccc[Global]|r"
            elseif bar.scope.type == "CHARACTER" then suffix = " |cff00ff00[Char]|r"
            elseif bar.scope.type == "SPEC" then suffix = " |cffffaa00[Spec]|r" end
            local btn = Skin:CreateButton(content, bar.name .. suffix, buttonWidth, 30)
            btn:SetPoint("TOPLEFT", 2, y) 
            if btn.text then
                btn.text:ClearAllPoints()
                btn.text:SetPoint("LEFT", 10, 0)
                btn.text:SetWidth(textWidth)
                btn.text:SetJustifyH("LEFT")
            end
            btn:SetScript("OnMouseDown", function(self)
                if self.IsEnabled and not self:IsEnabled() then return end
                if self.text then
                    self.text:ClearAllPoints()
                    self.text:SetPoint("LEFT", 11, -1)
                    self.text:SetWidth(textWidth)
                    self.text:SetJustifyH("LEFT")
                end
            end)
            btn:SetScript("OnMouseUp", function(self)
                if self.text then
                    self.text:ClearAllPoints()
                    self.text:SetPoint("LEFT", 10, 0)
                    self.text:SetWidth(textWidth)
                    self.text:SetJustifyH("LEFT")
                end
            end)
            local btnDel = CreateFrame("Button", nil, btn)
            btnDel:SetSize(20, 20)
            btnDel:SetPoint("RIGHT", -5, 0)
            local icon = btnDel:CreateTexture(nil, "OVERLAY")
            icon:SetSize(18, 18)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\AddOns\\WidgetForge\\media\\close.tga")
            icon:SetVertexColor(1, 1, 1, 1)
            local function UpdateBarButtonVisuals()
                local isSelected = (i == Config.SelectedBarIndex)
                local isHovered = btn.isPointerOverRow or btn.isPointerOverDelete
                if isSelected then
                    btn:SetBackdropColor(0, 0.7, 1, 0.4)
                    btn:SetBackdropBorderColor(0, 0.8, 1, 1)
                elseif isHovered then
                    btn:SetBackdropColor(unpack(Skin.Colors.buttonHover))
                    btn:SetBackdropBorderColor(unpack(Skin.Colors.accent))
                else
                    btn:SetBackdropColor(unpack(Skin.Colors.button))
                    btn:SetBackdropBorderColor(unpack(Skin.Colors.border))
                end
                if btn.isPointerOverDelete then
                    icon:SetVertexColor(1, 0.2, 0.2, 1)
                else
                    icon:SetVertexColor(1, 1, 1, 1)
                end
            end
            local function RefreshPointerState()
                btn.isPointerOverRow = btn:IsMouseOver()
                btn.isPointerOverDelete = btnDel:IsMouseOver()
                UpdateBarButtonVisuals()
            end
            btn:SetScript("OnEnter", function(self)
                if self.IsEnabled and not self:IsEnabled() then return end
                self.isPointerOverRow = true
                UpdateBarButtonVisuals()
            end)
            btn:SetScript("OnLeave", function(self)
                if self.IsEnabled and not self:IsEnabled() then return end
                C_Timer.After(0, function()
                    if btn and btn:IsShown() then
                        RefreshPointerState()
                    end
                end)
            end)
            btn:SetScript("OnClick", function() Config:SelectBar(i) end)
            btnDel:SetScript("OnEnter", function()
                btn.isPointerOverDelete = true
                btn.isPointerOverRow = true
                UpdateBarButtonVisuals()
            end)
            btnDel:SetScript("OnLeave", function()
                C_Timer.After(0, function()
                    if btn and btn:IsShown() then
                        RefreshPointerState()
                    end
                end)
            end)
            btnDel:SetScript("OnClick", function() 
                Config:ToggleSlidePanel(false) 
                table.remove(WidgetForgeDB.bars, i)
                Config.SelectedBarIndex = nil 
                Config:RefreshBarList()
                Config.DetailsContent:HideAllChildren()
                WidgetForge:UpdateAvailableBars()
            end)
            UpdateBarButtonVisuals()
            table.insert(content.buttons, btn)
            y = y - 36
        end
    end
    content:SetHeight(math.max(1, math.abs(y) + 8))
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
    local sectionW = Config:GetDetailsSectionWidth()
    if not bar.elements then bar.elements = {} end
    local isExclusive = false
    local exclusiveType = nil
    for _, e in ipairs(bar.elements) do
        if e.type == "Dragonriding" or e.type == "Cursor Ring" or e.type == "Retirement Home" or e.type == "Mythic+ Dashboard" or e.type == "Skill Stream" or e.type == "Target Castbar" or e.type == "Castbar" or e.type == "Interrupt Sync" or e.type == "VaultEye" or e.type == "CCPartySync" or e.type == "Party Defensives & Utility" or e.type == "PrepChecker" or e.type == "Move Widget" or e.type == "Level Up Tracker" then 
            isExclusive = true
            exclusiveType = e.type
            break 
        end
    end
    local y = -0
    local hLayout
    if not isExclusive then
        hLayout = Skin:CreateSectionHeader(content, L("SECTION_BAR_LAYOUT", bar.name), sectionW)
    else
        hLayout = Skin:CreateSectionHeader(content, L("SECTION_BAR_LAYOUT_LOCKED", bar.name), sectionW)
        if hLayout.text then hLayout.text:SetTextColor(1, 0.3, 0.3, 1) end
    end
    hLayout:SetPoint("TOPLEFT", 12, y)
    local btnEnable = Skin:CreateSwitch(content, "", bar.enabled, function(val)
        bar.enabled = val
        WidgetForge:UpdateAvailableBars() 
    end, "ON", "OFF")
    btnEnable:SetWidth(54)
    btnEnable:SetPoint("TOPRIGHT", hLayout, "TOPRIGHT", -2, 2) 
    local scopeList = {
        {text = L("OPTION_GLOBAL_ACCOUNT"), value = "GLOBAL"},
        {text = L("OPTION_THIS_CHARACTER"), value = "CHARACTER"},
        {text = L("OPTION_CURRENT_SPEC"), value = "SPEC"}
    }
    local currentScopeVal = "GLOBAL"
    if bar.scope then currentScopeVal = bar.scope.type end
    local ddScope = Skin:CreateDropdown(content, 196, scopeList, currentScopeVal, function(v)
        if v == "GLOBAL" then
            bar.scope = nil
        elseif v == "CHARACTER" then
            bar.scope = { type = "CHARACTER", value = UnitName("player") .. "-" .. GetRealmName() }
        elseif v == "SPEC" then
            local spec = GetSpecialization()
            if spec then
                 bar.scope = { type = "SPEC", value = GetSpecializationInfo(spec), character = UnitName("player") .. "-" .. GetRealmName() }
            else print("|cffff0000WidgetForge|r " .. L("ERR_NO_SPEC_ACTIVE")); return end
        end
        WidgetForge:UpdateAvailableBars()
        Config:RefreshBarList() 
    end)
    ddScope:SetPoint("RIGHT", btnEnable, "LEFT", -5, 0)
    y = y - 40
    local rowStartX = 10
    local rowEndX = 10 + sectionW
    local rowTop = y - 4
    local colGap = 16
    local labelGap = 8
    local nameLabelW = 60
    local visLabelW = 100
    local layerLabelW = 70
    local nameW = math.max(220, math.min(300, math.floor(sectionW * 0.31)))
    local visW = math.max(140, math.min(180, math.floor(sectionW * 0.20)))
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
    ebName:SetAllPoints(ebNameFrame); ebName:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
    ebName:SetTextInsets(5, 5, 0, 0); ebName:SetAutoFocus(false); ebName:SetText(bar.name)
    ebName:SetMaxLetters(40) 
    ebName:SetScript("OnEnterPressed", function(self) 
        bar.name = self:GetText(); if hLayout.text then hLayout.text:SetText(string.upper(L("SECTION_BAR_LAYOUT", bar.name))) end
        Config:RefreshBarList(); self:ClearFocus() 
    end)
    ebName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local lblName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblName:SetWidth(nameLabelW)
    lblName:SetJustifyH("LEFT")
    lblName:SetPoint("LEFT", ebNameFrame, "LEFT", -(nameLabelW + labelGap), 0)
    lblName:SetText(L("LABEL_NAME"))
    lblName:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
    local lblVis = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblVis:SetWidth(visLabelW)
    lblVis:SetJustifyH("RIGHT")
    lblVis:SetText(L("LABEL_VISIBILITY"))
    lblVis:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
    local visList = {
        {text = L("OPTION_ALWAYS_SHOW"), value = "ALWAYS"},
        {text = L("OPTION_COMBAT_ONLY"), value = "COMBAT"},
        {text = L("OPTION_OUT_OF_COMBAT"), value = "OUT_OF_COMBAT"}
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
    lblLayer:SetText(L("LABEL_LAYER"))
    lblLayer:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
    local layerList = {
        {text = L("OPTION_LAYER_BACKGROUND"), value = "BACKGROUND"},
        {text = L("OPTION_LAYER_LOW"), value = "LOW"},
        {text = L("OPTION_LAYER_MEDIUM"), value = "MEDIUM"},
        {text = L("OPTION_LAYER_HIGH"), value = "HIGH"},
        {text = L("OPTION_LAYER_DIALOG"), value = "DIALOG"},
        {text = L("OPTION_LAYER_FULLSCREEN"), value = "FULLSCREEN"},
        {text = L("OPTION_LAYER_TOOLTIP"), value = "TOOLTIP"}
    }
    local currentLayerVal = bar.layer or "DIALOG"
    local ddLayer = Skin:CreateDropdown(content, layerW, layerList, currentLayerVal, function(v)
        bar.layer = v
        WidgetForge:UpdateAvailableBars()
    end)
    ddLayer:SetPoint("TOPLEFT", layerBoxX, rowTop)
    lblLayer:SetPoint("RIGHT", ddLayer, "LEFT", -labelGap, 0)
    local settingsContentH = 610
    if isExclusive then settingsContentH = 150 end
    local settingsAcc = Skin:CreateAccordion(content, L("SECTION_BAR_CONFIGURATION"), settingsContentH, function(expanded)
        Config.SettingsAccordionExpanded = expanded
        if Config.UpdateAccordionLayout then Config.UpdateAccordionLayout() end
    end, sectionW)
    settingsAcc.onAnimUpdate = function() if Config.UpdateAccordionLayout then Config.UpdateAccordionLayout() end end
    if Config.SettingsAccordionExpanded == nil then Config.SettingsAccordionExpanded = false end
    settingsAcc:SetExpanded(Config.SettingsAccordionExpanded)
    Config.TourSettingsAccordion = settingsAcc
    if exclusiveType == "Cursor Ring" or exclusiveType == "Retirement Home" or exclusiveType == "Move Widget" then
        settingsAcc:Hide()
    end
    local settingsSep = Skin:CreateSeparator(content, sectionW)
    settingsSep:Hide()
    if Config.mainBuilder then Config.mainBuilder:Release() end
    local sb = WidgetForgeUtils:CreateSettingsBuilder(settingsAcc.content)
    Config.mainBuilder = sb
    sb.y = -10 
    if not isExclusive then
        sb:AddHeader(L("HEADER_BAR_LAYOUT_STYLING"))
        sb:AddSwitch("showTitle", L("LABEL_SHOW_TITLE_BAR"), false, bar, function(v) WidgetForge:RebuildBarComponents(index) end)
        bar.isVertical = (bar.layout == "VERTICAL")
        sb:AddSwitch("isVertical", L("LABEL_VERTICAL_LAYOUT"), false, bar, function(v) 
             bar.layout = v and "VERTICAL" or "HORIZONTAL"
            WidgetForge:UpdateAvailableBars()
        end)
        sb:AddDropdown("justify", L("LABEL_ALIGNMENT"), {
            { text = L("LABEL_LEFT"), value = "LEFT" },
            { text = L("LABEL_CENTER"), value = "CENTER" },
            { text = L("LABEL_RIGHT"), value = "RIGHT" },
        }, "CENTER", bar, function(v) WidgetForge:RebuildBarComponents(index) end)
        sb:AddSlider("padding", L("LABEL_SPACING"), -10, 50, 1, 5, bar, function(v) WidgetForge:UpdateAvailableBars() end)
    end
    if exclusiveType ~= "Cursor Ring" and exclusiveType ~= "Retirement Home" and exclusiveType ~= "Move Widget" then
        sb:AddHeader(L("HEADER_POSITION"))
        sb:AddSlider("x", L("LABEL_X_OFFSET"), -math.floor(GetScreenWidth()/2), math.floor(GetScreenWidth()/2), 1, 0, bar, function(v) 
            if Config.isUpdatingScale then return end
            WidgetForge:UpdateAvailableBars() 
        end)
        Config.slX = sb.controls[#sb.controls] 
        sb:AddSlider("y", L("LABEL_Y_OFFSET"), -math.floor(GetScreenHeight()/2), math.floor(GetScreenHeight()/2), 1, 0, bar, function(v) 
            if Config.isUpdatingScale then return end
            WidgetForge:UpdateAvailableBars() 
        end)
        Config.slY = sb.controls[#sb.controls] 
    end
    if not isExclusive then
        sb:AddHeader(L("HEADER_BACKGROUND_SETTINGS"))
        sb:AddSlider("width", L("LABEL_WIDTH"), 50, 600, 5, 250, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddSlider("height", L("LABEL_HEIGHT"), 10, 200, 2, 30, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddColor("bgColor", L("LABEL_BACKGROUND_COLOR"), {0, 0, 0, 0.5}, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        local clickThroughSwitch = sb:AddSwitch("clickThrough", L("LABEL_CLICK_THROUGH"), false, bar, function(v) 
            WidgetForge:SetBarsLocked(false) 
            WidgetForge:SetBarsLocked(WidgetForge.BarsLocked)
            Config:ApplyClickThroughToElementRows(bar)
        end)
        Config.TourClickThroughSwitch = clickThroughSwitch
        sb:AddHeader(L("HEADER_BORDER_SETTINGS"))
        sb:AddSwitch("showBorder", L("LABEL_SHOW_BORDER"), true, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddSlider("borderSize", L("LABEL_BORDER_SIZE"), 1, 10, 1, 1, bar, function(v) WidgetForge:UpdateAvailableBars() end)
        sb:AddColor("borderColor", L("LABEL_BORDER_COLOR"), {0.2, 0.2, 0.2, 1}, bar, function(v) WidgetForge:UpdateAvailableBars() end)
    end
    sb:Finish()
    settingsAcc:SetContentHeight(settingsAcc.content:GetHeight())
    local MasterY = y - 40
    local headEl = Skin:CreateSectionHeader(content, L("SECTION_BAR_ELEMENTS"), sectionW)
    Config.TourElementsHeader = headEl
    local barMode = "EMPTY"
    local OverlayTypes = { ["Cursor Ring"] = true, ["Retirement Home"] = true }
    if bar.elements and #bar.elements > 0 then
        barMode = "STANDARD"
        for _, e in ipairs(bar.elements) do
            if e.type == "Dragonriding" or e.type == "Mythic+ Dashboard" or e.type == "Skill Stream" or e.type == "Target Castbar" or e.type == "Castbar" or e.type == "Interrupt Sync" or e.type == "VaultEye" or e.type == "CCPartySync" or e.type == "Party Defensives & Utility" or e.type == "PrepChecker" or e.type == "Move Widget" or e.type == "Level Up Tracker" then 
                barMode = "STRICT"
                break 
            elseif OverlayTypes[e.type] then
                barMode = "OVERLAY"
            end
        end
    end
    local categories = {
        { name = L("CATEGORY_SYSTEM_PERFORMANCE"), elements = { "FPS", "MS", "Clock" } },
        { name = L("CATEGORY_PLAYER_STATS"), elements = { "Main Stat", "Stamina", "Crit", "Haste", "Mastery", "Versatility", "Avoidance", "Leech", "Speed", "Run Speed", "Dodge", "Parry", "Armor", "Max HP" } },
        { name = L("CATEGORY_PROGRESSION_GOODS"), elements = { "XP", "Gold", "Bag Space", "Item Level", "Durability" } },
        { name = L("CATEGORY_NAVIGATION"), elements = { "Zone", "Coords" } },
        { name = L("CATEGORY_SOCIAL"), elements = { "Guild", "Friends" } },
        { name = L("CATEGORY_DUNGEON_RAID"), elements = { "Mythic+ Dashboard", "Target Castbar", "Castbar", "Interrupt Sync", "CCPartySync", "Party Defensives & Utility", "PrepChecker", "Combat Timer", "Difficulty" } },
        { name = L("CATEGORY_UTILS"), elements = { "Dragonriding", "Cursor Ring", "Retirement Home", "Skill Stream", "VaultEye", "Move Widget", "Level Up Tracker", "Talent Loadout", "Custom Code" } }
    }
    Config.AccordionStates = Config.AccordionStates or {} 
    local accFrameList = {}
    Config.TourElementAccordions = accFrameList
    local activeElementsFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    activeElementsFrame:SetWidth(sectionW)
    activeElementsFrame:SetHeight(1) 
    local listSeparator = Skin:CreateSeparator(content, sectionW) 
    local ddFilter
    local filterWidth = math.max(220, math.min(280, math.floor(sectionW * 0.28)))
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
        if ddFilter then ddFilter:SetPoint("TOPLEFT", headEl, "TOPLEFT", sectionW - filterWidth, 5) end
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
    local filterList = { {text=L("SHOW_ALL"), value="ALL"} }
    for _, c in ipairs(categories) do table.insert(filterList, {text=c.name, value=c.name}) end
    ddFilter = Skin:CreateMultiDropdown(content, filterWidth, filterList, Config.SelectedElementCategories, function(val, newState)
        for _, acc in ipairs(accFrameList) do
            local isVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[acc.catName]
            acc:SetShown(isVisible)
        end
        Config.UpdateAccordionLayout()
    end)
    ddFilter:SetPoint("TOPLEFT", headEl, "TOPLEFT", sectionW - filterWidth, 5) 
    Config.TourElementsFilter = ddFilter
    Config.TourElementButtons = {}
    Config.TourElementAccordionsByElementType = {}
    for _, cat in ipairs(categories) do
        local displayElements = { "Divider" }
        for _, e in ipairs(cat.elements) do table.insert(displayElements, e) end
        local buttonPadX = 6
        local buttonGapX = 8
        local buttonGapY = 6
        local buttonHeight = 26
        local buttonColumns = math.max(4, math.min(6, math.floor((sectionW + buttonGapX) / (118 + buttonGapX))))
        local buttonWidth = math.max(112, math.floor((sectionW - (buttonPadX * 2) - ((buttonColumns - 1) * buttonGapX)) / buttonColumns))
        local numRows = math.ceil(#displayElements / buttonColumns)
        local contentH = (numRows * buttonHeight) + ((numRows - 1) * buttonGapY) + (buttonPadX * 2)
        local acc = Skin:CreateAccordion(content, cat.name, contentH, function(expanded) 
            Config.AccordionStates[cat.name] = expanded
            Config.UpdateAccordionLayout() 
        end, sectionW)
        acc.onAnimUpdate = Config.UpdateAccordionLayout
        acc.catName = cat.name 
        table.insert(accFrameList, acc)
        local isInitialVisible = Config.SelectedElementCategories["ALL"] or Config.SelectedElementCategories[cat.name]
        acc:SetShown(isInitialVisible)
        if Config.AccordionStates[cat.name] then acc:SetExpanded(true) end
        local btnX, btnY = buttonPadX, -buttonPadX
        for i, typeName in ipairs(displayElements) do
            local isDragonBtn = (typeName == "Dragonriding")
            local isSkillStreamBtn = (typeName == "Skill Stream")
            local isTargetCastBtn = (typeName == "Target Castbar")
            local isCastbarBtn = (typeName == "Castbar")
            local isDivider = (typeName == "Divider")
            local isBigWidget = (typeName == "Dragonriding" or typeName == "Skill Stream" or typeName == "Target Castbar" or typeName == "Castbar" or typeName == "Mythic+ Dashboard" or typeName == "Interrupt Sync" or typeName == "VaultEye" or typeName == "Cursor Ring" or typeName == "Retirement Home" or typeName == "Custom Code" or typeName == "CCPartySync" or typeName == "Party Defensives & Utility" or typeName == "PrepChecker" or typeName == "Move Widget" or typeName == "Level Up Tracker")
            local isActive = false
            for _, e in ipairs(bar.elements) do 
                if e.type == typeName then isActive = true; break end 
            end
            local buttonLabel = LE(typeName, true)
            local btn = Skin:CreateButton(acc.content, buttonLabel, buttonWidth, buttonHeight)
            btn:SetPoint("TOPLEFT", btnX, btnY)
            Config.TourElementButtons[typeName] = btn
            Config.TourElementAccordionsByElementType[typeName] = acc
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
            local btnIsStrict = (typeName == "Dragonriding" or typeName == "Mythic+ Dashboard" or typeName == "Skill Stream" or typeName == "Target Castbar" or typeName == "Castbar" or typeName == "Interrupt Sync" or typeName == "VaultEye" or typeName == "CCPartySync" or typeName == "Party Defensives & Utility" or typeName == "PrepChecker" or typeName == "Move Widget" or typeName == "Level Up Tracker")
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
                         newEl.code = "return WFL('TEXT_HELLO_WORLD')"
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
                     elseif typeName == "Party Defensives & Utility" then
                         newEl.barWidth = 220
                         newEl.barHeight = 30
                         newEl.iconSize = 30
                         newEl.spacing = 5
                         newEl.showIcon = true
                         newEl.catEXT_DEF = true
                         newEl.catRAID_DEF = true
                         newEl.catLUST = true
                         newEl.catCR = true
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
            btnX = btnX + buttonWidth + buttonGapX
            if i % buttonColumns == 0 then
                btnX = buttonPadX
                btnY = btnY - (buttonHeight + buttonGapY)
            end
        end
    end
    activeElementsFrame:SetHeight(math.max(1, #bar.elements * 38 + 10))
    Config.UpdateAccordionLayout() 
    local fontList = {}
    for k, v in pairs(Skin.Media.Fonts) do
        table.insert(fontList, {text = k, value = k, font = v})
    end
    local outlineList = { {text=L("OUTLINE_NONE"), value=""}, {text=L("OUTLINE_OUTLINE"), value="OUTLINE"}, {text=L("OUTLINE_THICK"), value="THICKOUTLINE"}, {text=L("OUTLINE_MONOCHROME"), value="MONOCHROME"}, {text=L("OUTLINE_MONO_OUTLINE"), value="MONOCHROME,OUTLINE"} }
    local settingsOnlyWidgetTypes = {
        ["Dragonriding"] = true,
        ["Skill Stream"] = true,
        ["Target Castbar"] = true,
        ["Castbar"] = true,
        ["Custom Code"] = true,
        ["Cursor Ring"] = true,
        ["Retirement Home"] = true,
        ["Mythic+ Dashboard"] = true,
        ["Interrupt Sync"] = true,
        ["VaultEye"] = true,
        ["CCPartySync"] = true,
        ["Party Defensives & Utility"] = true,
        ["PrepChecker"] = true,
        ["Level Up Tracker"] = true
    }
    Config.ElementRows = {}
    Config.TourElementRowsByType = {}
    for i, elem in ipairs(bar.elements) do
        local displayType = LE(elem.type, true)
        local item = CreateFrame("Frame", nil, activeElementsFrame, "BackdropTemplate")
        item:SetSize(sectionW, 34); item:SetPoint("TOPLEFT", 10, -((i-1) * 38))
        Skin:ApplyBackdrop(item, 0.3, 0.5)
        local labelWidth = settingsOnlyWidgetTypes[elem.type]
            and math.max(360, math.floor(sectionW - 200))
            or math.max(170, math.min(280, math.floor(sectionW * 0.34)))
        item.txt = item:CreateFontString(nil, "OVERLAY", "GameFontNormal"); item.txt:SetPoint("LEFT", 8, 0); item.txt:SetText(i..". "..displayType); item.txt:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, ""); item.txt:SetWidth(labelWidth); item.txt:SetJustifyH("LEFT")
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
        item.elementType = elem.type
        Config.TourElementRowsByType[elem.type] = item
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
                Config.DragGhost.text:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_UI, "")
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
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenElementSettings(index, i, elem) end)
        elseif elem.type == "Dragonriding" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenDragonridingSettings(index, i, elem) end)
        elseif elem.type == "Skill Stream" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenSkillStreamSettings(index, i, elem) end)
        elseif elem.type == "Target Castbar" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenTargetCastbarSettings(index, i, elem) end)
        elseif elem.type == "Castbar" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCastbarSettings(index, i, elem) end)
        elseif elem.type == "Custom Code" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCustomCodeSettings(index, i, elem) end)
        elseif elem.type == "Cursor Ring" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCursorRingSettings(index, i, elem) end)
        elseif elem.type == "Retirement Home" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenRetirementHomeSettings(index, i, elem) end)
        elseif elem.type == "Mythic+ Dashboard" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() 
                if Config.OpenMythicPlusSettings then Config:OpenMythicPlusSettings(index, i, elem) end 
             end)
        elseif elem.type == "Interrupt Sync" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenInterruptSyncSettings(index, i, elem) end)
        elseif elem.type == "VaultEye" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenVaultEyeSettings(index, i, elem) end)
        elseif elem.type == "CCPartySync" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenCCPartySyncSettings(index, i, elem) end)
        elseif elem.type == "Party Defensives & Utility" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenDefUtilSyncSettings(index, i, elem) end)
        elseif elem.type == "PrepChecker" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenPrepCheckerSettings(index, i, elem) end)
        elseif elem.type == "Level Up Tracker" then
             btnCol:Hide()
             local btnSettings = Skin:CreateButton(item, L("BUTTON_SETTINGS"), 100, 22)
             btnSettings:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnSettings:SetScript("OnClick", function() Config:OpenLevelUpTrackerSettings(index, i, elem) end)
        elseif elem.type == "Move Widget" then
             btnCol:Hide()
             local btnReset = Skin:CreateButton(item, L("BUTTON_RESET"), 100, 22)
             btnReset:SetPoint("RIGHT", dragHandle, "LEFT", -10, 0)
             btnReset:SetScript("OnClick", function()
                 local ref = (_G.WidgetForge and _G.WidgetForge.MoveWidget)
                 if ref and ref.ResetPositions then
                     ref:ResetPositions()
                 end
             end)
             local chkSave = Skin:CreateCheckbox(item, L("LABEL_SAVE_POSITION"), elem.savePosition ~= false, function(v)
                   elem.savePosition = v
               end)
             chkSave:SetCompactMode(true)
             chkSave:SetWidth(120)
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
            item.fontDropdown = ddFont
            chkIcon = Skin:CreateCheckbox(item, L("LABEL_ICON_SHORT"), elem.showIcon, function(v) elem.showIcon = v; WidgetForge:RebuildBarComponents(index) end); chkIcon:SetCompactMode(true); chkIcon:SetWidth(70); chkIcon:SetPoint("RIGHT", ddFont, "LEFT", -55, 0); chkIcon.box:SetSize(14, 14); chkIcon.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "")
            chkTip = Skin:CreateCheckbox(item, L("LABEL_TOOLTIP_SHORT"), elem.showTooltip, function(v) elem.showTooltip = v; WidgetForge:RebuildBarComponents(index) end); chkTip:SetCompactMode(true); chkTip:SetWidth(92); chkTip:SetPoint("RIGHT", chkIcon, "LEFT", -25, 0); chkTip.box:SetSize(14, 14); chkTip.label:SetFont(Skin.Constants.FONT_NORMAL, 10, "") 
            item.chkIcon = chkIcon
            item.chkTip = chkTip
            Config:SetElementCheckboxDisabledVisual(chkTip, not not bar.clickThrough)
            if elem.type == "Clock" then 
                local fmtList = { {text=L("OPTION_24H"), value="24h"}, {text=L("OPTION_12H"), value="12h"} }; 
                ddFmt = Skin:CreateDropdown(item, 50, fmtList, elem.timeFormat or "24h", function(v) elem.timeFormat = v; WidgetForge:RebuildBarComponents(index) end); 
                ddFmt:SetPoint("RIGHT", chkTip, "LEFT", -5, 0) 
            elseif elem.type == "Gold" then
                local sepList = { {text="10,000", value="COMMA"}, {text="10.000", value="DOT"}, {text="10 000", value="SPACE"}, {text="10000", value="NONE"} }
                ddSep = Skin:CreateDropdown(item, 70, sepList, elem.separator or "COMMA", function(v) elem.separator = v; WidgetForge:RebuildBarComponents(index) end)
                ddSep:SetPoint("RIGHT", chkTip, "LEFT", -5, 0)
            end
        end
        y = y - 38 
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
        local title = Skin:CreateTitleBar(f, L("DIVIDER_SETTINGS_TITLE"), function() f:Hide() end)
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
    local lblMode = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblMode:SetPoint("TOPLEFT", 20, y-5); lblMode:SetText(L("LABEL_MODE"))
    local modeList = { {text=L("OPTION_GRAPHIC_LINE"), value="LINE"}, {text=L("OPTION_TEXT_CHARACTER"), value="TEXT"} }
    local ddMode = Skin:CreateDropdown(content, 120, modeList, elem.dividerMode or "LINE", function(v) 
        elem.dividerMode = v; 
        WidgetForge:RebuildBarComponents(barIndex)
        Config:OpenElementSettings(barIndex, elemIndex, elem) 
    end)
    ddMode:SetPoint("TOPLEFT", 100, y)
    y = y - 40
    local lblStyle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblStyle:SetPoint("TOPLEFT", 20, y-5); lblStyle:SetText(L("LABEL_STYLE"))
    local styleList = { {text=L("OPTION_VERTICAL"), value="VERTICAL"}, {text=L("OPTION_HORIZONTAL"), value="HORIZONTAL"} }
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
        local lblTxt = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblTxt:SetPoint("TOPLEFT", 20, y-5); lblTxt:SetText(L("LABEL_TEXT"))
        local ebFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        ebFrame:SetSize(120, 25); ebFrame:SetPoint("TOPLEFT", 100, y)
        Skin:ApplyBackdrop(ebFrame); ebFrame:SetBackdropColor(0,0,0,0.5)
        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetAllPoints(ebFrame); eb:SetFont(Skin.Constants.FONT_NORMAL, 12, ""); eb:SetTextInsets(5,5,0,0); eb:SetAutoFocus(false)
        eb:SetText(elem.dividerText or "|")
        eb:SetScript("OnTextChanged", function(self) elem.dividerText = self:GetText(); WidgetForge:RebuildBarComponents(barIndex) end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        y = y - 40
        local lblSz = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblSz:SetPoint("TOPLEFT", 20, y-5); lblSz:SetText(L("LABEL_SIZE"))
        local slSz = Skin:CreateSlider(content, 8, 72, 1, elem.size or 12, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slSz:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    else
        local lblLen = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblLen:SetPoint("TOPLEFT", 20, y-5); lblLen:SetText(L("LABEL_LENGTH"))
        local slLen = Skin:CreateSlider(content, 5, 200, 1, elem.size or 20, function(v) elem.size = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slLen:SetPoint("TOPLEFT", 100, y)
        y = y - 40
        local lblThk = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblThk:SetPoint("TOPLEFT", 20, y-5); lblThk:SetText(L("LABEL_THICKNESS"))
        local slThk = Skin:CreateSlider(content, 1, 20, 1, elem.thickness or 2, function(v) elem.thickness = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
        slThk:SetPoint("TOPLEFT", 100, y)
        y = y - 40
    end
    local lblOff = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lblOff:SetPoint("TOPLEFT", 20, y-5); lblOff:SetText(L("LABEL_OFFSET"))
    local slOff = Skin:CreateSlider(content, -50, 50, 1, elem.offset or 0, function(v) elem.offset = v; WidgetForge:RebuildBarComponents(barIndex) end, 120)
    slOff:SetPoint("TOPLEFT", 100, y)
    y = y - 40
    local txtHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtHelp:SetPoint("TOP", 0, y - 5)
    txtHelp:SetText(L("HELP_DIVIDER_OFFSET"))
    f:Show()
end
function Config:GetSlidePanel()
    if Config.SlidePanel then return Config.SlidePanel end
    local Skin = _G.ForgeSkin
    local parent = Config.Frame
    local anchorFrame = Config.MainPanel or parent
    local panel = Skin:CreateSlidePanel(parent, anchorFrame:GetWidth(), anchorFrame:GetHeight(), {
        anchorFrame = anchorFrame,
        x = 0,
        y = 0,
    })
    panel.onCloseHandler = function(self)
        Config:ToggleSlidePanel(false)
    end
    Config.SlidePanel = panel
    Config:RefreshWindowLayout()
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
function Config:ResetSlidePanelContent(panel)
    if not panel or not panel.content then return end
    local content = panel.content
    local kids = { content:GetChildren() }
    for _, k in ipairs(kids) do
        k:Hide()
    end
    local regions = { content:GetRegions() }
    for _, r in ipairs(regions) do
        r:Hide()
    end
    if panel.builder then
        if panel.builder.Release then
            panel.builder:Release()
        end
        panel.builder = nil
    end
end
function Config:BuildActiveSlidePanel(preserveScroll)
    local panel = self.SlidePanel
    if not panel or not panel.activeSettingsBuilder then return end
    local scrollPos = 0
    if preserveScroll and panel.scroll and panel.scroll.GetVerticalScroll then
        scrollPos = panel.scroll:GetVerticalScroll() or 0
    end
    self:ResetSlidePanelContent(panel)
    panel.activeSettingsBuilder(panel)
    if panel.scroll and panel.scroll.RefreshLayout then
        panel.scroll:RefreshLayout()
    end
    if preserveScroll and panel.scroll and panel.scroll.SetVerticalScroll then
        C_Timer.After(0, function()
            if not panel or not panel:IsShown() or not panel.scroll then return end
            local maxScroll = panel.scroll.GetVerticalScrollRange and panel.scroll:GetVerticalScrollRange() or 0
            panel.scroll:SetVerticalScroll(math.max(0, math.min(scrollPos or 0, maxScroll or 0)))
        end)
    end
end
function Config:ScheduleSlidePanelRefresh()
    local panel = self.SlidePanel
    if not panel or not panel:IsShown() or not panel.activeSettingsBuilder then return end
    panel.resizeRefreshNonce = (panel.resizeRefreshNonce or 0) + 1
    local nonce = panel.resizeRefreshNonce
    C_Timer.After(0.05, function()
        if not panel or not panel:IsShown() or panel.resizeRefreshNonce ~= nonce then return end
        Config:BuildActiveSlidePanel(true)
    end)
end
function Config:ScheduleSelectedBarRefresh()
    if not self.Frame or not self.Frame:IsShown() or not self.SelectedBarIndex then return end
    self.selectedBarRefreshNonce = (self.selectedBarRefreshNonce or 0) + 1
    local nonce = self.selectedBarRefreshNonce
    C_Timer.After(0.05, function()
        if not Config.Frame or not Config.Frame:IsShown() or Config.selectedBarRefreshNonce ~= nonce then return end
        if not Config.SelectedBarIndex or not WidgetForgeDB or not WidgetForgeDB.bars or not WidgetForgeDB.bars[Config.SelectedBarIndex] then return end
        local scrollPos = 0
        if Config.DetailsScroll and Config.DetailsScroll.GetVerticalScroll then
            scrollPos = Config.DetailsScroll:GetVerticalScroll() or 0
        end
        Config:SelectBar(Config.SelectedBarIndex)
        if Config.DetailsScroll and Config.DetailsScroll.SetVerticalScroll then
            C_Timer.After(0, function()
                if not Config.DetailsScroll then return end
                local maxScroll = Config.DetailsScroll.GetVerticalScrollRange and Config.DetailsScroll:GetVerticalScrollRange() or 0
                Config.DetailsScroll:SetVerticalScroll(math.max(0, math.min(scrollPos or 0, maxScroll or 0)))
            end)
        end
    end)
end
function Config:OpenManagedWidgetSettings(titleText, barIndex, elem, createSettingsFunc)
    local panel = Config:GetSlidePanel()
    local wasShown = panel:IsShown()
    if wasShown and panel.onCloseWidgetSpecific then
        panel.onCloseWidgetSpecific()
        panel.onCloseWidgetSpecific = nil
    end
    Config:ToggleSlidePanel(true)
    panel.header.title:SetText(titleText)
    panel.config = elem
    panel.barIndex = barIndex
    if panel.scroll then
        panel.scroll:SetVerticalScroll(0)
    end
    panel.activeSettingsBuilder = function(activePanel)
        if createSettingsFunc then
            createSettingsFunc(activePanel)
        end
    end
    Config:BuildActiveSlidePanel(false)
    return panel
end
function Config:OpenCustomCodeSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_CUSTOM_CODE"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.CustomCode and _G.WidgetForge.CustomCode.CreateSettings then
            _G.WidgetForge.CustomCode:CreateSettings(panel)
        end
    end)
end
function Config:OpenDragonridingSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_DRAGONRIDING"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.Dragonriding and _G.WidgetForge.Dragonriding.CreateSettings then
            _G.WidgetForge.Dragonriding:CreateSettings(panel)
        end
    end)
end
function Config:OpenSkillStreamSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_SKILL_STREAM"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.SkillStream and _G.WidgetForge.SkillStream.CreateSettings then
            _G.WidgetForge.SkillStream:CreateSettings(panel)
        end
    end)
end
function Config:OpenTargetCastbarSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_TARGET_CASTBAR"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.TargetCastbar and _G.WidgetForge.TargetCastbar.CreateSettings then
            _G.WidgetForge.TargetCastbar:CreateSettings(panel)
        end
    end)
end
function Config:OpenCastbarSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_CASTBAR"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.Castbar and _G.WidgetForge.Castbar.CreateSettings then
            _G.WidgetForge.Castbar:CreateSettings(panel)
        end
    end)
end
function Config:OpenCursorRingSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_CURSOR_RING"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.CursorRing and _G.WidgetForge.CursorRing.CreateSettings then
            _G.WidgetForge.CursorRing:CreateSettings(panel)
        end
    end)
end
function Config:OpenRetirementHomeSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_RETIREMENT_HOME"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.RetirementHome and _G.WidgetForge.RetirementHome.CreateSettings then
            _G.WidgetForge.RetirementHome:CreateSettings(panel)
        end
    end)
end
function Config:OpenMythicPlusSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_MYTHIC_DASHBOARD"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.MythicPlus and _G.WidgetForge.MythicPlus.CreateSettings then
            _G.WidgetForge.MythicPlus:CreateSettings(panel)
        end
    end)
end
function Config:OpenInterruptSyncSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_INTERRUPT_SYNC"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.InterruptSync and _G.WidgetForge.InterruptSync.CreateSettings then
            _G.WidgetForge.InterruptSync:CreateSettings(panel)
        end
    end)
end
function Config:OpenVaultEyeSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_VAULTEYE"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.VaultEye and _G.WidgetForge.VaultEye.CreateSettings then
            _G.WidgetForge.VaultEye:CreateSettings(panel)
        end
    end)
end
function Config:OpenCCPartySyncSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_CC_PARTY_SYNC"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.CCSync and _G.WidgetForge.CCSync.CreateSettings then
            _G.WidgetForge.CCSync:CreateSettings(panel)
        end
    end)
end
function Config:OpenDefUtilSyncSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_DEFENSIVES_UTILITY"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.DefUtilSync and _G.WidgetForge.DefUtilSync.CreateSettings then
            _G.WidgetForge.DefUtilSync:CreateSettings(panel)
        end
    end)
end
function Config:OpenPrepCheckerSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_PREP_CHECKER"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.PrepChecker and _G.WidgetForge.PrepChecker.CreateSettings then
            _G.WidgetForge.PrepChecker:CreateSettings(panel)
        end
    end)
end
function Config:OpenLevelUpTrackerSettings(barIndex, elemIndex, elem)
    Config:OpenManagedWidgetSettings(L("SETTINGS_LEVEL_UP_TRACKER"), barIndex, elem, function(panel)
        if _G.WidgetForge and _G.WidgetForge.LevelUpTracker and _G.WidgetForge.LevelUpTracker.CreateSettings then
            _G.WidgetForge.LevelUpTracker:CreateSettings(panel)
        end
    end)
end
function Config:RegisterAddonSettingsPanel()
    if self.AddonSettingsPanel then return end
    local panel = CreateFrame("Frame", "WidgetForgeAddonSettingsPanel", UIParent)
    panel.name = "WidgetForge"
    self.AddonSettingsPanel = panel
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L("MINIMAP_TOOLTIP_TITLE"))
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(620)
    desc:SetText(L("ADDON_SETTINGS_DESC"))
    local minimapCheck = CreateFrame("CheckButton", "WidgetForgeMinimapToggle", panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    _G[minimapCheck:GetName() .. "Text"]:SetText(L("ENABLE_MINIMAP_ICON"))
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
    openButton:SetText(L("OPEN_WIDGETFORGE"))
    openButton:SetScript("OnClick", function()
        Config:OpenConfigWindow()
    end)
    local tourButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    tourButton:SetSize(140, 24)
    tourButton:SetPoint("LEFT", openButton, "RIGHT", 8, 0)
    tourButton:SetText(L("BUTTON_START_TOUR"))
    tourButton:SetScript("OnClick", function()
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.Start then
                _G.WidgetForgeTour:Start(true)
            end
        end)
    end)
    local guideButton = Skin:CreateButton(panel, L("BUTTON_START_GUIDE"), 160, 24)
    guideButton:SetPoint("LEFT", tourButton, "RIGHT", 8, 0)
    guideButton:SetScript("OnClick", function()
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.StartGuide then
                _G.WidgetForgeTour:StartGuide(true)
            end
        end)
    end)
    local tipButton = Skin:CreateButton(panel, L("BUTTON_SHOW_TIP"), 160, 24)
    tipButton:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -8)
    tipButton:SetScript("OnClick", function()
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.StartTipOfDay then
                _G.WidgetForgeTour:StartTipOfDay(true)
            end
        end)
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
    local trimmed = (msg or ""):match("^%s*(.-)%s*$")
    local input = string.lower(trimmed or "")
    local localeAPI = _G.WidgetForgeLocale
    if input == "help" or input == "?" then
        print("|cff00ccff" .. L("CMD_HELP_HEADER") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_OPEN_CONFIG") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_SHOW_HELP") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_TOUR_START") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_TOUR_RESET") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_GUIDE_START") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_TIP_SHOW") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_MINIMAP_ON") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_MINIMAP_OFF") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_LOCALE_SHOW") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_LOCALE_LIST") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_LOCALE_SET") .. "|r")
        print("  |cff00ccff" .. L("CMD_HELP_LOCALE_RESET") .. "|r")
        return
    end
    if input == "minimap on" then
        if WidgetForge and WidgetForge.SetMinimapButtonEnabled then
            WidgetForge:SetMinimapButtonEnabled(true)
        end
        print("|cff00ccffWidgetForge|r " .. L("MSG_MINIMAP_ICON_STATUS", "|cff00ff00" .. L("SWITCH_ON") .. "|r"))
        return
    end
    if input == "minimap off" then
        if WidgetForge and WidgetForge.SetMinimapButtonEnabled then
            WidgetForge:SetMinimapButtonEnabled(false)
        end
        print("|cff00ccffWidgetForge|r " .. L("MSG_MINIMAP_ICON_STATUS", "|cffff0000" .. L("SWITCH_OFF") .. "|r"))
        return
    end
    if input == "tour" or input == "tour start" then
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.Start then
                _G.WidgetForgeTour:Start(true)
                print("|cff00ccffWidgetForge|r " .. L("MSG_TOUR_STARTED"))
            end
        end)
        return
    end
    if input == "tour reset" then
        if _G.WidgetForgeTour and _G.WidgetForgeTour.ResetProgress then
            _G.WidgetForgeTour:ResetProgress()
            print("|cff00ccffWidgetForge|r " .. L("MSG_TOUR_RESET"))
        end
        return
    end
    if input == "guide" or input == "guide start" then
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.StartGuide then
                _G.WidgetForgeTour:StartGuide(true)
                print("|cff00ccffWidgetForge|r " .. L("MSG_GUIDE_STARTED"))
            end
        end)
        return
    end
    if input == "tip" or input == "tips" or input == "tip start" then
        Config:OpenConfigWindow()
        C_Timer.After(0.2, function()
            if _G.WidgetForgeTour and _G.WidgetForgeTour.StartTipOfDay then
                _G.WidgetForgeTour:StartTipOfDay(true)
                print("|cff00ccffWidgetForge|r " .. L("MSG_TIP_SHOWN"))
            end
        end)
        return
    end
    if input == "locale" then
        if localeAPI and localeAPI.GetCurrentCode then
            local current = localeAPI:GetCurrentCode()
            local override = localeAPI.GetSavedOverride and localeAPI:GetSavedOverride()
            if override then
                print("|cff00ccffWidgetForge|r " .. L("MSG_ADDON_LOCALE_OVERRIDE", "|cff00ff00" .. current .. "|r"))
            else
                print("|cff00ccffWidgetForge|r " .. L("MSG_USING_CLIENT_LOCALE", "|cff00ff00" .. current .. "|r"))
            end
        end
        return
    end
    if input == "locale list" then
        if localeAPI and localeAPI.GetSupportedCodes then
            print("|cff00ccffWidgetForge|r " .. L("MSG_SUPPORTED_LOCALES", table.concat(localeAPI:GetSupportedCodes(), ", ")))
        end
        return
    end
    if input == "locale reset" or input == "locale clear" then
        if localeAPI and localeAPI.ClearOverride then
            localeAPI:ClearOverride()
            local current = localeAPI:GetCurrentCode()
            print("|cff00ccffWidgetForge|r " .. L("MSG_LOCALE_OVERRIDE_CLEARED", "|cff00ff00" .. current .. "|r"))
            ReloadUI()
        end
        return
    end
    local requestedLocale = trimmed and trimmed:match("^locale%s+([%w]+)$")
    if requestedLocale then
        if not localeAPI or not localeAPI.SetOverride then
            print("|cffff0000WidgetForge|r " .. L("ERR_LOCALE_SYSTEM_UNAVAILABLE"))
            return
        end
        local ok, resolved = localeAPI:SetOverride(requestedLocale)
        if not ok then
            print("|cffff0000WidgetForge|r " .. L("ERR_UNSUPPORTED_LOCALE", requestedLocale))
            print("|cff00ccffWidgetForge|r " .. L("MSG_SUPPORTED_LOCALES", table.concat(localeAPI:GetSupportedCodes(), ", ")))
            return
        end
        print("|cff00ccffWidgetForge|r " .. L("MSG_LOCALE_SET_RELOADING", "|cff00ff00" .. resolved .. "|r"))
        ReloadUI()
        return
    end
    Config:OpenConfigWindow()
end
