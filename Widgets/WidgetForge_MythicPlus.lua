
local addonName, addonTable = ...
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.MythicPlus = {}
local MPlus = _G.WidgetForge.MythicPlus
addonTable.MythicPlus = MPlus
local L = WFL
MPlus.Instances = {}
MPlus.GlobalState = {
    activeRun = false,
    currentTime = 0,
    timeLimit = 0,
    threeChestLimit = 0,
    twoChestLimit = 0,
    enemyForces = { cur = 0, max = 100, pct = 0 },
    bosses = {},
    splits = {},
    bossStatus = {},
    bestRunCompare = nil,
    affixIDs = {}
}
MPlus.initialized = false
MPlus.hiddenFrame = nil
local function GetChallengeElapsedTime()
    local num = GetNumWorldElapsedTimers and GetNumWorldElapsedTimers() or 0
    for i = 1, num do
        local timerType, elapsed = GetWorldElapsedTime(i)
        if timerType == 2 then 
            return elapsed
        end
    end
    if GetWorldElapsedTime then
        local _, t = GetWorldElapsedTime(1)
        if t and t >= 0 then return t end
    end
    return nil
end
function MPlus:InitGlobal()
    if MPlus.initialized then return end
    if not _G.WidgetForgeDB then return end
    if not _G.WidgetForgeDB.MythicPlus then
        _G.WidgetForgeDB.MythicPlus = {
            History = {},
            Settings = {
                showEnemyForcesAbsolute = true,
                autoKeystone = true,
                autoCloseBags = true,
                hideBlizzardTracker = true,
                splitComparisonMode = "LEVEL",
                autoSize = true,
                hoverExpand = false,
                showAffixes = true,
                showBosses = true,
                showTimer = true,
                showForces = true,
                showDeathCounter = true,
                timerChunk1Color = {0.30, 0.69, 0.49, 1},
                timerChunk2Color = {1.00, 0.55, 0.26, 1},
                timerChunk3Color = {0.90, 0.22, 0.27, 1}
            }
        }
    end
    _G.WidgetForgeDB.MythicPlus.History = _G.WidgetForgeDB.MythicPlus.History or {}
    MPlus.config = _G.WidgetForgeDB.MythicPlus
    MPlus.hiddenFrame = CreateFrame("Frame")
    MPlus.hiddenFrame:Hide()
    MPlus:RegisterEvents()
    MPlus.initialized = true
end
function MPlus:IsWidgetActive()
    if not MPlus.Instances or #MPlus.Instances == 0 then return false end
    local hasActive = false
    for i = #MPlus.Instances, 1, -1 do
        local inst = MPlus.Instances[i]
        local isOrphan = true
        if _G.WidgetForgeDB and _G.WidgetForgeDB.bars and _G.WidgetForge and _G.WidgetForge.IsBarRelevant then
            for _, bar in ipairs(_G.WidgetForgeDB.bars) do
                if bar.enabled and _G.WidgetForge:IsBarRelevant(bar) then
                    if bar.elements then
                        for _, e in ipairs(bar.elements) do
                            if e == inst.elem then
                                isOrphan = false
                                hasActive = true
                                break
                            end
                        end
                    end
                end
                if not isOrphan then break end
            end
        end
        if isOrphan then
            inst:Hide()
            inst:SetParent(nil)
            table.remove(MPlus.Instances, i)
        end
    end
    return hasActive
end
function MPlus:DisableRuntimeState()
    MPlus.GlobalState.activeRun = false
    MPlus.GlobalState.isCompleted = false
    MPlus.suppressBags = false
    MPlus:ShowDefaultTracker()
end
function MPlus:SyncStateFromGame()
    if not MPlus:IsWidgetActive() then
        MPlus:DisableRuntimeState()
        return false
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        local state = MPlus.GlobalState
        state.activeRun = true
        state.isCompleted = false
        state.splits = state.splits or {}
        state.runStartTime = state.runStartTime or GetTime()
        if C_ChallengeMode.GetActiveChallengeMapID then
            local mapID = C_ChallengeMode.GetActiveChallengeMapID()
            local level = C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo() or nil
            if mapID then
                state.mapID = mapID
                state.bestRunCompare = MPlus:GetBestRun(mapID, level)
            end
            if level and level > 0 then
                state.keystoneLevel = level
            end
        end
        MPlus:UpdateTimerData()
        MPlus:UpdateObjectivesData()
    else
        MPlus.GlobalState.activeRun = false
        MPlus.GlobalState.bestRunCompare = nil
        MPlus:ShowDefaultTracker()
    end
    return true
end
local function CreateMythicPlusUtilityButtons()
    if ChallengesKeystoneFrame.WidgetForgeButtonsCreated then return end
    local readyBtn = CreateFrame("Button", "WFMPlusReadyBtn", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
    readyBtn:SetSize(110, 25)
    readyBtn:SetText(L("BUTTON_READY_CHECK"))
    readyBtn:SetPoint("BOTTOMLEFT", ChallengesKeystoneFrame, "BOTTOMLEFT", 21, 20)
    readyBtn:SetScript("OnClick", function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
        else
            print("|cffff0000[WidgetForge]|r " .. L("ERR_READY_CHECK_LEADER"))
        end
    end)
    local pullBtn = CreateFrame("Button", "WFMPlusPullBtn", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
    pullBtn:SetSize(110, 25)
    pullBtn:SetText(L("BUTTON_PULL_10S"))
    pullBtn:SetPoint("BOTTOMRIGHT", ChallengesKeystoneFrame, "BOTTOMRIGHT", -21, 20)
    pullBtn:SetScript("OnClick", function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            C_PartyInfo.DoCountdown(10)
        else
            print("|cffff0000[WidgetForge]|r " .. L("ERR_PULL_LEADER"))
        end
    end)
    ChallengesKeystoneFrame.WidgetForgeButtonsCreated = true
end
function MPlus:HookKeystoneFrame()
    if MPlus.keystoneHooked then return end
    if not ChallengesKeystoneFrame then return end
    MPlus.keystoneHooked = true
    ChallengesKeystoneFrame:HookScript("OnShow", function()
        local isWidgetActive = MPlus:IsWidgetActive()
        if not isWidgetActive then
            if WFMPlusReadyBtn then WFMPlusReadyBtn:Hide() end
            if WFMPlusPullBtn then WFMPlusPullBtn:Hide() end
            return
        end
        if MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
            C_Timer.After(0.3, function()
                local stillActive = MPlus:IsWidgetActive()
                if stillActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
                    MPlus:TrySlotKeystone()
                end
            end)
        end
        CreateMythicPlusUtilityButtons()
        if WFMPlusReadyBtn then WFMPlusReadyBtn:Show() end
        if WFMPlusPullBtn then WFMPlusPullBtn:Show() end
        if MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoCloseBags then
            MPlus.suppressBags = true
            CloseAllBags()
            C_Timer.After(0.1, function() MPlus.suppressBags = false end)
        end
    end)
    if not MPlus.keystoneHiddenHooked then
        ChallengesKeystoneFrame:HookScript("OnHide", function()
             MPlus.suppressBags = false
        end)
        MPlus.keystoneHiddenHooked = true
    end
    if not MPlus.openAllBagsHooked then
        hooksecurefunc("OpenAllBags", function()
            local isActive = MPlus:IsWidgetActive()
            if isActive and MPlus.suppressBags then
                CloseAllBags()
            end
        end)
        MPlus.openAllBagsHooked = true
    end
end
local function CreateProgressBar(parent, labelText)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    bar:SetHeight(18)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:GetStatusBarTexture():SetHorizTile(false)
    local Skin = _G.ForgeSkin
    if Skin then
        Skin:ApplyBackdrop(bar, 0.4, 0.6)
        bar:SetStatusBarColor(unpack(Skin.Colors.accent))
    end
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
    bar.label:SetText(labelText)
    bar.marker2 = bar:CreateTexture(nil, "OVERLAY")
    bar.marker2:SetColorTexture(1.00, 0.55, 0.26, 0.8) 
    bar.marker2:SetSize(2, 18)
    bar.marker2:Hide()
    bar.marker3 = bar:CreateTexture(nil, "OVERLAY")
    bar.marker3:SetColorTexture(0.30, 0.69, 0.49, 0.8) 
    bar.marker3:SetSize(2, 18)
    bar.marker3:Hide()
    bar.chunk1 = CreateFrame("StatusBar", nil, bar, "BackdropTemplate")
    bar.chunk2 = CreateFrame("StatusBar", nil, bar, "BackdropTemplate")
    bar.chunk3 = CreateFrame("StatusBar", nil, bar, "BackdropTemplate")
    local c1text = CreateFrame("Frame", nil, bar.chunk1)
    c1text:SetAllPoints()
    c1text:SetFrameLevel(bar.chunk1:GetFrameLevel() + 5)
    bar.chunk1.text = c1text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.chunk1.text:SetPoint("CENTER", 0, 0)
    local c2text = CreateFrame("Frame", nil, bar.chunk2)
    c2text:SetAllPoints()
    c2text:SetFrameLevel(bar.chunk2:GetFrameLevel() + 5)
    bar.chunk2.text = c2text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.chunk2.text:SetPoint("CENTER", 0, 0)
    local c3text = CreateFrame("Frame", nil, bar.chunk3)
    c3text:SetAllPoints()
    c3text:SetFrameLevel(bar.chunk3:GetFrameLevel() + 5)
    bar.chunk3.text = c3text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.chunk3.text:SetPoint("CENTER", 0, 0)
    for _, chunk in ipairs({bar.chunk1, bar.chunk2, bar.chunk3}) do
        chunk:SetHeight(18)
        chunk:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        if Skin then Skin:ApplyBackdrop(chunk, 0.4, 0.6) end
        chunk:Hide()
    end
    return bar
end
function MPlus:HideDefaultTracker()
    if not MPlus:IsWidgetActive() then return end
    if not MPlus.config.Settings.hideBlizzardTracker then return end
    if not MPlus.GlobalState.activeRun then return end
    local in_combat = InCombatLockdown() or UnitAffectingCombat("player")
    if not in_combat and ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame:GetParent() ~= MPlus.hiddenFrame then
            MPlus.originalTrackerParent = ObjectiveTrackerFrame:GetParent()
            ObjectiveTrackerFrame:SetParent(MPlus.hiddenFrame)
        end
    end
end
function MPlus:ShowDefaultTracker()
    local in_combat = InCombatLockdown() or UnitAffectingCombat("player")
    if not in_combat and ObjectiveTrackerFrame and MPlus.originalTrackerParent then
        if ObjectiveTrackerFrame:GetParent() == MPlus.hiddenFrame then
            ObjectiveTrackerFrame:SetParent(MPlus.originalTrackerParent)
        end
    end
end
function MPlus:Load(parent, elem)
    MPlus:InitGlobal()
    local Skin = _G.ForgeSkin
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("CENTER", parent, "CENTER") 
    container.elem = elem
    container.isHovered = false
    if Skin and Skin.ApplyBackdrop then
        Skin:ApplyBackdrop(container)
        container:SetBackdropColor(unpack(elem.bgColor or {0, 0, 0, 0.5}))
        container:SetBackdropBorderColor(0, 0, 0, 0)
    end
    container.affixFrame = CreateFrame("Frame", nil, container)
    container.affixFrame:SetSize(120, 24)
    container.affixFrame.icons = {}
    container.bossList = CreateFrame("Frame", nil, container)
    container.bossList.rows = {}
    container.timerBar = CreateProgressBar(container, "RUN TIMER")
    container.timerBar:SetMinMaxValues(0, 100)
    container.forcesBar = CreateProgressBar(container, "ENEMY FORCES")
    container.forcesBar:SetMinMaxValues(0, 100)
    container.deathCount = container:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    container.deathCount:SetJustifyH("LEFT") 
    container.deathCount:SetText("")
    container.keyLevel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.keyLevel:SetJustifyH("RIGHT")
    container.keyLevel:SetTextColor(0, 0.8, 1, 1)
    container.keyLevel:SetText("")
    table.insert(MPlus.Instances, container)
    container:SetScript("OnUpdate", function(self)
        if MPlus.config.Settings.hoverExpand then
            local hovered = self:IsMouseOver()
            if self.isHovered ~= hovered then
                self.isHovered = hovered
                MPlus:UpdateLayout(self)
            end
        end
    end)
    container.Unload = function(self)
        for i, inst in ipairs(MPlus.Instances) do
            if inst == self then table.remove(MPlus.Instances, i); break end
        end
    end
    MPlus:SyncStateFromGame()
    MPlus:CheckVisibility(container)
    MPlus:UpdateVisuals(container)
    return container
end
function MPlus:UpdateLayout(container)
    if not container then return end
    local conf = MPlus.config.Settings
    local state = MPlus.GlobalState
    local width = container.elem.widgetWidth or 300
    container:SetWidth(width)
    local y = -10
    local padding = 5
    local showAffixes = conf.showAffixes ~= false
    local showBosses = conf.showBosses ~= false
    local showTimer = conf.showTimer ~= false
    local showForces = conf.showForces ~= false
    local showDeaths = conf.showDeathCounter ~= false
    local isCompact = conf.hoverExpand and not container.isHovered
    if isCompact then
        showBosses = false
        showAffixes = false
        showDeaths = false
    end
    container.keyLevel:ClearAllPoints()
    container.keyLevel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -8)
    if showTimer then
        y = y - 12
        container.timerBar:Show()
        container.timerBar:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        container.timerBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y)
        y = y - 18 - padding
    else
        container.timerBar:Hide()
    end
    if showForces then
        y = y - 12
        container.forcesBar:Show()
        container.forcesBar:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        container.forcesBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y)
        y = y - 18 - padding
    else
        container.forcesBar:Hide()
    end
    if (showTimer or showForces) and showBosses then
        y = y - 5
    end
    if showBosses and state.bosses and #state.bosses > 0 then
        container.bossList:Show()
        container.bossList:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        container.bossList:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y) 
        local bossHeight = #state.bosses * 20
        container.bossList:SetHeight(bossHeight)
        y = y - bossHeight - padding
    else
        container.bossList:Hide()
    end
    local bottomRowHeight = 0
    local hasBottomRow = false
    if showDeaths then
        container.deathCount:Show()
        container.deathCount:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 10, 10)
        bottomRowHeight = math.max(bottomRowHeight, 14)
        hasBottomRow = true
    else
        container.deathCount:Hide()
    end
    if showAffixes and state.affixIDs and #state.affixIDs > 0 then
        container.affixFrame:Show()
        container.affixFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 10)
        bottomRowHeight = math.max(bottomRowHeight, 24)
        hasBottomRow = true
    else
        container.affixFrame:Hide()
    end
    if hasBottomRow then
        y = y - bottomRowHeight - 10
    end
    if isCompact then
        y = y - 5
    end
    local finalHeight = math.abs(y)
    if not conf.autoSize and container.elem.widgetHeight then
        finalHeight = container.elem.widgetHeight
    end
    container:SetHeight(finalHeight)
    if conf.autoSize then
        if container.elem.widgetHeight ~= finalHeight then
            container.elem.widgetHeight = finalHeight
            local parentBar = container:GetParent()
            if parentBar and parentBar.index and _G.WidgetForge and _G.WidgetForge.UpdateBarValues then
                C_Timer.After(0.01, function()
                    _G.WidgetForge:UpdateBarValues(parentBar.index, true)
                end)
            end
        end
    end
end
function MPlus:UpdateVisuals(container)
    if not container or not container:IsShown() then return end
    local state = MPlus.GlobalState
    local conf = MPlus.config.Settings
    local Skin = _G.ForgeSkin
    local barTexture = conf.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    if container.SetBackdropColor then
        container:SetBackdropColor(unpack(container.elem.bgColor or {0, 0, 0, 0.5}))
    end
    MPlus:UpdateLayout(container)
    if state.currentTime and state.timeLimit and state.timeLimit > 0 then
        local mode = conf.timerChestMode or "LINES"
        container.timerBar.chunk1:Hide()
        container.timerBar.chunk2:Hide()
        container.timerBar.chunk3:Hide()
        container.timerBar.marker2:Hide()
        container.timerBar.marker3:Hide()
        local timeLeft = state.timeLimit - state.currentTime
        local isOver = timeLeft < 0
        local color = isOver and "|cffffff00" or "|cffffffff"
        if mode == "SPLIT" and state.threeChestLimit > 0 and state.twoChestLimit > 0 then
            container.timerBar.text:SetText("") 
            container.timerBar:SetStatusBarTexture("")
            if container.timerBar.SetBackdropColor then container.timerBar:SetBackdropColor(0,0,0,0) end
            if container.timerBar.SetBackdropBorderColor then container.timerBar:SetBackdropBorderColor(0,0,0,0) end
            container.timerBar.chunk1:Show()
            container.timerBar.chunk2:Show()
            container.timerBar.chunk3:Show()
            local w = container.timerBar:GetWidth()
            local gap = 4
            local pct3 = state.threeChestLimit / state.timeLimit
            local pct2 = state.twoChestLimit / state.timeLimit
            local w1 = math.max(1, (w * pct3) - gap)
            local w2 = math.max(1, (w * (pct2 - pct3)) - gap)
            local w3 = math.max(1, w - w1 - w2 - (gap * 2))
            if not container.timerBar.chunk1.laidOut then
                container.timerBar.chunk1:SetPoint("LEFT", container.timerBar, "LEFT", 0, 0)
                container.timerBar.chunk2:SetPoint("LEFT", container.timerBar.chunk1, "RIGHT", gap, 0)
                container.timerBar.chunk3:SetPoint("LEFT", container.timerBar.chunk2, "RIGHT", gap, 0)
                container.timerBar.chunk1.laidOut = true
            end
            if math.abs(container.timerBar.chunk1:GetWidth() - w1) > 0.1 then
                container.timerBar.chunk1:SetWidth(w1)
                container.timerBar.chunk2:SetWidth(w2)
                container.timerBar.chunk3:SetWidth(w3)
            end
            local _, curMax1 = container.timerBar.chunk1:GetMinMaxValues()
            if curMax1 ~= state.threeChestLimit then
                container.timerBar.chunk1:SetMinMaxValues(0, state.threeChestLimit)
                container.timerBar.chunk2:SetMinMaxValues(0, state.twoChestLimit - state.threeChestLimit)
                container.timerBar.chunk3:SetMinMaxValues(0, state.timeLimit - state.twoChestLimit)
                container.timerBar.chunk1:SetValue(0)
                container.timerBar.chunk2:SetValue(0)
                container.timerBar.chunk3:SetValue(0)
            end
            local val1 = math.min(state.threeChestLimit, state.currentTime)
            local val2 = math.max(0, math.min(state.twoChestLimit - state.threeChestLimit, state.currentTime - state.threeChestLimit))
            local val3 = math.max(0, state.currentTime - state.twoChestLimit)
            if math.abs(container.timerBar.chunk1:GetValue() - val1) > 0.05 then container.timerBar.chunk1:SetValue(val1) end
            if math.abs(container.timerBar.chunk2:GetValue() - val2) > 0.05 then container.timerBar.chunk2:SetValue(val2) end
            if math.abs(container.timerBar.chunk3:GetValue() - val3) > 0.05 then container.timerBar.chunk3:SetValue(val3) end
            local f1 = math.max(0, state.threeChestLimit - state.currentTime)
            local f2 = math.max(0, state.twoChestLimit - state.currentTime)
            local f3 = state.timeLimit - state.currentTime  
            container.timerBar.chunk1.text:SetText(format("%02d:%02d", f1 / 60, f1 % 60))
            container.timerBar.chunk2.text:SetText(format("%02d:%02d", f2 / 60, f2 % 60))
            if f3 < 0 then
                container.timerBar.chunk3.text:SetText(format("|cffffff00-%02d:%02d|r", abs(f3) / 60, abs(f3) % 60))
            else
                container.timerBar.chunk3.text:SetText(format("%02d:%02d", f3 / 60, f3 % 60))
            end
            if container.timerBar.chunk1.texHash ~= barTexture then
                container.timerBar.chunk1:SetStatusBarTexture(barTexture)
                container.timerBar.chunk2:SetStatusBarTexture(barTexture)
                container.timerBar.chunk3:SetStatusBarTexture(barTexture)
                container.timerBar.chunk1.texHash = barTexture
            end
            container.timerBar.chunk1:SetStatusBarColor(unpack(conf.timerChunk1Color or {0.30, 0.69, 0.49, 1}))
            container.timerBar.chunk2:SetStatusBarColor(unpack(conf.timerChunk2Color or {1.00, 0.55, 0.26, 1}))
            container.timerBar.chunk3:SetStatusBarColor(unpack(conf.timerChunk3Color or {0.90, 0.22, 0.27, 1}))
            local _, curMax0 = container.timerBar:GetMinMaxValues()
            if curMax0 ~= state.timeLimit then
                container.timerBar:SetMinMaxValues(0, state.timeLimit)
                container.timerBar:SetValue(0)
            end
        else
            container.timerBar.text:SetText(format("%s%02d:%02d|r / %02d:%02d", color, abs(timeLeft) / 60, abs(timeLeft) % 60, state.timeLimit / 60, state.timeLimit % 60))
            if container.timerBar.texHash ~= barTexture then
                container.timerBar:SetStatusBarTexture(barTexture)
                container.timerBar.texHash = barTexture
            end
            if container.timerBar.SetBackdropColor then container.timerBar:SetBackdropColor(0,0,0,0.6) end
            if container.timerBar.SetBackdropBorderColor then container.timerBar:SetBackdropBorderColor(0,0,0,1) end
            local _, curMax0 = container.timerBar:GetMinMaxValues()
            if curMax0 ~= state.timeLimit then
                container.timerBar:SetMinMaxValues(0, state.timeLimit)
            end
            if math.abs(container.timerBar:GetValue() - state.currentTime) > 0.05 then
                container.timerBar:SetValue(state.currentTime)
            end
            if conf.dynamicTimerColor ~= false then
                if state.currentTime < state.threeChestLimit then container.timerBar:SetStatusBarColor(0.30, 0.69, 0.49, 1) 
                elseif state.currentTime < state.twoChestLimit then container.timerBar:SetStatusBarColor(1.00, 0.55, 0.26, 1) 
                else container.timerBar:SetStatusBarColor(0.90, 0.22, 0.27, 1) end
            else
                container.timerBar:SetStatusBarColor(unpack(conf.timerColor or {0, 0.8, 1, 1}))
            end
            if mode == "LINES" and state.threeChestLimit > 0 and state.twoChestLimit > 0 then
                local barWidth = container.timerBar:GetWidth()
                local pct3 = state.threeChestLimit / state.timeLimit
                local pct2 = state.twoChestLimit / state.timeLimit
                container.timerBar.marker3:Show()
                container.timerBar.marker3:ClearAllPoints()
                container.timerBar.marker3:SetPoint("LEFT", container.timerBar, "LEFT", barWidth * pct3, 0)
                container.timerBar.marker2:Show()
                container.timerBar.marker2:ClearAllPoints()
                container.timerBar.marker2:SetPoint("LEFT", container.timerBar, "LEFT", barWidth * pct2, 0)
            end
        end
    else
        container.timerBar:SetValue(0)
        container.timerBar.text:SetText("00:00 / 00:00")
        container.timerBar.marker2:Hide()
        container.timerBar.marker3:Hide()
        if container.timerBar.chunk1 then container.timerBar.chunk1:Hide() end
        if container.timerBar.chunk2 then container.timerBar.chunk2:Hide() end
        if container.timerBar.chunk3 then container.timerBar.chunk3:Hide() end
    end
    if state.enemyForces then
        container.forcesBar:SetValue(state.enemyForces.pct)
        container.forcesBar:SetStatusBarTexture(barTexture)
        local fmt = conf.showEnemyForcesAbsolute and format("%.1f%% (%d/%d)", state.enemyForces.pct, state.enemyForces.cur, state.enemyForces.max) or format("%.2f%%", state.enemyForces.pct)
        container.forcesBar.text:SetText(fmt)
        container.forcesBar:SetStatusBarColor(unpack(conf.forcesColor or {0.8, 0, 0, 1}))
    end
    if state.bosses then
        local spacing = 20
        local mediaPath = "Interface\\AddOns\\WidgetForge\\media\\"
        for i, boss in ipairs(state.bosses) do
            local row = container.bossList.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, container.bossList)
                row:SetHeight(18)
                row.box = row:CreateTexture(nil, "OVERLAY")
                row.box:SetSize(12, 12)
                row.box:SetPoint("LEFT", row, "LEFT", 0, 0) 
                row.box:SetTexture(mediaPath .. "square_emty.tga")
                row.check = row:CreateTexture(nil, "OVERLAY")
                row.check:SetSize(12, 12)
                row.check:SetPoint("CENTER", row.box, "CENTER", 0, 0)
                row.check:SetTexture(mediaPath .. "square_full.tga")
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetPoint("LEFT", row.box, "RIGHT", 5, 0) 
                local bossFont = (Skin and Skin.Constants and Skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
                row.name:SetFont(bossFont, 11, "OUTLINE")
                row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.time:SetPoint("RIGHT", row, "RIGHT", 0, 0) 
                container.bossList.rows[i] = row
            end
            row:Show()
            row:SetPoint("TOPLEFT", container.bossList, "TOPLEFT", 0, -(i-1) * spacing)
            row:SetPoint("TOPRIGHT", container.bossList, "TOPRIGHT", 0, -(i-1) * spacing)
            if boss.done then
                row.name:SetText(boss.name .. " (" .. L("STATUS_DEFEATED") .. ")")
                row.name:SetTextColor(1, 0.2, 0.2, 1) 
                row.check:Show()
                row.check:SetVertexColor(0, 0.8, 1, 1) 
                row.box:SetVertexColor(0.2, 0.2, 0.2, 1)
                local split = state.splits and state.splits[boss.id]
                if split and conf.showSplits ~= false then
                    local text = format("[%d:%02d]", split / 60, split % 60)
                    if state.bestRunCompare and state.bestRunCompare.splits and state.bestRunCompare.splits[boss.id] then
                        local best = state.bestRunCompare.splits[boss.id]
                        local diff = split - best
                        local sign = (diff >= 0) and "+" or "-"
                        local diffAbs = abs(diff)
                        local color = (diff <= 0) and "|cff00ff00" or "|cffff0000" 
                        text = text .. format(" %s(%s%d:%02d|r)", color, sign, diffAbs/60, diffAbs%60)
                    end
                    row.time:SetText(text)
                else
                    row.time:SetText("")
                end
            else
                row.name:SetText(boss.name)
                row.name:SetTextColor(1, 0.82, 0, 1) 
                row.check:Hide()
                row.box:SetVertexColor(0, 0.8, 1, 1)
                row.time:SetText("")
            end
        end
        for i = #state.bosses + 1, #container.bossList.rows do container.bossList.rows[i]:Hide() end
    end
    if state.affixIDs and #state.affixIDs > 0 then
        local iconSize = 24
        local spacing = 4
        for i, id in ipairs(state.affixIDs) do
            local aFrame = container.affixFrame.icons[i]
            if not aFrame then
                aFrame = CreateFrame("Frame", nil, container.affixFrame, "BackdropTemplate")
                aFrame:SetSize(iconSize, iconSize)
                aFrame.icon = aFrame:CreateTexture(nil, "ARTWORK")
                aFrame.icon:SetAllPoints()
                aFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if Skin and Skin.ApplyBackdrop then 
                    Skin:ApplyBackdrop(aFrame, 0, 1) 
                    if aFrame.SetBackdropBorderColor then aFrame:SetBackdropBorderColor(0, 0.7, 1, 1) end
                end
                container.affixFrame.icons[i] = aFrame
            end
            local name, description, fileID = C_ChallengeMode.GetAffixInfo(id)
            aFrame.icon:SetTexture(fileID)
            aFrame:Show()
            aFrame:SetPoint("RIGHT", -(i-1) * (iconSize + spacing), 0)
            aFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(name, 1, 1, 1)
                GameTooltip:AddLine(description, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            aFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        for i = #state.affixIDs + 1, #container.affixFrame.icons do container.affixFrame.icons[i]:Hide() end
    end
    if container.deathCount then
        local unlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
        if MPlus.previewMode or unlocked then
            container.deathCount:SetText(string.format(L("LABEL_DEATHS_LOST_TIME"), 5, 0, 25))
        elseif C_ChallengeMode and C_ChallengeMode.GetDeathCount then
            local count, timeLost = C_ChallengeMode.GetDeathCount()
            if count and count > 0 then
                container.deathCount:SetText(format(L("LABEL_DEATHS_LOST_TIME"), count, (timeLost or 0)/60, (timeLost or 0)%60))
            else
                container.deathCount:SetText("")
            end
        end
    end
    if container.keyLevel then
        local text = ""
        if state.mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            local name = C_ChallengeMode.GetMapUIInfo(state.mapID)
            if name and name ~= "" then 
                text = name .. " " 
            end
        end
        if state.keystoneLevel and state.keystoneLevel > 0 then
            text = text .. "+" .. state.keystoneLevel
        end
        container.keyLevel:SetText(text)
    end
end
function MPlus:UpdateAllInstances()
    for _, container in ipairs(MPlus.Instances) do
        MPlus:UpdateVisuals(container)
    end
end
function MPlus:CheckVisibility(container)
    local unlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
    if MPlus.previewMode or unlocked then
        container:Show()
        container:SetAlpha(1)
        local state = MPlus.GlobalState
        if not state.activeRun then
            state.currentTime = 950 
            state.timeLimit = 1800 
            state.threeChestLimit = 1080
            state.twoChestLimit = 1440
            state.enemyForces = { cur = 240, max = 300, pct = 80.0 }
            state.bosses = {
                {name = L("PREVIEW_BOSS_ONE"), done = true, id = 1},
                {name = L("PREVIEW_BOSS_TWO"), done = true, id = 2},
                {name = L("PREVIEW_FINAL_BOSS"), done = false, id = 3}
            }
            state.splits = {[1] = 300, [2] = 650}
            state.affixIDs = {9, 10, 11, 122}
            state.keystoneLevel = 12
            state.mapID = 375
        end
        return
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then 
        container:Show()
        container:SetAlpha(1)
        MPlus:HideDefaultTracker()
    else
        container:Hide()
        MPlus:ShowDefaultTracker()
    end
end
function MPlus:RegisterEvents()
    if MPlus.eventFrame then return end
    local eventFrame = CreateFrame("Frame")
    MPlus.eventFrame = eventFrame
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("CHALLENGE_MODE_RESET") 
    eventFrame:RegisterEvent("SCENARIO_UPDATE")
    eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(function() eventFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN") end)
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        local hasActiveWidget = MPlus:IsWidgetActive()
        if not hasActiveWidget then
            if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED" or event == "PLAYER_ENTERING_WORLD" then
                MPlus:DisableRuntimeState()
            end
            return
        end
        if event == "CHALLENGE_MODE_START" then
            MPlus:StartRun()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            MPlus:EndRun()
        elseif event == "CHALLENGE_MODE_RESET" then
            MPlus:DisableRuntimeState()
            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
        elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
            MPlus:UpdateObjectivesData()
        elseif event == "PLAYER_ENTERING_WORLD" then
            MPlus:SyncStateFromGame()
            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
            C_Timer.After(1.5, function()
                if not MPlus:IsWidgetActive() then return end
                MPlus:SyncStateFromGame()
                if _G.C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
                MPlus:UpdateAllInstances()
            end)
        elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN" then
            local isWidgetActive = MPlus:IsWidgetActive()
            if isWidgetActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
                C_Timer.After(0.3, function()
                    local stillActive = MPlus:IsWidgetActive()
                    if stillActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
                        MPlus:TrySlotKeystone()
                    end
                end)
            end
        end
    end)
    MPlus.timerFrame = CreateFrame("Frame")
    MPlus.timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if not MPlus:IsWidgetActive() then
            MPlus:DisableRuntimeState()
            return
        end
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then return end
        local tick = self.elapsed
        self.elapsed = 0
        local state = MPlus.GlobalState
        if state.activeRun then
            local timeElapsed = GetChallengeElapsedTime()
            if (not timeElapsed or timeElapsed <= 0) and state.runStartTime then
                timeElapsed = GetTime() - state.runStartTime
            end
            if timeElapsed and timeElapsed >= 0 then state.currentTime = timeElapsed end
            MPlus:HideDefaultTracker()
            self.forcePoll = (self.forcePoll or 0) + tick
            if self.forcePoll >= 1.0 then
                self.forcePoll = 0
                MPlus:UpdateObjectivesData()
            end
            MPlus:UpdateAllInstances()
        else
            self.slowTick = (self.slowTick or 0) + tick
            if self.slowTick > 5 then
                self.slowTick = 0
                if not state.affixIDs or #state.affixIDs == 0 then
                    if _G.C_MythicPlus and C_MythicPlus.GetCurrentAffixes then
                        local affixes = C_MythicPlus.GetCurrentAffixes()
                        if affixes then
                            state.affixIDs = {}
                            for _, a in ipairs(affixes) do table.insert(state.affixIDs, a.id) end
                            MPlus:UpdateAllInstances()
                        end
                    end
                end
            end
        end
    end)
end
function MPlus:UpdateTimerData()
    if not MPlus:IsWidgetActive() then return end
    if not _G.C_ChallengeMode then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    local state = MPlus.GlobalState
    if mapID then state.mapID = mapID end
    if not mapID then return end
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local isChallengersPeril = false
    if C_ChallengeMode.GetActiveKeystoneInfo then
        local keystoneLevel, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
        if affixes and type(affixes) == "table" then
            state.affixIDs = {}
            for _, affixID in ipairs(affixes) do
                table.insert(state.affixIDs, affixID)
                if affixID == 152 then isChallengersPeril = true end
            end
        elseif affixes == nil then
            if C_MythicPlus and C_MythicPlus.GetCurrentAffixes then
                local currentAffixes = C_MythicPlus.GetCurrentAffixes()
                if currentAffixes then
                    state.affixIDs = {}
                    for _, a in ipairs(currentAffixes) do
                        table.insert(state.affixIDs, a.id)
                        if a.id == 152 then isChallengersPeril = true end
                    end
                end
            end
        end
        if keystoneLevel and keystoneLevel > 0 then
            state.keystoneLevel = keystoneLevel
        end
    end
    if timeLimit then
        state.timeLimit = timeLimit
        if isChallengersPeril then
            state.threeChestLimit = ((timeLimit - 90) * 0.6) + 90
            state.twoChestLimit = ((timeLimit - 90) * 0.8) + 90
        else
            state.threeChestLimit = timeLimit * 0.6
            state.twoChestLimit = timeLimit * 0.8
        end
    end
end
function MPlus:StartRun()
    if not MPlus:IsWidgetActive() then
        MPlus:DisableRuntimeState()
        return
    end
    local state = MPlus.GlobalState
    state.activeRun = true
    state.isCompleted = false
    state.splits = {}
    state.runStartTime = GetTime()
    MPlus:UpdateTimerData()
    MPlus:HideDefaultTracker()
    if C_ChallengeMode.GetActiveChallengeMapID then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then state.keystoneLevel = level end
        if mapID then
            state.mapID = mapID
            state.bestRunCompare = MPlus:GetBestRun(mapID, level)
        else
            state.bestRunCompare = nil
        end
    end
    MPlus:UpdateObjectivesData()
    for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
    MPlus:UpdateAllInstances()
    C_Timer.After(1.0, function()
        if state.activeRun then
            MPlus:UpdateTimerData()
            MPlus:UpdateObjectivesData()
            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
            MPlus:UpdateAllInstances()
        end
    end)
end
function MPlus:EndRun()
    if not MPlus:IsWidgetActive() then
        MPlus:DisableRuntimeState()
        return
    end
    local state = MPlus.GlobalState
    state.activeRun = false
    state.isCompleted = true
    state.bestRunCompare = nil
    MPlus:ShowDefaultTracker()
    if MPlus.config then
        MPlus.config.History = MPlus.config.History or {}
    end
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and state.currentTime and MPlus.config then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID() or state.mapID
        if mapID then
            local level = 0
            if C_ChallengeMode.GetActiveKeystoneInfo then
                local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
                if keystoneLevel and keystoneLevel > 0 then
                    level = keystoneLevel
                end
            end
            local entry = {
                level = level,
                time = state.currentTime,
                date = date("%Y-%m-%d %H:%M:%S"),
                completed = (state.currentTime <= (state.timeLimit or 0)),
                splits = state.splits or {}
            }
            MPlus.config.History[mapID] = MPlus.config.History[mapID] or { Runs = {} }
            table.insert(MPlus.config.History[mapID].Runs, entry)
        end
    end
    print("|cff00ffff[WidgetForge]|r Mythic+ Run Completed!")
end
function MPlus:TrySlotKeystone()
    if not MPlus:IsWidgetActive() then return end
    local slotted = false
    if C_ChallengeMode and C_ChallengeMode.SlotKeystone then
        local success = C_ChallengeMode.SlotKeystone()
        if success then 
            slotted = true
        end
    end
    if not slotted then
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local link = info.hyperlink:lower()
                    if link:find("keystone") then
                        C_Container.UseContainerItem(bag, slot)
                        slotted = true
                        break
                    end
                end
            end
            if slotted then break end
        end
    end
end
function MPlus:UpdateObjectivesData()
    if not MPlus:IsWidgetActive() then return end
    local state = MPlus.GlobalState
    if state.isCompleted then return end 
    if not _G.C_Scenario or not C_Scenario.GetStepInfo then return end
    local _, _, numStages = C_Scenario.GetStepInfo()
    if not numStages or numStages == 0 then return end
    if not state.splits then state.splits = {} end
    if not state.bossStatus then state.bossStatus = {} end
    state.bosses = {}
    local numCriteria = select(3, C_Scenario.GetStepInfo())
    if not numCriteria then return end
    for i = 1, numCriteria do
        local description, quantity, totalQuantity, quantityString, isEnemyForces, completed, criteriaType
        if _G.C_ScenarioInfo and _G.C_ScenarioInfo.GetCriteriaInfo then
            local tbl = C_ScenarioInfo.GetCriteriaInfo(i)
            if tbl then
                description = tbl.description; completed = tbl.completed
                quantity = tbl.quantity; totalQuantity = tbl.totalQuantity
                criteriaType = tbl.criteriaType
                if tbl.isWeightedProgress or criteriaType == 4 then isEnemyForces = true end
            end
        else
            local c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12
            description, c2, completed, quantity, totalQuantity, c6, c7, quantityString, c9, c10, c11, isEnemyForces = C_Scenario.GetCriteriaInfo(i)
            criteriaType = c2
            if criteriaType == 4 then isEnemyForces = true end
        end
        if isEnemyForces then
            state.enemyForces = { cur = quantity or 0, max = totalQuantity or 100, pct = (totalQuantity and totalQuantity > 0) and ((quantity or 0) / totalQuantity) * 100 or 0 }
        else
            if state.bossStatus[i] == nil then state.bossStatus[i] = completed end
            if completed and state.bossStatus[i] == false then
                if not state.splits[i] then state.splits[i] = state.currentTime or 0 end
            end
            state.bossStatus[i] = completed
            local bName = description or "Unknown"
            bName = string.gsub(bName, " [Dd]efeated$", "")
            bName = string.gsub(bName, " [Ss]lain$", "")
            bName = string.gsub(bName, " [Bb]esiegen$", "")
            bName = string.gsub(bName, " [Vv]aincu$", "")
            bName = string.gsub(bName, " [Dd]errotado$", "")
            bName = string.gsub(bName, " [Mm]aÄŸlup [Ee]dildi$", "")
            bName = string.gsub(bName, " maÄŸlup edildi$", "")
            table.insert(state.bosses, { name = bName, done = completed, id = i })
        end
    end
    MPlus:UpdateAllInstances()
end
function MPlus:GetBestRun(mapID, level)
    if not mapID or not MPlus.config or not MPlus.config.History then return nil end
    local history = MPlus.config.History[mapID]
    if not history or not history.Runs then return nil end
    local mode = MPlus.config.Settings.splitComparisonMode or "LEVEL" 
    local best = nil
    local bestTime = 999999
    for _, run in ipairs(history.Runs) do
        local match = (mode == "ZONE") or (run.level == level)
        if match and run.completed and run.time < bestTime then
            bestTime = run.time; best = run
        end
    end
    return best
end
function MPlus:CreateSettings(parentFrame)
    MPlus:InitGlobal()
    local f = parentFrame
    local elem = f.config
    local globalSets = MPlus.config.Settings
    if globalSets.autoSize == nil then globalSets.autoSize = true end
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    local function UpdateGlobal() MPlus:UpdateAllInstances() end
    local function UpdateVisual()
        for _, inst in ipairs(MPlus.Instances) do
             if inst.elem == elem then
                 if not globalSets.autoSize and elem.widgetHeight then inst:SetHeight(elem.widgetHeight) end
                 if elem.widgetWidth then inst:SetWidth(elem.widgetWidth) end
                 if inst.SetBackdropColor then
                     inst:SetBackdropColor(unpack(elem.bgColor or {0, 0, 0, 0.5}))
                 end
             end
             MPlus:UpdateLayout(inst)
        end
        if _G.WidgetForge and _G.WidgetForge.RebuildBarComponents then _G.WidgetForge:RebuildBarComponents(f.barIndex) end
    end
    local Skin = _G.ForgeSkin
    local textureItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then
        for name, path in pairs(Skin.Media.Textures) do table.insert(textureItems, {text = name, value = path}) end
    else
        textureItems = {{text = "Default", value = "Interface\\TargetingFrame\\UI-StatusBar"}}
    end
    sb:AddHeader(L("HEADER_LAYOUT_VISIBILITY_FLEX"))
    sb:AddSwitch("autoSize", L("LABEL_AUTO_ADJUST_HEIGHT"), true, globalSets, UpdateVisual)
    sb:AddSwitch("hoverExpand", L("LABEL_HOVER_TO_EXPAND"), false, globalSets, UpdateGlobal)
    sb:AddSwitch("showTimer", L("LABEL_SHOW_TIMER_BAR"), true, globalSets, UpdateGlobal)
    sb:AddSwitch("showForces", L("LABEL_SHOW_ENEMY_FORCES_BAR"), true, globalSets, UpdateGlobal)
    sb:AddSwitch("showBosses", L("LABEL_SHOW_BOSS_LIST"), true, globalSets, UpdateGlobal)
    sb:AddSwitch("showAffixes", L("LABEL_SHOW_AFFIXES"), true, globalSets, UpdateGlobal)
    sb:AddSwitch("showDeathCounter", L("LABEL_SHOW_DEATH_COUNTER"), true, globalSets, UpdateGlobal)
    sb:AddHeader(L("HEADER_VISUAL_CONFIGURATION"))
    sb:AddSlider("widgetWidth", L("LABEL_DASHBOARD_WIDTH"), 200, 600, 1, 300, elem, UpdateVisual)
    sb:AddSlider("widgetHeight", L("LABEL_MANUAL_HEIGHT"), 50, 400, 1, 160, elem, UpdateVisual)
    sb:AddColor("bgColor", L("LABEL_BACKGROUND_COLOR"), {0, 0, 0, 0.5}, elem, UpdateVisual)
    sb:AddDropdown("barTexture", L("LABEL_BAR_TEXTURE"), textureItems, "Interface\\TargetingFrame\\UI-StatusBar", globalSets, UpdateGlobal)
    sb:AddHeader(L("HEADER_COMPONENT_COLORS"))
    local chkDynamic = sb:AddSwitch("dynamicTimerColor", L("LABEL_DYNAMIC_TIMER_COLOR"), true, globalSets, UpdateGlobal)
    if chkDynamic then
        local isSplit = (globalSets.timerChestMode == "SPLIT")
        chkDynamic:EnableMouse(not isSplit)
        chkDynamic:SetAlpha(isSplit and 0.5 or 1)
    end
    sb:AddSwitch("showEnemyForcesAbsolute", L("LABEL_SHOW_ABSOLUTE_FORCES"), true, globalSets, UpdateGlobal)
    sb:AddColor("timerColor", L("LABEL_TIMER_BAR_COLOR"), {0, 0.8, 1, 1}, globalSets, UpdateGlobal)
    sb:AddColor("forcesColor", L("LABEL_FORCES_BAR_COLOR"), {0.8, 0, 0, 1}, globalSets, UpdateGlobal)
    sb:AddHeader(L("HEADER_SPLITS_MECHANICS"))
    sb:AddDropdown("timerChestMode", L("LABEL_TIMER_BAR_STYLE"), {
        {text = L("OPTION_LINES_MARKERS"), value = "LINES"},
        {text = L("OPTION_SPLIT_3_BARS"), value = "SPLIT"},
        {text = L("OPTION_NO_MARKS"), value = "NONE"}
    }, "LINES", globalSets, function(v)
        UpdateGlobal()
        if chkDynamic then
            local isSplit = (v == "SPLIT")
            chkDynamic:EnableMouse(not isSplit)
            chkDynamic:SetAlpha(isSplit and 0.5 or 1)
        end
    end, true)
    sb:AddColor("timerChunk1Color", L("LABEL_CHUNK1_COLOR"), {0.30, 0.69, 0.49, 1}, globalSets, UpdateGlobal)
    sb:AddColor("timerChunk2Color", L("LABEL_CHUNK2_COLOR"), {1.00, 0.55, 0.26, 1}, globalSets, UpdateGlobal)
    sb:AddColor("timerChunk3Color", L("LABEL_CHUNK3_COLOR"), {0.90, 0.22, 0.27, 1}, globalSets, UpdateGlobal)
    sb:AddSwitch("showSplits", L("LABEL_SHOW_SPLIT_TIMES"), true, globalSets, UpdateGlobal)
    sb:AddDropdown("splitComparisonMode", L("LABEL_COMPARE_SPLITS_WITH"), {
        {text = L("OPTION_BEST_OF_ZONE_ANY_LEVEL"), value = "ZONE"},
        {text = L("OPTION_BEST_OF_LEVEL"), value = "LEVEL"},
        {text = L("OPTION_EXACT_MATCH"), value = "EXACT"}
    }, "LEVEL", globalSets, UpdateGlobal, true)
    sb:AddHeader(L("HEADER_AUTOMATION_QOL"))
    sb:AddSwitch("autoKeystone", L("LABEL_AUTO_INSERT_KEYSTONE"), true, globalSets, UpdateGlobal)
    sb:AddSwitch("hideBlizzardTracker", L("LABEL_HIDE_BLIZZARD_TRACKER"), true, globalSets, function(v)
        globalSets.hideBlizzardTracker = v
        if v then MPlus:HideDefaultTracker() else MPlus:ShowDefaultTracker() end
        UpdateGlobal()
    end)
    sb:AddSwitch("autoCloseBags", L("LABEL_AUTO_CLOSE_BAGS"), true, globalSets, UpdateGlobal)
    sb:Finish()
end
function MPlus:TogglePreview(state)
    MPlus.previewMode = state
    for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
    MPlus:UpdateAllInstances()
end
local fEvents = CreateFrame("Frame")
fEvents:RegisterEvent("ADDON_LOADED")
fEvents:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        MPlus:InitGlobal()
    end
    if arg1 == "Blizzard_ChallengesUI" then
        MPlus:HookKeystoneFrame()
    end
end)
