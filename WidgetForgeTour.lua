WidgetForgeTour = WidgetForgeTour or {}

local Tour = WidgetForgeTour
local Config = ForgeConfig
local Skin = ForgeSkin
local L = WFL

Tour.VERSION = (WIDGETFORGE_CONSTANTS and WIDGETFORGE_CONSTANTS.TOUR_VERSION) or 1
Tour.Active = false
Tour.GuideActive = false
Tour.TipActive = false
Tour.PendingAutoStart = false
Tour.PendingStepID = nil
Tour.CurrentStepID = nil
Tour.CurrentStepIndex = nil
Tour.GuideCurrentStepID = nil
Tour.GuideCurrentStepIndex = nil
Tour.GuideContext = nil
Tour.GuideStepComplete = false
Tour.CurrentTipIndex = nil
Tour.PreparedTipIndex = nil
Tour.LastAccentIndex = nil
Tour.HighlightProxyFrame = nil
Tour.AccentPalette = {
    { r = 0.12, g = 0.82, b = 1.00, a = 1.00 },
    { r = 0.25, g = 0.95, b = 0.62, a = 1.00 },
    { r = 1.00, g = 0.72, b = 0.20, a = 1.00 },
    { r = 1.00, g = 0.42, b = 0.42, a = 1.00 },
    { r = 0.80, g = 0.50, b = 1.00, a = 1.00 },
    { r = 0.98, g = 0.55, b = 0.78, a = 1.00 },
}

Tour.StepOrder = {
    "welcome",
    "bars",
    "quickstart",
    "move",
    "elements",
    "profiles",
}

Tour.Steps = {
    welcome = {
        titleKey = "TOUR_TITLE_WELCOME",
        textKey = "TOUR_TEXT_WELCOME",
        targetHintKey = "TOUR_TARGET_WELCOME",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.Frame
        end,
    },
    bars = {
        titleKey = "TOUR_TITLE_BARS",
        textKey = "TOUR_TEXT_BARS",
        targetHintKey = "TOUR_TARGET_BARS",
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        resolveTarget = function()
            return Config and (Config.TourSidebar or Config.BarListScroll or Config.BarListContent)
        end,
    },
    quickstart = {
        titleKey = "TOUR_TITLE_QUICK_START",
        textKey = "TOUR_TEXT_QUICK_START",
        targetHintKey = "TOUR_TARGET_QUICK_START",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and (Config.TourAddBarButton or Config.TourPresetDropdown)
        end,
    },
    move = {
        titleKey = "TOUR_TITLE_MOVE",
        textKey = "TOUR_TEXT_MOVE",
        targetHintKey = "TOUR_TARGET_MOVE",
        highlightPadding = { left = 1, right = 1, top = 1, bottom = 1 },
        resolveTarget = function()
            return Tour:GetSelectedBarFrame() or (Config and (Config.TourMainPanel or Config.MainPanel))
        end,
    },
    elements = {
        titleKey = "TOUR_TITLE_ELEMENTS",
        textKey = "TOUR_TEXT_ELEMENTS",
        targetHintKey = "TOUR_TARGET_ELEMENTS",
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function()
            if Config and Config.SelectedBarIndex and Config.SelectBar then
                Config:SelectBar(Config.SelectedBarIndex)
            end
        end,
        resolveTarget = function()
            return Config and (Config.TourElementsHeader or Config.DetailsContent or Config.MainPanel)
        end,
    },
    profiles = {
        titleKey = "TOUR_TITLE_PROFILES",
        textKey = "TOUR_TEXT_PROFILES",
        targetHintKey = "TOUR_TARGET_PROFILES",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and (Config.TourExportButton or Config.TourImportButton or Config.Frame)
        end,
    },
}

Tour.GuideStepOrder = {
    "guide_intro",
    "guide_add_bar",
    "guide_open_settings",
    "guide_click_through",
    "guide_move_bar",
    "guide_add_element",
    "guide_change_font",
    "guide_complete",
}

Tour.GuideSteps = {
    guide_intro = {
        titleKey = "GUIDE_TITLE_INTRO",
        textKey = "GUIDE_TEXT_INTRO",
        targetHintKey = "GUIDE_TARGET_INTRO",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.Frame
        end,
    },
    guide_add_bar = {
        titleKey = "GUIDE_TITLE_ADD_BAR",
        textKey = "GUIDE_TEXT_ADD_BAR",
        targetHintKey = "GUIDE_TARGET_ADD_BAR",
        actionRequired = true,
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        onEnter = function(self, context)
            context.startBarCount = self:GetBarCount()
            context.createdBarIndex = nil
        end,
        afterComplete = function(self, context)
            context.createdBarIndex = (Config and Config.SelectedBarIndex) or self:GetBarCount()
        end,
        isComplete = function(self, context)
            return self:GetBarCount() > (context.startBarCount or 0)
        end,
        resolveTarget = function()
            return Config and Config.TourAddBarButton
        end,
    },
    guide_open_settings = {
        titleKey = "GUIDE_TITLE_OPEN_SETTINGS",
        textKey = "GUIDE_TEXT_OPEN_SETTINGS",
        targetHintKey = "GUIDE_TARGET_OPEN_SETTINGS",
        actionRequired = true,
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function(self)
            self:SelectGuideBar()
        end,
        isComplete = function()
            return Config and Config.SettingsAccordionExpanded == true
        end,
        resolveTarget = function()
            return Config and Config.TourSettingsAccordion and Config.TourSettingsAccordion.header
        end,
    },
    guide_click_through = {
        titleKey = "GUIDE_TITLE_CLICK_THROUGH",
        textKey = "GUIDE_TEXT_CLICK_THROUGH",
        targetHintKey = "GUIDE_TARGET_CLICK_THROUGH",
        actionRequired = true,
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function(self)
            self:SelectGuideBar()
            self:EnsureGuideSettingsExpanded()
        end,
        isComplete = function(self)
            local bar = self:GetGuideBar()
            return bar and not not bar.clickThrough
        end,
        resolveTarget = function()
            return Config and Config.TourClickThroughSwitch
        end,
    },
    guide_move_bar = {
        titleKey = "GUIDE_TITLE_MOVE_BAR",
        textKey = "GUIDE_TEXT_MOVE_BAR",
        targetHintKey = "GUIDE_TARGET_MOVE_BAR",
        actionRequired = true,
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function(self)
            self:SelectGuideBar()
            self:EnsureGuideSettingsExpanded()
        end,
        onEnter = function(self, context)
            local bar = self:GetGuideBar()
            context.baseX = bar and tonumber(bar.x) or 0
            context.baseY = bar and tonumber(bar.y) or 0
        end,
        isComplete = function(self, context)
            local bar = self:GetGuideBar()
            if not bar then
                return false
            end

            local x = tonumber(bar.x) or 0
            local y = tonumber(bar.y) or 0
            return math.abs(x - (context.baseX or 0)) >= 10 or math.abs(y - (context.baseY or 0)) >= 10
        end,
        resolveTarget = function()
            return Config and (Config.slX or Config.slY)
        end,
    },
    guide_add_element = {
        titleKey = "GUIDE_TITLE_ADD_ELEMENT",
        textKey = "GUIDE_TEXT_ADD_ELEMENT",
        targetHintKey = "GUIDE_TARGET_ADD_ELEMENT",
        actionRequired = true,
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        prepare = function(self)
            self:SelectGuideBar()
            self:EnsureGuideElementAccordion("FPS")
        end,
        onEnter = function(self, context)
            local bar = self:GetGuideBar()
            context.baseElementCount = bar and #bar.elements or 0
            context.fpsInitiallyPresent = self:GetGuideElementByType("FPS") ~= nil
            context.fpsWasRemoved = false
        end,
        isComplete = function(self, context)
            local bar = self:GetGuideBar()
            if not bar then
                return false
            end

            local hasFPS = self:GetGuideElementByType("FPS") ~= nil
            if context.fpsInitiallyPresent then
                if not context.fpsWasRemoved and not hasFPS then
                    context.fpsWasRemoved = true
                    return false
                end
                return context.fpsWasRemoved and hasFPS
            end

            return hasFPS and #bar.elements > (context.baseElementCount or 0)
        end,
        resolveTarget = function()
            return Config and Config.TourElementButtons and Config.TourElementButtons["FPS"]
        end,
    },
    guide_change_font = {
        titleKey = "GUIDE_TITLE_CHANGE_FONT",
        textKey = "GUIDE_TEXT_CHANGE_FONT",
        targetHintKey = "GUIDE_TARGET_CHANGE_FONT",
        actionRequired = true,
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function(self)
            self:SelectGuideBar()
        end,
        onEnter = function(self, context)
            local elem = self:GetGuideElementByType("FPS")
            context.baseFont = elem and (elem.font or false) or false
        end,
        isComplete = function(self, context)
            local elem = self:GetGuideElementByType("FPS")
            if not elem then
                return false
            end
            return (elem.font or false) ~= (context.baseFont or false)
        end,
        resolveTarget = function()
            return Tour:GetGuideFontDropdown("FPS") or Tour:GetGuideElementRowByType("FPS")
        end,
    },
    guide_complete = {
        titleKey = "GUIDE_TITLE_COMPLETE",
        textKey = "GUIDE_TEXT_COMPLETE",
        targetHintKey = "GUIDE_TARGET_COMPLETE",
        highlightPadding = { left = 1, right = 1, top = 1, bottom = 1 },
        prepare = function(self)
            self:SelectGuideBar()
        end,
        resolveTarget = function()
            return Tour:GetSelectedBarFrame() or (Config and Config.Frame)
        end,
    },
}

Tour.Tips = {
    {
        id = "tip_quick_bar",
        titleKey = "TIP_TITLE_QUICK_BAR",
        textKey = "TIP_TEXT_QUICK_BAR",
        targetHintKey = "TIP_TARGET_QUICK_BAR",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.TourAddBarButton
        end,
    },
    {
        id = "tip_presets",
        titleKey = "TIP_TITLE_PRESETS",
        textKey = "TIP_TEXT_PRESETS",
        targetHintKey = "TIP_TARGET_PRESETS",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.TourPresetDropdown
        end,
    },
    {
        id = "tip_clickthrough",
        titleKey = "TIP_TITLE_CLICKTHROUGH",
        textKey = "TIP_TEXT_CLICKTHROUGH",
        targetHintKey = "TIP_TARGET_CLICKTHROUGH",
        highlightPadding = { left = 0, right = 0, top = 0, bottom = 0 },
        prepare = function(self)
            if Config and Config.SelectedBarIndex and Config.SelectBar then
                Config:SelectBar(Config.SelectedBarIndex)
            end
            self:EnsureGuideSettingsExpanded()
        end,
        resolveTarget = function()
            return Config and Config.TourClickThroughSwitch
        end,
    },
    {
        id = "tip_move",
        titleKey = "TIP_TITLE_MOVE",
        textKey = "TIP_TEXT_MOVE",
        targetHintKey = "TIP_TARGET_MOVE",
        highlightPadding = { left = 1, right = 1, top = 1, bottom = 1 },
        resolveTarget = function()
            return Tour:GetSelectedBarFrame()
        end,
    },
    {
        id = "tip_profiles",
        titleKey = "TIP_TITLE_PROFILES",
        textKey = "TIP_TEXT_PROFILES",
        targetHintKey = "TIP_TARGET_PROFILES",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and (Config.TourImportButton or Config.TourExportButton)
        end,
    },
    {
        id = "tip_guide",
        titleKey = "TIP_TITLE_GUIDE",
        textKey = "TIP_TEXT_GUIDE",
        targetHintKey = "TIP_TARGET_GUIDE",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.Frame
        end,
    },
    {
        id = "tip_locale",
        titleKey = "TIP_TITLE_LOCALE",
        textKey = "TIP_TEXT_LOCALE",
        targetHintKey = "TIP_TARGET_LOCALE",
        highlightPadding = { left = 2, right = 2, top = 2, bottom = 2 },
        resolveTarget = function()
            return Config and Config.Frame
        end,
    },
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    return pcall(fn, ...)
end

function Tour:GetDB()
    if type(_G.WidgetForgeDB) ~= "table" then
        return nil
    end

    if type(_G.WidgetForgeDB.tour) ~= "table" then
        _G.WidgetForgeDB.tour = {}
    end

    local db = _G.WidgetForgeDB.tour
    if type(db.versionSeen) ~= "number" then db.versionSeen = 0 end
    if type(db.dismissedVersion) ~= "number" then db.dismissedVersion = 0 end
    if type(db.lastStep) ~= "string" then db.lastStep = nil end
    if type(db.tips) ~= "table" then db.tips = {} end
    if type(db.tips.lastShownDate) ~= "string" then db.tips.lastShownDate = "" end
    if type(db.tips.lastTipIndex) ~= "number" then db.tips.lastTipIndex = 0 end
    if type(db.tips.autoShow) ~= "boolean" then db.tips.autoShow = true end

    return db
end

function Tour:Initialize()
    self:GetDB()
end

function Tour:GetTotalSteps()
    return #self.StepOrder
end

function Tour:GetGuideTotalSteps()
    return #self.GuideStepOrder
end

function Tour:GetStepIndex(stepID)
    for index, id in ipairs(self.StepOrder) do
        if id == stepID then
            return index
        end
    end
    return nil
end

function Tour:GetGuideStepIndex(stepID)
    for index, id in ipairs(self.GuideStepOrder) do
        if id == stepID then
            return index
        end
    end
    return nil
end

function Tour:GetStep(stepID)
    return self.Steps[stepID]
end

function Tour:GetGuideStep(stepID)
    return self.GuideSteps[stepID]
end

function Tour:IsConfigVisible()
    return Config and Config.Frame and Config.Frame:IsShown()
end

function Tour:GetRandomAccentColor()
    local palette = self.AccentPalette
    if not palette or #palette == 0 then
        return { r = 0.12, g = 0.82, b = 1.00, a = 1.00 }
    end

    local index = math.random(1, #palette)
    if #palette > 1 and self.LastAccentIndex == index then
        index = (index % #palette) + 1
    end

    self.LastAccentIndex = index
    local color = palette[index]
    return { r = color.r, g = color.g, b = color.b, a = color.a }
end

function Tour:GetSelectedBarFrame()
    if not (_G.WidgetForge and _G.WidgetForge.GetBarFrames and Config and Config.SelectedBarIndex) then
        return nil
    end

    local bars = _G.WidgetForge:GetBarFrames()
    if type(bars) ~= "table" then
        return nil
    end

    local frame = bars[Config.SelectedBarIndex]
    if frame and frame.IsShown and frame:IsShown() then
        return frame
    end

    for _, candidate in pairs(bars) do
        if candidate and candidate.IsShown and candidate:IsShown() then
            return candidate
        end
    end

    return nil
end

function Tour:GetBarCount()
    local db = _G.WidgetForgeDB
    if not (db and type(db.bars) == "table") then
        return 0
    end
    return #db.bars
end

function Tour:GetGuideBar()
    local barIndex = self.GuideContext and self.GuideContext.createdBarIndex
    if not barIndex then
        barIndex = Config and Config.SelectedBarIndex
    end
    if not (barIndex and _G.WidgetForgeDB and _G.WidgetForgeDB.bars) then
        return nil
    end
    return _G.WidgetForgeDB.bars[barIndex]
end

function Tour:SelectGuideBar()
    local barIndex = self.GuideContext and self.GuideContext.createdBarIndex
    if barIndex and Config and Config.SelectBar then
        Config:SelectBar(barIndex)
    end
end

function Tour:EnsureGuideSettingsExpanded()
    local accordion = Config and Config.TourSettingsAccordion
    if not accordion then
        return
    end

    local changed = false
    if accordion.SetExpanded and not accordion.expanded then
        accordion:SetExpanded(true)
        Config.SettingsAccordionExpanded = true
        changed = true
    end

    if changed and Config and Config.UpdateAccordionLayout then
        Config.UpdateAccordionLayout()
    end
end

function Tour:EnsureGuideElementAccordion(typeName)
    if not (Config and Config.TourElementAccordionsByElementType) then
        return
    end

    local accordion = Config.TourElementAccordionsByElementType[typeName]
    if not accordion then
        return
    end

    accordion:Show()
    if accordion.SetExpanded and not accordion.expanded then
        accordion:SetExpanded(true)
    end

    if Config.AccordionStates and accordion.catName then
        Config.AccordionStates[accordion.catName] = true
    end

    if Config.UpdateAccordionLayout then
        Config.UpdateAccordionLayout()
    end
end

function Tour:GetGuideElementByType(typeName)
    local bar = self:GetGuideBar()
    if not (bar and type(bar.elements) == "table") then
        return nil
    end

    for _, elem in ipairs(bar.elements) do
        if elem and elem.type == typeName then
            return elem
        end
    end

    return nil
end

function Tour:GetGuideElementRowByType(typeName)
    if not (Config and type(Config.TourElementRowsByType) == "table") then
        return nil
    end
    return Config.TourElementRowsByType[typeName]
end

function Tour:GetGuideFontDropdown(typeName)
    local row = self:GetGuideElementRowByType(typeName)
    return row and row.fontDropdown or nil
end

function Tour:GetTodayKey()
    return date("%Y-%m-%d")
end

function Tour:GetTipCount()
    return #self.Tips
end

function Tour:GetTip(index)
    return self.Tips[index]
end

function Tour:IsTipAutoShowEnabled()
    local db = self:GetDB()
    return db and db.tips and db.tips.autoShow ~= false
end

function Tour:SetTipAutoShowEnabled(enabled)
    local db = self:GetDB()
    if not (db and db.tips) then
        return
    end

    db.tips.autoShow = enabled and true or false
end

function Tour:ShouldAutoShowTip()
    local db = self:GetDB()
    if not db or not db.tips then
        return false
    end

    if self:ShouldAutoStart() then
        return false
    end

    if db.tips.autoShow == false then
        return false
    end

    return true
end

function Tour:PickRandomTipIndex(excludeIndex)
    local total = self:GetTipCount()
    if total <= 0 then
        return nil
    end

    local index = math.random(1, total)
    if total > 1 and excludeIndex and index == excludeIndex then
        index = (index % total) + 1
    end
    return index
end

function Tour:ResolveTipTarget(index)
    local tip = self:GetTip(index)
    if not tip or type(tip.resolveTarget) ~= "function" then
        return nil
    end
    return tip.resolveTarget()
end

function Tour:PrepareTip(index)
    local tip = self:GetTip(index)
    if not tip then
        return
    end

    if self.PreparedTipIndex == index then
        return
    end

    if type(tip.prepare) == "function" then
        SafeCall(tip.prepare, self)
    end

    self.PreparedTipIndex = index
end

function Tour:IsDescendantOf(frame, ancestor)
    while frame do
        if frame == ancestor then
            return true
        end
        if not frame.GetParent then
            break
        end
        frame = frame:GetParent()
    end
    return false
end

function Tour:GetFrameRect(frame)
    if not (frame and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom) then
        return nil
    end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not (left and right and top and bottom) then
        return nil
    end

    return left, right, top, bottom
end

function Tour:GetHighlightViewport(stepID, target)
    if Config and stepID == "guide_move_bar" and Config.DetailsScroll then
        return Config.DetailsScroll
    end

    if Config and stepID == "elements" and Config.DetailsScroll then
        return Config.DetailsScroll
    end

    if Config and Config.DetailsScroll and (self:IsDescendantOf(target, Config.DetailsScroll) or self:IsDescendantOf(target, Config.DetailsContent)) then
        return Config.DetailsScroll
    end

    if Config and Config.BarListScroll and (self:IsDescendantOf(target, Config.BarListScroll) or self:IsDescendantOf(target, Config.BarListContent)) then
        return Config.BarListScroll
    end

    return nil
end

function Tour:IsCurrentVersionDone()
    local db = self:GetDB()
    if not db then
        return false
    end
    return db.versionSeen >= self.VERSION or db.dismissedVersion >= self.VERSION
end

function Tour:ShouldAutoStart()
    local db = self:GetDB()
    if not db then
        return false
    end
    return db.versionSeen < self.VERSION and db.dismissedVersion < self.VERSION
end

function Tour:EnsureConfigOpen()
    if Config and Config.OpenConfigWindow then
        Config:OpenConfigWindow()
    end
end

function Tour:EnsureControlFrame()
    if self.ControlFrame then
        return self.ControlFrame
    end

    local frame = CreateFrame("Frame", "WidgetForgeTourControlFrame", UIParent, "BackdropTemplate")
    frame:SetSize(640, 330)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    Skin:ApplyBackdrop(frame, 0.92, 1)
    Skin:SetSmartBorder(frame, 1, { r = 0.12, g = 0.82, b = 1.00, a = 1.00 }, "OUTSIDE")
    frame:SetBackdropColor(0.04, 0.05, 0.06, 0.96)
    frame:SetBackdropBorderColor(0.20, 0.23, 0.26, 1)

    frame:SetScript("OnDragStart", function(self)
        if Tour.GuideActive or Tour.Active or Tour.TipActive then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.wasDragged = true
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not ((Tour.GuideActive or Tour.Active or Tour.TipActive) and self:IsShown()) then
            self.guideElapsed = 0
            self.highlightElapsed = 0
            return
        end

        self.highlightElapsed = (self.highlightElapsed or 0) + elapsed
        if self.highlightElapsed >= 0.05 then
            self.highlightElapsed = 0
            Tour:RefreshCurrentHighlight()
        end

        if not Tour.GuideActive then
            self.guideElapsed = 0
            return
        end

        self.guideElapsed = (self.guideElapsed or 0) + elapsed
        if self.guideElapsed >= 0.15 then
            self.guideElapsed = 0
            Tour:RefreshGuideStepState()
        end
    end)

    frame.glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.glow:SetPoint("TOPLEFT", -6, 6)
    frame.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    frame.glow:SetFrameLevel(frame:GetFrameLevel() - 1)
    Skin:ApplyBackdrop(frame.glow, 0.05, 0)
    frame.glow:SetBackdropColor(0, 0, 0, 0.12)
    frame.glow:SetBackdropBorderColor(0, 0, 0, 0)

    frame.kicker = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.kicker:SetPoint("TOPLEFT", 22, -18)
    frame.kicker:SetJustifyH("LEFT")
    frame.kicker:SetTextColor(0.75, 0.78, 0.82, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 22, -46)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWidth(596)

    frame.progress = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.progress:SetPoint("TOPRIGHT", -22, -18)
    frame.progress:SetJustifyH("RIGHT")

    frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.body:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -10)
    frame.body:SetPoint("TOPRIGHT", -22, -82)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")
    frame.body:SetWordWrap(true)
    frame.body:SetSpacing(5)

    frame.targetLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.targetLabel:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -12)
    frame.targetLabel:SetWidth(596)
    frame.targetLabel:SetJustifyH("LEFT")
    frame.targetLabel:SetTextColor(0.72, 0.72, 0.72, 1)
    frame.targetLabel:SetWordWrap(true)

    frame.statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusLabel:SetPoint("TOPLEFT", frame.targetLabel, "BOTTOMLEFT", 0, -10)
    frame.statusLabel:SetWidth(596)
    frame.statusLabel:SetJustifyH("LEFT")
    frame.statusLabel:SetWordWrap(true)
    frame.statusLabel:SetTextColor(0.80, 0.84, 0.88, 1)

    frame.tipAutoShowCheck = Skin:CreateCheckbox(frame, L("TIP_AUTO_SHOW"), true, function(value)
        Tour:SetTipAutoShowEnabled(value)
    end)
    frame.tipAutoShowCheck:SetCompactMode(true)
    frame.tipAutoShowCheck:SetWidth(220)
    frame.tipAutoShowCheck:SetPoint("BOTTOMLEFT", 18, 70)

    frame.buttonSeparator = frame:CreateTexture(nil, "ARTWORK")
    frame.buttonSeparator:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.buttonSeparator:SetPoint("BOTTOMLEFT", 22, 60)
    frame.buttonSeparator:SetPoint("BOTTOMRIGHT", -22, 60)
    frame.buttonSeparator:SetHeight(1)
    frame.buttonSeparator:SetVertexColor(1, 1, 1, 0.10)

    frame.backButton = Skin:CreateButton(frame, L("BUTTON_BACK"), 90, 24)
    frame.backButton:SetPoint("BOTTOMLEFT", 18, 18)
    frame.backButton:SetScript("OnClick", function()
        if Tour.GuideActive then
            Tour:PreviousGuideStep()
        else
            Tour:PreviousStep()
        end
    end)

    frame.skipButton = Skin:CreateButton(frame, L("BUTTON_SKIP_TOUR"), 110, 24)
    frame.skipButton:SetPoint("LEFT", frame.backButton, "RIGHT", 8, 0)
    frame.skipButton:SetScript("OnClick", function()
        if Tour.TipActive then
            Tour:CloseTip()
        elseif Tour.GuideActive then
            Tour:SkipGuide()
        else
            Tour:SkipTour()
        end
    end)

    frame.primaryButton = Skin:CreateButton(frame, L("BUTTON_NEXT_STEP"), 140, 24)
    frame.primaryButton:SetPoint("BOTTOMRIGHT", -18, 18)
    frame.primaryButton:SetScript("OnClick", function()
        if Tour.TipActive then
            Tour:ShowAnotherTip()
        elseif Tour.GuideActive then
            if Tour.GuideCurrentStepIndex and Tour.GuideCurrentStepIndex >= Tour:GetGuideTotalSteps() then
                Tour:CompleteGuide()
            else
                Tour:NextGuideStep()
            end
        else
            if Tour.CurrentStepIndex and Tour.CurrentStepIndex >= Tour:GetTotalSteps() then
                Tour:CompleteTour()
            else
                Tour:NextStep()
            end
        end
    end)

    self.ControlFrame = frame
    return frame
end

function Tour:EnsureHighlightFrame()
    if self.HighlightFrame then
        return self.HighlightFrame
    end

    local frame = CreateFrame("Frame", "WidgetForgeTourHighlightFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(450)
    frame:EnableMouse(false)
    frame:Hide()
    Skin:ApplyBackdrop(frame, 0.02, 0)
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)

    frame.inner = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.inner:SetPoint("TOPLEFT", 2, -2)
    frame.inner:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.inner:EnableMouse(false)
    frame.inner:Hide()
    Skin:ApplyBackdrop(frame.inner, 0.02, 0)
    frame.inner:SetBackdropColor(0, 0, 0, 0)

    frame.shade = frame:CreateTexture(nil, "BACKGROUND")
    frame.shade:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.shade:SetAllPoints()
    frame.shade:SetVertexColor(0, 0, 0, 0)

    self.HighlightFrame = frame
    return frame
end

function Tour:EnsureHighlightProxyFrame()
    if self.HighlightProxyFrame then
        return self.HighlightProxyFrame
    end

    local frame = CreateFrame("Frame", "WidgetForgeTourHighlightProxyFrame", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(440)
    frame:Hide()
    self.HighlightProxyFrame = frame
    return frame
end

function Tour:SetProxyRect(topLeftTarget, bottomRightTarget, leftOffset, topOffset, rightOffset, bottomOffset)
    if not (topLeftTarget and bottomRightTarget) then
        return nil
    end

    local proxy = self:EnsureHighlightProxyFrame()
    proxy:ClearAllPoints()
    proxy:SetPoint("TOPLEFT", topLeftTarget, "TOPLEFT", leftOffset or 0, topOffset or 0)
    proxy:SetPoint("BOTTOMRIGHT", bottomRightTarget, "BOTTOMRIGHT", rightOffset or 0, bottomOffset or 0)
    proxy:Show()
    return proxy
end

function Tour:BuildHighlightTarget(stepID, target)
    local proxy = self:EnsureHighlightProxyFrame()
    proxy:Hide()

    if stepID == "quickstart" and Config and Config.TourAddBarButton then
        return Config.TourAddBarButton
    end

    if stepID == "elements" and Config and Config.TourElementsHeader and type(Config.TourElementAccordions) == "table" then
        local lastVisibleAccordion = nil
        for _, acc in ipairs(Config.TourElementAccordions) do
            if acc and acc.IsShown and acc:IsShown() then
                lastVisibleAccordion = acc
            end
        end

        if lastVisibleAccordion then
            return self:SetProxyRect(Config.TourElementsHeader, lastVisibleAccordion, -2, 2, 0, -2)
        end
    end

    if stepID == "profiles" and Config and Config.TourImportButton and Config.TourExportButton then
        return self:SetProxyRect(Config.TourImportButton, Config.TourExportButton, 0, 0, 0, 0)
    end

    if stepID == "guide_move_bar" and Config and Config.slX and Config.slY then
        local topAnchor = Config.slX.label or Config.slX
        local bottomAnchor = Config.slY
        return self:SetProxyRect(topAnchor, bottomAnchor, -2, 4, 2, -2)
    end

    return target
end

function Tour:ApplyAccentColor(color)
    local frame = self:EnsureControlFrame()
    color = color or self:GetRandomAccentColor()
    frame.currentAccent = color

    Skin:SetSmartBorder(frame, 1, color, "OUTSIDE")
    frame.kicker:SetTextColor(color.r * 0.80 + 0.20, color.g * 0.80 + 0.20, color.b * 0.80 + 0.20, 1)
    frame.progress:SetTextColor(color.r, color.g, color.b, 1)
    frame.title:SetTextColor(1, 1, 1, 1)
    frame.body:SetTextColor(0.92, 0.92, 0.92, 1)
    frame.targetLabel:SetTextColor(color.r * 0.75 + 0.25, color.g * 0.75 + 0.25, color.b * 0.75 + 0.25, 1)
    frame.statusLabel:SetTextColor(0.84, 0.88, 0.92, 1)
    frame.buttonSeparator:SetVertexColor(color.r, color.g, color.b, 0.16)
end

function Tour:SetPrimaryButtonEnabled(enabled)
    local frame = self:EnsureControlFrame()
    local button = frame.primaryButton
    if not button then
        return
    end

    button:SetEnabled(enabled and true or false)
    button:SetAlpha(enabled and 1 or 0.50)

    if button.text then
        if enabled then
            button.text:SetTextColor(1, 1, 1, 1)
        else
            button.text:SetTextColor(0.72, 0.72, 0.72, 1)
        end
    end

    if enabled then
        button:SetBackdropColor(unpack(Skin.Colors.button))
        button:SetBackdropBorderColor(unpack(Skin.Colors.border))
    else
        button:SetBackdropColor(0.10, 0.10, 0.10, 0.90)
        button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    end
end

function Tour:UpdateControlFrame(stepID)
    local frame = self:EnsureControlFrame()
    local step = self:GetStep(stepID)
    local index = self:GetStepIndex(stepID) or 1
    local total = self:GetTotalSteps()

    frame.title:SetText(L(step.titleKey))
    frame.body:SetText(L(step.textKey))
    frame.kicker:SetText(L("MINIMAP_TOOLTIP_TITLE"))
    frame.progress:SetText(L("TOUR_PROGRESS", index, total))
    frame.targetLabel:SetText(step.targetHintKey and L(step.targetHintKey) or "")
    frame.statusLabel:SetText("")
    frame.tipAutoShowCheck:Hide()

    frame.backButton:SetShown(index > 1)
    frame.skipButton:SetShown(index < total)
    frame.backButton:ClearAllPoints()
    frame.backButton:SetPoint("BOTTOMLEFT", 18, 18)
    frame.skipButton:ClearAllPoints()
    frame.skipButton:SetPoint("LEFT", frame.backButton, "RIGHT", 8, 0)
    if frame.skipButton and frame.skipButton.text then
        frame.skipButton.text:SetText(L("BUTTON_SKIP_TOUR"))
    end

    if stepID == "welcome" then
        frame.primaryButton.text:SetText(L("BUTTON_START_TOUR"))
    elseif index >= total then
        frame.primaryButton.text:SetText(L("BUTTON_FINISH_TOUR"))
    else
        frame.primaryButton.text:SetText(L("BUTTON_NEXT_STEP"))
    end

    self:SetPrimaryButtonEnabled(true)
end

function Tour:UpdateGuideControlFrame(stepID)
    local frame = self:EnsureControlFrame()
    local step = self:GetGuideStep(stepID)
    local index = self:GetGuideStepIndex(stepID) or 1
    local total = self:GetGuideTotalSteps()

    frame.title:SetText(L(step.titleKey))
    frame.body:SetText(L(step.textKey))
    frame.kicker:SetText(L("GUIDE_KICKER"))
    frame.progress:SetText(L("TOUR_PROGRESS", index, total))
    frame.targetLabel:SetText(step.targetHintKey and L(step.targetHintKey) or "")
    frame.statusLabel:SetText(L("GUIDE_STATUS_DRAG"))
    frame.tipAutoShowCheck:Hide()

    frame.backButton:SetShown(index > 1)
    frame.skipButton:SetShown(index < total)
    frame.backButton:ClearAllPoints()
    frame.backButton:SetPoint("BOTTOMLEFT", 18, 18)
    frame.skipButton:ClearAllPoints()
    frame.skipButton:SetPoint("LEFT", frame.backButton, "RIGHT", 8, 0)
    if frame.skipButton and frame.skipButton.text then
        frame.skipButton.text:SetText(L("BUTTON_SKIP_GUIDE"))
    end

    if stepID == "guide_intro" then
        frame.primaryButton.text:SetText(L("BUTTON_START_GUIDE"))
    elseif index >= total then
        frame.primaryButton.text:SetText(L("BUTTON_FINISH_GUIDE"))
    else
        frame.primaryButton.text:SetText(L("BUTTON_NEXT_STEP"))
    end

    self:SetPrimaryButtonEnabled(not step.actionRequired)
end

function Tour:UpdateTipControlFrame(index)
    local frame = self:EnsureControlFrame()
    local tip = self:GetTip(index)
    if not tip then
        return
    end

    frame.title:SetText(L(tip.titleKey))
    frame.body:SetText(L(tip.textKey))
    frame.kicker:SetText(L("TIP_KICKER"))
    frame.progress:SetText(L("TIP_PROGRESS"))
    frame.targetLabel:SetText(tip.targetHintKey and L(tip.targetHintKey) or "")
    frame.statusLabel:SetText(L("TIP_STATUS_DRAG"))
    frame.tipAutoShowCheck:SetChecked(self:IsTipAutoShowEnabled())
    frame.tipAutoShowCheck:Show()

    frame.backButton:SetShown(false)
    frame.skipButton:SetShown(true)
    frame.skipButton:ClearAllPoints()
    frame.skipButton:SetPoint("BOTTOMLEFT", 18, 18)
    if frame.skipButton and frame.skipButton.text then
        frame.skipButton.text:SetText(L("BUTTON_CLOSE"))
    end
    frame.primaryButton.text:SetText(L("BUTTON_ANOTHER_TIP"))
    self:SetPrimaryButtonEnabled(true)
end

function Tour:AnchorControlFrame()
    local frame = self:EnsureControlFrame()
    if (self.GuideActive or self.Active or self.TipActive) and frame.wasDragged then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function Tour:HideHelpTip()
    if self.HighlightFrame then
        self.HighlightFrame:Hide()
        if self.HighlightFrame.inner then
            self.HighlightFrame.inner:Hide()
        end
    end
    if self.HighlightProxyFrame then
        self.HighlightProxyFrame:Hide()
    end
end

function Tour:ShowHelpTip(stepID, target)
    self:HideHelpTip()

    if not (target and target.IsShown and target:IsShown()) then
        return
    end

    target = self:BuildHighlightTarget(stepID, target)
    if not (target and target.IsShown and target:IsShown()) then
        return
    end

    local color = self:EnsureControlFrame().currentAccent or self:GetRandomAccentColor()
    local highlight = self:EnsureHighlightFrame()
    local step = self:GetStep(stepID) or self:GetGuideStep(stepID) or {}
    local pad = step.highlightPadding or {}
    local leftPad = tonumber(pad.left) or 0
    local rightPad = tonumber(pad.right) or 0
    local topPad = tonumber(pad.top) or 0
    local bottomPad = tonumber(pad.bottom) or 0

    local viewport = self:GetHighlightViewport(stepID, target)
    if viewport then
        local left, right, top, bottom = self:GetFrameRect(target)
        local viewLeft, viewRight, viewTop, viewBottom = self:GetFrameRect(viewport)
        if not (left and viewLeft) then
            return
        end

        if left < viewLeft or right > viewRight or top > viewTop or bottom < viewBottom then
            return
        end
    end

    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -leftPad, topPad)
    highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", rightPad, -bottomPad)
    highlight:Show()
    Skin:SetSmartBorder(highlight, 1, color, "OUTSIDE")
    highlight:SetBackdropColor(0, 0, 0, 0)

    if highlight.inner then
        highlight.inner:Show()
        Skin:SetSmartBorder(highlight.inner, 1, { r = 1, g = 1, b = 1, a = 0.12 }, "INSIDE")
        highlight.inner:SetBackdropColor(0, 0, 0, 0)
    end
end

function Tour:ShowTipHighlight(index)
    local tip = self:GetTip(index)
    if not tip then
        self:HideHelpTip()
        return
    end

    self:PrepareTip(index)

    local target = self:ResolveTipTarget(index)
    if not target then
        self:HideHelpTip()
        return
    end

    self:ShowHelpTip(tip.id, target)
end

function Tour:ResolveTarget(stepID)
    local step = self:GetStep(stepID)
    if not step or type(step.resolveTarget) ~= "function" then
        return nil
    end
    return step.resolveTarget()
end

function Tour:ResolveGuideTarget(stepID)
    local step = self:GetGuideStep(stepID)
    if not step or type(step.resolveTarget) ~= "function" then
        return nil
    end
    return step.resolveTarget()
end

function Tour:ShowTip(index)
    local tip = self:GetTip(index)
    if not tip then
        return
    end

    if self.CurrentTipIndex ~= index then
        self.PreparedTipIndex = nil
    end
    self.CurrentTipIndex = index
    self:AnchorControlFrame()
    self:ApplyAccentColor(self:GetRandomAccentColor())
    self:UpdateTipControlFrame(index)
    self.ControlFrame:Show()
    self:ShowTipHighlight(index)
end

function Tour:RefreshCurrentHighlight()
    local stepID
    local target

    if self.GuideActive and self.GuideCurrentStepID then
        stepID = self.GuideCurrentStepID
        target = self:ResolveGuideTarget(stepID)
    elseif self.TipActive and self.CurrentTipIndex then
        self:ShowTipHighlight(self.CurrentTipIndex)
        return
    elseif self.Active and self.CurrentStepID then
        stepID = self.CurrentStepID
        target = self:ResolveTarget(stepID)
    end

    if not (stepID and target and target.IsShown and target:IsShown()) then
        self:HideHelpTip()
        return
    end

    self:ShowHelpTip(stepID, target)
end

function Tour:TryShowStep(stepID, retriesRemaining)
    if not self.Active then
        return
    end

    if not self:IsConfigVisible() then
        self.PendingStepID = stepID
        return
    end

    local step = self:GetStep(stepID)
    if not step then
        return
    end

    if type(step.prepare) == "function" then
        step.prepare()
    end

    local target = self:ResolveTarget(stepID)
    if not (target and target.IsShown and target:IsShown()) then
        if (retriesRemaining or 0) > 0 then
            C_Timer.After(0.15, function()
                Tour:TryShowStep(stepID, retriesRemaining - 1)
            end)
            return
        end

        target = Config and Config.Frame
        if not (target and target.IsShown and target:IsShown()) then
            return
        end
    end

    self.CurrentStepID = stepID
    self.CurrentStepIndex = self:GetStepIndex(stepID)
    self.PendingStepID = nil

    local db = self:GetDB()
    if db then
        db.lastStep = stepID
    end

    self:AnchorControlFrame()
    self:ApplyAccentColor(self:GetRandomAccentColor())
    self:UpdateControlFrame(stepID)
    self.ControlFrame:Show()
    self:ShowHelpTip(stepID, target)
end

function Tour:TryShowGuideStep(stepID, retriesRemaining)
    if not self.GuideActive then
        return
    end

    if not self:IsConfigVisible() then
        return
    end

    local step = self:GetGuideStep(stepID)
    if not step then
        return
    end

    if type(step.prepare) == "function" then
        SafeCall(step.prepare, self)
    end

    local target = self:ResolveGuideTarget(stepID)
    if not (target and target.IsShown and target:IsShown()) then
        if (retriesRemaining or 0) > 0 then
            C_Timer.After(0.15, function()
                Tour:TryShowGuideStep(stepID, retriesRemaining - 1)
            end)
            return
        end

        target = Config and Config.Frame
        if not (target and target.IsShown and target:IsShown()) then
            return
        end
    end

    self.GuideCurrentStepID = stepID
    self.GuideCurrentStepIndex = self:GetGuideStepIndex(stepID)
    self.GuideStepComplete = false

    if type(step.onEnter) == "function" then
        SafeCall(step.onEnter, self, self.GuideContext or {})
    end

    self:AnchorControlFrame()
    self:ApplyAccentColor(self:GetRandomAccentColor())
    self:UpdateGuideControlFrame(stepID)
    self.ControlFrame:Show()
    self:ShowHelpTip(stepID, target)
    self:RefreshGuideStepState()
end

function Tour:ShowStep(stepID)
    self:TryShowStep(stepID, 8)
end

function Tour:ShowGuideStep(stepID)
    self:TryShowGuideStep(stepID, 8)
end

function Tour:Start(force)
    local db = self:GetDB()
    if not db then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        self.PendingAutoStart = true
        return false
    end

    if self.GuideActive then
        self:EndGuideSession()
    end
    if self.TipActive then
        self:EndTipSession()
    end

    self:EnsureConfigOpen()
    self.Active = true
    if self.ControlFrame then
        self.ControlFrame.wasDragged = false
    end
    self.PendingAutoStart = false
    if force then
        db.dismissedVersion = 0
    end

    self:ShowStep("welcome")
    return true
end

function Tour:StartGuide(force)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if self.GuideActive then
        self:EndGuideSession()
    end

    if self.TipActive then
        self:EndTipSession()
    end

    if self.Active then
        self:EndSession()
    end

    self.PendingAutoStart = false
    self:EnsureConfigOpen()
    self.GuideActive = true
    if self.ControlFrame then
        self.ControlFrame.wasDragged = false
    end
    self.GuideContext = {
        startedBarCount = self:GetBarCount(),
    }

    if force then
        self.GuideCurrentStepID = nil
        self.GuideCurrentStepIndex = nil
    end

    self:ShowGuideStep("guide_intro")
    return true
end

function Tour:StartTipOfDay(force)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if self.TipActive then
        self:EndTipSession()
    end

    if self.Active then
        self:EndSession()
    end

    if self.GuideActive then
        self:EndGuideSession()
    end

    self:EnsureConfigOpen()
    self.TipActive = true
    if self.ControlFrame then
        self.ControlFrame.wasDragged = false
    end

    local db = self:GetDB()
    local tipIndex = self:PickRandomTipIndex(db and db.tips and db.tips.lastTipIndex or nil)
    if not tipIndex then
        self.TipActive = false
        return false
    end

    if db and db.tips then
        db.tips.lastShownDate = self:GetTodayKey()
        db.tips.lastTipIndex = tipIndex
    end

    self:ShowTip(tipIndex)
    return true
end

function Tour:ShowAnotherTip()
    if not self.TipActive then
        return
    end

    local current = self.CurrentTipIndex
    local nextIndex = self:PickRandomTipIndex(current)
    if not nextIndex then
        return
    end

    local db = self:GetDB()
    if db and db.tips then
        db.tips.lastShownDate = self:GetTodayKey()
        db.tips.lastTipIndex = nextIndex
    end

    self:ShowTip(nextIndex)
end

function Tour:ResumeIfNeeded()
    local db = self:GetDB()
    if not db or not self.Active then
        return
    end

    self:ShowStep(db.lastStep or self.PendingStepID or "welcome")
end

function Tour:ResumeGuideIfNeeded()
    if not self.GuideActive then
        return
    end

    self:ShowGuideStep(self.GuideCurrentStepID or "guide_intro")
end

function Tour:ResumeTipIfNeeded()
    if not self.TipActive then
        return
    end

    self:ShowTip(self.CurrentTipIndex or self:PickRandomTipIndex(nil))
end

function Tour:PauseTour()
    self:HideHelpTip()
    if self.ControlFrame and not self.GuideActive then
        self.ControlFrame:Hide()
    end
end

function Tour:PauseGuide()
    self:HideHelpTip()
    if self.ControlFrame then
        self.ControlFrame:Hide()
    end
end

function Tour:PauseTip()
    self:HideHelpTip()
    if self.ControlFrame then
        self.ControlFrame:Hide()
    end
end

function Tour:EndSession()
    self.Active = false
    self.PendingStepID = nil
    self.CurrentStepID = nil
    self.CurrentStepIndex = nil
    self:HideHelpTip()
    if self.ControlFrame then
        self.ControlFrame:Hide()
    end
end

function Tour:EndGuideSession()
    self.GuideActive = false
    self.GuideCurrentStepID = nil
    self.GuideCurrentStepIndex = nil
    self.GuideContext = nil
    self.GuideStepComplete = false
    self:HideHelpTip()
    if self.ControlFrame then
        self.ControlFrame:Hide()
    end
end

function Tour:EndTipSession()
    self.TipActive = false
    self.CurrentTipIndex = nil
    self.PreparedTipIndex = nil
    self:HideHelpTip()
    if self.ControlFrame then
        self.ControlFrame:Hide()
    end
end

function Tour:SkipTour()
    local db = self:GetDB()
    if db then
        db.dismissedVersion = self.VERSION
        db.lastStep = nil
    end
    self:EndSession()
    print("|cff00ccffWidgetForge|r " .. L("MSG_TOUR_SKIPPED"))
end

function Tour:SkipGuide()
    self:EndGuideSession()
    print("|cff00ccffWidgetForge|r " .. L("MSG_GUIDE_SKIPPED"))
end

function Tour:CloseTip()
    self:EndTipSession()
end

function Tour:CompleteTour()
    local db = self:GetDB()
    if db then
        db.versionSeen = self.VERSION
        db.dismissedVersion = 0
        db.lastStep = nil
    end
    self:EndSession()
end

function Tour:CompleteGuide()
    self:EndGuideSession()
end

function Tour:ResetProgress()
    local db = self:GetDB()
    if not db then
        return
    end

    db.versionSeen = 0
    db.dismissedVersion = 0
    db.lastStep = nil
    self:EndSession()
end

function Tour:NextStep()
    local currentIndex = self.CurrentStepIndex or self:GetStepIndex(self.CurrentStepID) or 1
    local nextID = self.StepOrder[currentIndex + 1]
    if nextID then
        self:ShowStep(nextID)
    else
        self:CompleteTour()
    end
end

function Tour:PreviousStep()
    local currentIndex = self.CurrentStepIndex or self:GetStepIndex(self.CurrentStepID) or 1
    local prevID = self.StepOrder[currentIndex - 1]
    if prevID then
        self:ShowStep(prevID)
    end
end

function Tour:IsGuideStepComplete(stepID)
    local step = self:GetGuideStep(stepID)
    if not step then
        return false
    end

    if not step.actionRequired then
        return true
    end

    if type(step.isComplete) == "function" then
        local ok, result = SafeCall(step.isComplete, self, self.GuideContext or {})
        return ok and result or false
    end

    return false
end

function Tour:RefreshGuideStepState()
    if not (self.GuideActive and self.GuideCurrentStepID and self.ControlFrame and self.ControlFrame:IsShown()) then
        return
    end

    local frame = self:EnsureControlFrame()
    local step = self:GetGuideStep(self.GuideCurrentStepID)
    if not step then
        return
    end

    local complete = self:IsGuideStepComplete(self.GuideCurrentStepID)
    self.GuideStepComplete = complete

    if step.actionRequired then
        if complete then
            frame.statusLabel:SetText(L("GUIDE_STATUS_READY"))
            self:SetPrimaryButtonEnabled(true)
        else
            frame.statusLabel:SetText(L("GUIDE_STATUS_WAITING"))
            self:SetPrimaryButtonEnabled(false)
        end
    else
        frame.statusLabel:SetText(L("GUIDE_STATUS_DRAG"))
        self:SetPrimaryButtonEnabled(true)
    end
end

function Tour:NextGuideStep()
    local currentID = self.GuideCurrentStepID
    local currentIndex = self.GuideCurrentStepIndex or self:GetGuideStepIndex(currentID) or 1
    local currentStep = currentID and self:GetGuideStep(currentID) or nil

    if currentStep and currentStep.actionRequired and not self:IsGuideStepComplete(currentID) then
        self:RefreshGuideStepState()
        return
    end

    if currentStep and type(currentStep.afterComplete) == "function" then
        SafeCall(currentStep.afterComplete, self, self.GuideContext or {})
    end

    local nextID = self.GuideStepOrder[currentIndex + 1]
    if nextID then
        self:ShowGuideStep(nextID)
    else
        self:CompleteGuide()
    end
end

function Tour:PreviousGuideStep()
    local currentIndex = self.GuideCurrentStepIndex or self:GetGuideStepIndex(self.GuideCurrentStepID) or 1
    local prevID = self.GuideStepOrder[currentIndex - 1]
    if prevID then
        self:ShowGuideStep(prevID)
    end
end

function Tour:HandleConfigOpened()
    self:AnchorControlFrame()

    if self.TipActive then
        self:ResumeTipIfNeeded()
        return
    end

    if self.GuideActive then
        self:ResumeGuideIfNeeded()
        return
    end

    if self.Active then
        self:ResumeIfNeeded()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.PendingAutoStart = self.PendingAutoStart or self:ShouldAutoStart()
        return
    end

    local db = self:GetDB()
    if db and db.lastStep and db.versionSeen < self.VERSION and db.dismissedVersion < self.VERSION then
        self.Active = true
        self:ResumeIfNeeded()
        return
    end

    if self:ShouldAutoStart() then
        self.PendingAutoStart = false
        C_Timer.After(0.2, function()
            if Tour:IsConfigVisible() and not Tour.Active and not Tour.GuideActive then
                Tour:Start(false)
            end
        end)
        return
    end

    if self:ShouldAutoShowTip() then
        C_Timer.After(0.35, function()
            if Tour:IsConfigVisible() and not Tour.Active and not Tour.GuideActive and not Tour.TipActive then
                Tour:StartTipOfDay(false)
            end
        end)
    end
end

function Tour:HandleConfigClosed()
    if self.TipActive then
        self:PauseTip()
    end
    if self.GuideActive then
        self:PauseGuide()
    end
    if self.Active then
        self:PauseTour()
    end
end

function Tour:HandleCombatEnded()
    if self.TipActive and self:IsConfigVisible() then
        self:ResumeTipIfNeeded()
        return
    end

    if self.GuideActive and self:IsConfigVisible() then
        self:ResumeGuideIfNeeded()
        return
    end

    if self.PendingAutoStart and self:IsConfigVisible() then
        self.PendingAutoStart = false
        self:Start(false)
    elseif self.Active and self:IsConfigVisible() then
        self:ResumeIfNeeded()
    end
end
