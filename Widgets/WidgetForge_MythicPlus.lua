-- =========================================================================
--  WidgetForge - Mythic+ Dashboard Module
--  Instance-based, Highly Optimized, Adaptive Layout Mythic+ Tracker
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.MythicPlus = {}
local MPlus = _G.WidgetForge.MythicPlus
addonTable.MythicPlus = MPlus

-- Global Veri ve State
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

-- --- DB & EVENTS INIT ---
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
                -- Yeni Adaptive Layout Ayarları
                autoSize = true,
                hoverExpand = false,
                showTitle = true,
                showAffixes = true,
                showBosses = true,
                showTimer = true,
                showForces = true,
                showDeathCounter = true
            }
        }
    end
    MPlus.config = _G.WidgetForgeDB.MythicPlus
    
    -- Taint Korumalı Gizli Frame
    MPlus.hiddenFrame = CreateFrame("Frame")
    MPlus.hiddenFrame:Hide()
    
    MPlus:RegisterEvents()
    MPlus.initialized = true
end

-- --- UI YARDIMCILARI ---
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
    
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    bar.label:SetText(labelText)
    
    return bar
end

-- --- GÜVENLİ TRACKER GİZLEME ---
function MPlus:HideDefaultTracker()
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

-- --- WIDGET YÜKLEME ---
function MPlus:Load(parent, elem)
    MPlus:InitGlobal()
    local Skin = _G.ForgeSkin
    
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.isHovered = false
    
    container.title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = (Skin and Skin.Constants and Skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
    container.title:SetFont(font, 14, "OUTLINE")
    container.title:SetTextColor(unpack((Skin and Skin.Colors.accent) or {0, 0.8, 1, 1}))

    container.affixFrame = CreateFrame("Frame", nil, container)
    container.affixFrame:SetSize(120, 32)
    container.affixFrame.icons = {}

    container.bossList = CreateFrame("Frame", nil, container)
    container.bossList:SetSize(320, 10) 
    container.bossList.rows = {}

    container.timerBar = CreateProgressBar(container, "RUN TIMER")
    container.timerBar:SetMinMaxValues(0, 100)
    
    container.forcesBar = CreateProgressBar(container, "ENEMY FORCES")
    container.forcesBar:SetMinMaxValues(0, 100)
    
    container.deathCount = container:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    container.deathCount:SetText("")
    
    table.insert(MPlus.Instances, container)
    
    -- Hover (Mouse Over) Dinleme Döngüsü (Minimalist mod için)
    container:SetScript("OnUpdate", function(self)
        if MPlus.config.Settings.hoverExpand then
            local hovered = MouseIsOver(self)
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
    
    MPlus:CheckVisibility(container)
    MPlus:UpdateVisuals(container)
    
    return container
end

-- --- DİNAMİK DÜZEN MOTORU (ADAPTIVE LAYOUT) ---
function MPlus:UpdateLayout(container)
    if not container then return end
    
    local conf = MPlus.config.Settings
    local state = MPlus.GlobalState
    local y = -10
    
    -- Görünürlük Kontrolleri (Hover durumuna göre ezilebilir)
    local showTitle = conf.showTitle ~= false
    local showAffixes = conf.showAffixes ~= false
    local showBosses = conf.showBosses ~= false
    local showTimer = conf.showTimer ~= false
    local showForces = conf.showForces ~= false
    local showDeaths = conf.showDeathCounter ~= false
    
    -- Hover-to-Expand Mantığı
    if conf.hoverExpand and not container.isHovered then
        showBosses = false
        showAffixes = false
        showTitle = false
        showDeaths = false
    end

    -- 1. TITLE
    if showTitle then
        container.title:Show()
        container.title:SetPoint("TOPLEFT", 15, y)
        container.title:SetText("MYTHIC+ DASHBOARD")
    else
        container.title:Hide()
    end

    -- 2. AFFIXES (Başlıkla aynı satırda sağda)
    if showAffixes and state.affixIDs and #state.affixIDs > 0 then
        container.affixFrame:Show()
        container.affixFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, showTitle and (y + 8) or y)
        if not showTitle then y = y - 35 else y = y - 30 end
    else
        container.affixFrame:Hide()
        if showTitle then y = y - 30 end
    end
    
    -- 3. BOSS LIST
    if showBosses and state.bosses and #state.bosses > 0 then
        container.bossList:Show()
        container.bossList:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        local bossHeight = #state.bosses * 20
        container.bossList:SetHeight(bossHeight)
        y = y - bossHeight - 10
    else
        container.bossList:Hide()
    end

    -- 4. TIMER BAR
    if showTimer then
        container.timerBar:Show()
        container.timerBar:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y - 10)
        container.timerBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y - 10)
        y = y - 35
    else
        container.timerBar:Hide()
    end

    -- 5. FORCES BAR
    if showForces then
        container.forcesBar:Show()
        container.forcesBar:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y - 10)
        container.forcesBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y - 10)
        y = y - 35
    else
        container.forcesBar:Hide()
    end

    -- 6. DEATH COUNTER (En alta sağa yapıştır)
    if showDeaths then
        container.deathCount:Show()
        container.deathCount:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -15, 12)
        -- Death counter ufak olduğu için ekstra y eklemeye gerek yok, çerçevenin alt payına girer
    else
        container.deathCount:Hide()
    end

    -- Çerçeve Boyutunu Otomatik Ayarla
    if conf.autoSize ~= false then
        local minHeight = math.abs(y) + 15
        if showDeaths then minHeight = minHeight + 15 end
        container:SetHeight(math.max(minHeight, 30))
    elseif container.elem.widgetHeight then
        container:SetHeight(container.elem.widgetHeight)
    end
end

-- --- GÖRSEL GÜNCELLEME ---
function MPlus:UpdateVisuals(container)
    if not container or not container:IsShown() then return end
    
    local state = MPlus.GlobalState
    local conf = MPlus.config.Settings
    local Skin = _G.ForgeSkin
    local barTexture = conf.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
    
    -- Düzeni Yeniden Hesapla (Eğer boss sayısı veya modlar değişirse)
    MPlus:UpdateLayout(container)
    
    -- TIMER BAR DATA
    if state.currentTime and state.timeLimit and state.timeLimit > 0 then
        container.timerBar:SetMinMaxValues(0, state.timeLimit)
        container.timerBar:SetValue(state.currentTime)
        container.timerBar:SetStatusBarTexture(barTexture)
        
        local timeLeft = state.timeLimit - state.currentTime
        local isOver = timeLeft < 0
        local color = isOver and "|cffff0000" or "|cffffffff"
        container.timerBar.text:SetText(format("%s%02d:%02d|r / %02d:%02d", color, abs(timeLeft) / 60, abs(timeLeft) % 60, state.timeLimit / 60, state.timeLimit % 60))
        
        if conf.dynamicTimerColor ~= false then
            if state.currentTime < state.threeChestLimit then container.timerBar:SetStatusBarColor(0, 1, 0.5, 1) 
            elseif state.currentTime < state.twoChestLimit then container.timerBar:SetStatusBarColor(1, 0.8, 0, 1) 
            else container.timerBar:SetStatusBarColor(1, 0.3, 0.3, 1) end
        else
            container.timerBar:SetStatusBarColor(unpack(conf.timerColor or {0, 0.8, 1, 1}))
        end
    else
        container.timerBar:SetValue(0)
        container.timerBar.text:SetText("00:00 / 00:00")
    end
    
    -- FORCES BAR DATA
    if state.enemyForces then
        container.forcesBar:SetValue(state.enemyForces.pct)
        container.forcesBar:SetStatusBarTexture(barTexture)
        local fmt = conf.showEnemyForcesAbsolute and format("%.1f%% (%d/%d)", state.enemyForces.pct, state.enemyForces.cur, state.enemyForces.max) or format("%.2f%%", state.enemyForces.pct)
        container.forcesBar.text:SetText(fmt)
        container.forcesBar:SetStatusBarColor(unpack(conf.forcesColor or {0.8, 0, 0, 1}))
    end

    -- BOSS LIST DATA
    if state.bosses then
        local spacing = 20
        local mediaPath = "Interface\\AddOns\\WidgetForge\\media\\"
        
        for i, boss in ipairs(state.bosses) do
            local row = container.bossList.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, container.bossList)
                row:SetSize(300, 18)
                row.box = row:CreateTexture(nil, "OVERLAY")
                row.box:SetSize(12, 12)
                row.box:SetPoint("LEFT", 0, 0)
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
                row.time:SetPoint("RIGHT", 0, 0) 
                container.bossList.rows[i] = row
            end
            
            row:Show()
            row:SetPoint("TOPLEFT", 5, -(i-1) * spacing)
            row.name:SetText(boss.name)
            
            if boss.done then
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
                row.name:SetTextColor(1, 0.82, 0, 1) 
                row.check:Hide()
                row.box:SetVertexColor(0, 0.8, 1, 1)
                row.time:SetText("")
            end
        end
        for i = #state.bosses + 1, #container.bossList.rows do container.bossList.rows[i]:Hide() end
    end

    -- AFFIXES DATA
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

    -- DEATH COUNTER DATA
    if container.deathCount then
        local unlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
        if MPlus.previewMode or unlocked then
            container.deathCount:SetText("5 Deaths -0:25")
        elseif C_ChallengeMode and C_ChallengeMode.GetDeathCount then
            local count, timeLost = C_ChallengeMode.GetDeathCount()
            if count and count > 0 then
                container.deathCount:SetText(format("%d Deaths -%d:%02d", count, (timeLost or 0)/60, (timeLost or 0)%60))
            else
                container.deathCount:SetText("")
            end
        end
    end
end

function MPlus:UpdateAllInstances()
    for _, container in ipairs(MPlus.Instances) do
        MPlus:UpdateVisuals(container)
    end
end

-- --- GÖRÜNÜRLÜK KONTROLÜ ---
function MPlus:CheckVisibility(container)
    local unlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false) or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
    
    if MPlus.previewMode or unlocked then
        container:Show()
        container:SetAlpha(1)
        
        local state = MPlus.GlobalState
        state.currentTime = 950 
        state.timeLimit = 1800 
        state.threeChestLimit = 1080
        state.twoChestLimit = 1440
        state.enemyForces = { cur = 240, max = 300, pct = 80.0 }
        state.bosses = {
            {name = "Boss One", done = true, id = 1},
            {name = "Boss Two", done = true, id = 2},
            {name = "Final Boss", done = false, id = 3}
        }
        state.splits = {[1] = 300, [2] = 650}
        state.affixIDs = {9, 10, 11, 122}
        return
    end

    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then 
        container:Show()
        MPlus:HideDefaultTracker()
    else
        container:Hide()
        MPlus:ShowDefaultTracker()
    end
end

-- --- EVENTLER VE DATA TOPLAMA ---
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
        if event == "CHALLENGE_MODE_START" then
            MPlus:StartRun()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            MPlus:EndRun()
        elseif event == "CHALLENGE_MODE_RESET" then
            MPlus.GlobalState.activeRun = false
            MPlus:ShowDefaultTracker()
            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
        elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
            MPlus:UpdateObjectivesData()
        elseif event == "PLAYER_ENTERING_WORLD" then
            if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then
                if not MPlus.GlobalState.activeRun then
                    MPlus.GlobalState.activeRun = true
                    MPlus.GlobalState.splits = MPlus.GlobalState.splits or {}
                end
                MPlus:HideDefaultTracker()
            else
                MPlus.GlobalState.activeRun = false
                MPlus:ShowDefaultTracker()
            end

            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
            
            C_Timer.After(1.5, function()
                MPlus:UpdateTimerData()
                MPlus:UpdateObjectivesData()
                if _G.C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
                MPlus:UpdateAllInstances()
            end)
        elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN" then
            MPlus:OnKeystoneOpen()
        end
    end)
    
    MPlus.timerFrame = CreateFrame("Frame")
    MPlus.timerFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.1 then return end
        local tick = self.elapsed
        self.elapsed = 0

        local state = MPlus.GlobalState
        if state.activeRun then
            local _, timeElapsed = GetWorldElapsedTime(1)
            if timeElapsed and timeElapsed >= 0 then state.currentTime = timeElapsed end
            MPlus:HideDefaultTracker() 
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
    if not _G.C_ChallengeMode then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return end
    
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local state = MPlus.GlobalState

    local isChallengersPeril = false
    if C_ChallengeMode.GetActiveKeystoneInfo then
        local activeAffixes = select(2, C_ChallengeMode.GetActiveKeystoneInfo())
        if activeAffixes then
             state.affixIDs = activeAffixes
             for _, id in ipairs(activeAffixes) do
                 if id == 152 then isChallengersPeril = true; break end
             end
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
    local state = MPlus.GlobalState
    state.activeRun = true
    state.splits = {} 
    MPlus:UpdateTimerData()
    MPlus:HideDefaultTracker()
    
    if C_ChallengeMode.GetActiveChallengeMapID then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        local level = select(2, C_ChallengeMode.GetActiveKeystoneInfo())
        state.bestRunCompare = MPlus:GetBestRun(mapID, level)
    end

    MPlus:UpdateObjectivesData()
    for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
end

function MPlus:EndRun()
    local state = MPlus.GlobalState
    state.activeRun = false
    state.bestRunCompare = nil
    MPlus:ShowDefaultTracker()
    
    if C_ChallengeMode.GetActiveChallengeMapID and state.currentTime then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        local level = select(2, C_ChallengeMode.GetActiveKeystoneInfo()) or 0
        local entry = { level = level, time = state.currentTime, date = date("%Y-%m-%d %H:%M:%S"), completed = (state.currentTime <= (state.timeLimit or 0)), splits = state.splits }
        MPlus.config.History[mapID] = MPlus.config.History[mapID] or { Runs = {} }
        table.insert(MPlus.config.History[mapID].Runs, entry)
    end
    print("|cff00ffff[WidgetForge]|r Mythic+ Run Completed!")
end

function MPlus:OnKeystoneOpen()
    if not MPlus.config.Settings.autoKeystone then return end
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == 158923 then 
                C_Container.UseContainerItem(bag, slot)
                if MPlus.config.Settings.autoCloseBags then C_Timer.After(0.5, function() CloseAllBags() end) end
                return
            end
        end
    end
end

function MPlus:UpdateObjectivesData()
    if not _G.C_Scenario or not C_Scenario.GetStepInfo then return end
    local _, _, numStages = C_Scenario.GetStepInfo()
    if not numStages or numStages == 0 then return end
    
    local state = MPlus.GlobalState
    if not state.splits then state.splits = {} end
    if not state.bossStatus then state.bossStatus = {} end

    state.bosses = {}
    local numCriteria = select(3, C_Scenario.GetStepInfo())
    if not numCriteria then return end
    
    for i = 1, numCriteria do
        local description, quantity, totalQuantity, quantityString, isEnemyForces, completed
        
        if _G.C_ScenarioInfo and _G.C_ScenarioInfo.GetCriteriaInfo then
            local tbl = C_ScenarioInfo.GetCriteriaInfo(i)
            if tbl then
                description = tbl.description; completed = tbl.completed
                quantity = tbl.quantity; totalQuantity = tbl.totalQuantity
                if tbl.isWeightedProgress then isEnemyForces = true end
            end
        else
            description, _, completed, quantity, totalQuantity, _, _, quantityString, _, _, _, isEnemyForces = C_Scenario.GetCriteriaInfo(i)
        end
        
        if isEnemyForces then
            state.enemyForces = { cur = quantity, max = totalQuantity, pct = (totalQuantity and totalQuantity > 0) and (quantity / totalQuantity) * 100 or 0 }
        else
            if state.bossStatus[i] == nil then state.bossStatus[i] = completed end
            if completed and state.bossStatus[i] == false then
                if not state.splits[i] then state.splits[i] = state.currentTime or 0 end
            end
            state.bossStatus[i] = completed
            table.insert(state.bosses, { name = description or "Unknown", done = completed, id = i })
        end
    end
    MPlus:UpdateAllInstances()
end

function MPlus:GetBestRun(mapID, level)
    if not MPlus.config.History or not MPlus.config.History[mapID] then return nil end
    local mode = MPlus.config.Settings.splitComparisonMode or "LEVEL" 
    local best = nil
    local bestTime = 999999
    for _, run in ipairs(MPlus.config.History[mapID].Runs) do
        local match = (mode == "ZONE") or (run.level == level)
        if match and run.completed and run.time < bestTime then
            bestTime = run.time; best = run
        end
    end
    return best
end

-- --- AYARLAR (SETTINGS) ---
function MPlus:CreateSettings(parentFrame)
    MPlus:InitGlobal()
    local f = parentFrame
    local elem = f.config
    local globalSets = MPlus.config.Settings

    -- Ayar eksiklerini tamamla (Geriyedönük uyumluluk)
    if globalSets.autoSize == nil then globalSets.autoSize = true end
    if globalSets.showTitle == nil then globalSets.showTitle = true end

    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    
    local function UpdateGlobal() MPlus:UpdateAllInstances() end
    local function UpdateVisual()
        for _, inst in ipairs(MPlus.Instances) do
             if inst.elem == elem then
                 if not globalSets.autoSize and elem.widgetHeight then inst:SetHeight(elem.widgetHeight) end
                 if elem.widgetWidth then inst:SetWidth(elem.widgetWidth) end
             end
        end
        if WidgetForge.RebuildBarComponents then WidgetForge:RebuildBarComponents(f.barIndex) end
    end

    sb:AddHeader("Layout & Visibility (Flexible UI)")
    sb:AddCheckbox("autoSize", "Auto-Adjust Height (Recommended)", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("hoverExpand", "Hover to Expand (Minimalist Mode)", false, globalSets, UpdateGlobal)
    sb:AddCheckbox("showTitle", "Show Title", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showAffixes", "Show Affixes", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showBosses", "Show Boss List", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showTimer", "Show Timer Bar", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showForces", "Show Enemy Forces Bar", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showDeathCounter", "Show Death Counter", true, globalSets, UpdateGlobal)

    sb:AddHeader("Visual Configuration")
    sb:AddSlider("widgetWidth", "Dashboard Width", 200, 600, 1, 350, elem, UpdateVisual)
    sb:AddSlider("widgetHeight", "Manual Height (If Auto-Size Off)", 50, 400, 1, 160, elem, UpdateVisual)
    
    local Skin = _G.ForgeSkin
    local textureItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then
        for name, path in pairs(Skin.Media.Textures) do table.insert(textureItems, {text = name, value = path}) end
    else
        textureItems = {{text = "Default", value = "Interface\\TargetingFrame\\UI-StatusBar"}}
    end
    sb:AddDropdown("barTexture", "Bar Texture", textureItems, "Interface\\TargetingFrame\\UI-StatusBar", globalSets, UpdateGlobal)
    
    sb:AddHeader("Component Colors")
    sb:AddCheckbox("dynamicTimerColor", "Dynamic Timer Color", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showEnemyForcesAbsolute", "Show Absolute Forces", true, globalSets, UpdateGlobal)
    sb:AddColor("timerColor", "Timer Bar Color", {0, 0.8, 1, 1}, globalSets, UpdateGlobal)
    sb:AddColor("forcesColor", "Forces Bar Color", {0.8, 0, 0, 1}, globalSets, UpdateGlobal)
    
    sb:AddHeader("Splits & Mechanics")
    sb:AddCheckbox("showSplits", "Show Split Times", true, globalSets, UpdateGlobal)
    sb:AddDropdown("splitComparisonMode", "Compare Splits With:", {
        {text = "Best of Zone (Any Level)", value = "ZONE"},
        {text = "Best of Level", value = "LEVEL"},
        {text = "Exact Match", value = "EXACT"}
    }, "LEVEL", globalSets, UpdateGlobal, true)
    
    sb:AddHeader("Automation & Quality of Life")
    sb:AddCheckbox("autoKeystone", "Auto-Insert Keystone", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("autoCloseBags", "Auto-Close Bags", true, globalSets, UpdateGlobal)
    
    sb:AddCheckbox("hideBlizzardTracker", "Hide Blizzard Tracker", true, globalSets, function(v)
        globalSets.hideBlizzardTracker = v
        if v then MPlus:HideDefaultTracker() else MPlus:ShowDefaultTracker() end
        UpdateGlobal()
    end)
    
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
    if arg1 == addonName then MPlus:InitGlobal() end
end)