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

-- Helper: scan all world elapsed timers to find the M+ timer (type 2)
local function GetChallengeElapsedTime()
    local num = GetNumWorldElapsedTimers and GetNumWorldElapsedTimers() or 0
    for i = 1, num do
        local timerType, elapsed = GetWorldElapsedTime(i)
        if timerType == 2 then -- LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE
            return elapsed
        end
    end
    -- Fallback: try index 1
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
                timerChunk1Color = {0, 1, 0.5, 1},
                timerChunk2Color = {1, 0.8, 0, 1},
                timerChunk3Color = {1, 0.3, 0.3, 1}
            }
        }
    end
    MPlus.config = _G.WidgetForgeDB.MythicPlus
    
    MPlus.hiddenFrame = CreateFrame("Frame")
    MPlus.hiddenFrame:Hide()
    
    MPlus:RegisterEvents()
    MPlus.initialized = true
end


local function CreateMythicPlusUtilityButtons()
    if ChallengesKeystoneFrame.WidgetForgeButtonsCreated then return end

    local readyBtn = CreateFrame("Button", "WFMPlusReadyBtn", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
    readyBtn:SetSize(110, 25)
    readyBtn:SetText("Ready Check")
    readyBtn:SetPoint("BOTTOMLEFT", ChallengesKeystoneFrame, "BOTTOMLEFT", 21, 20)
    
    readyBtn:SetScript("OnClick", function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
        else
            print("|cffff0000[WidgetForge]|r Ready Check başlatmak için grup lideri olmalısınız.")
        end
    end)

    local pullBtn = CreateFrame("Button", "WFMPlusPullBtn", ChallengesKeystoneFrame, "UIPanelButtonTemplate")
    pullBtn:SetSize(110, 25)
    pullBtn:SetText("Pull (10s)")
    pullBtn:SetPoint("BOTTOMRIGHT", ChallengesKeystoneFrame, "BOTTOMRIGHT", -21, 20)
    
    pullBtn:SetScript("OnClick", function()
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            C_PartyInfo.DoCountdown(10)
        else
            print("|cffff0000[WidgetForge]|r Geri sayım başlatmak için grup lideri olmalısınız.")
        end
    end)

    ChallengesKeystoneFrame.WidgetForgeButtonsCreated = true
end

-- Called when Blizzard_ChallengesUI is loaded (load-on-demand)
function MPlus:HookKeystoneFrame()
    if MPlus.keystoneHooked then return end
    if not ChallengesKeystoneFrame then return end
    MPlus.keystoneHooked = true
    
    ChallengesKeystoneFrame:HookScript("OnShow", function()
        local isWidgetActive = MPlus.Instances and #MPlus.Instances > 0

        if isWidgetActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
            C_Timer.After(0.3, function()
                MPlus:TrySlotKeystone()
            end)
        end
        
        -- Yeni butonlarımızı buraya ekliyoruz
        CreateMythicPlusUtilityButtons()
        
        -- Widget aktif değilse butonları gizle
        local isWidgetActive = MPlus.Instances and #MPlus.Instances > 0
        if WFMPlusReadyBtn then WFMPlusReadyBtn:SetShown(isWidgetActive) end
        if WFMPlusPullBtn then WFMPlusPullBtn:SetShown(isWidgetActive) end
        
        if isWidgetActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoCloseBags then
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
            if MPlus.suppressBags then
                CloseAllBags()
            end
        end)
        MPlus.openAllBagsHooked = true
    end
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
    
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 5)
    
    bar.text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
    bar.label:SetText(labelText)
    
    -- Chest markers for Timer Bar (LINES mode)
    bar.marker2 = bar:CreateTexture(nil, "OVERLAY")
    bar.marker2:SetColorTexture(1, 0.8, 0, 0.8) -- Gold for 2-chest
    bar.marker2:SetSize(2, 18)
    bar.marker2:Hide()
    
    bar.marker3 = bar:CreateTexture(nil, "OVERLAY")
    bar.marker3:SetColorTexture(0, 1, 0.5, 0.8) -- Green for 3-chest
    bar.marker3:SetSize(2, 18)
    bar.marker3:Hide()
    
    -- Chunks for SPLIT mode
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
    container.deathCount:SetJustifyH("LEFT") -- Yazıyı tam sola dayalı hale getiriyoruz
    container.deathCount:SetText("")
    
    -- Key level label (top-right)
    container.keyLevel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.keyLevel:SetJustifyH("RIGHT")
    container.keyLevel:SetTextColor(0, 0.8, 1, 1)
    container.keyLevel:SetText("")
    
    table.insert(MPlus.Instances, container)
    
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

-- --- YENİLENMİŞ DİNAMİK DÜZEN MOTORU (REDESIGN) ---
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

    -- Key level (top-right, always visible when widget is shown)
    container.keyLevel:ClearAllPoints()
    container.keyLevel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -8)

    -- 1. TIMER BAR (En Üst)
    if showTimer then
        y = y - 12
        container.timerBar:Show()
        container.timerBar:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        container.timerBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y)
        y = y - 18 - padding
    else
        container.timerBar:Hide()
    end

    -- 2. FORCES BAR
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

    -- 3. BOSS LIST (Barlara dinamik olarak zincirlendi)
    if showBosses and state.bosses and #state.bosses > 0 then
        container.bossList:Show()
        container.bossList:SetPoint("TOPLEFT", container, "TOPLEFT", 10, y)
        container.bossList:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, y) -- Barlarla aynı hizalama
        local bossHeight = #state.bosses * 20
        container.bossList:SetHeight(bossHeight)
        y = y - bossHeight - padding
    else
        container.bossList:Hide()
    end

    -- 4. AFFIXES & DEATH COUNTER (En Alt Satır - Sağ ve Sol)
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

    -- COMPACT MOD: Alt taraftan 5 piksel fazladan uzat
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

-- --- GÖRSEL GÜNCELLEME ---
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
        local color = isOver and "|cffff0000" or "|cffffffff"
        
        if mode == "SPLIT" and state.threeChestLimit > 0 and state.twoChestLimit > 0 then
            container.timerBar.text:SetText("") -- Disable main text in split mode
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
            
            container.timerBar.chunk1:SetPoint("LEFT", container.timerBar, "LEFT", 0, 0)
            container.timerBar.chunk1:SetWidth(w1)
            container.timerBar.chunk2:SetPoint("LEFT", container.timerBar.chunk1, "RIGHT", gap, 0)
            container.timerBar.chunk2:SetWidth(w2)
            container.timerBar.chunk3:SetPoint("LEFT", container.timerBar.chunk2, "RIGHT", gap, 0)
            container.timerBar.chunk3:SetWidth(w3)
            
            container.timerBar.chunk1:SetMinMaxValues(0, state.threeChestLimit)
            container.timerBar.chunk2:SetMinMaxValues(0, state.twoChestLimit - state.threeChestLimit)
            container.timerBar.chunk3:SetMinMaxValues(0, state.timeLimit - state.twoChestLimit)
            
            local val1 = math.min(state.threeChestLimit, state.currentTime)
            local val2 = math.max(0, math.min(state.twoChestLimit - state.threeChestLimit, state.currentTime - state.threeChestLimit))
            local val3 = math.max(0, state.currentTime - state.twoChestLimit)
            
            container.timerBar.chunk1:SetValue(val1)
            container.timerBar.chunk2:SetValue(val2)
            container.timerBar.chunk3:SetValue(val3)
            
            -- Cumulative countdown: each bar shows time remaining to ITS OWN milestone
            -- Bar1 = time to 3-chest, Bar2 = time to 2-chest (bar1+self), Bar3 = total time left
            local f1 = math.max(0, state.threeChestLimit - state.currentTime)
            local f2 = math.max(0, state.twoChestLimit - state.currentTime)
            local f3 = state.timeLimit - state.currentTime  -- can be negative (overtime)
            
            container.timerBar.chunk1.text:SetText(format("%02d:%02d", f1 / 60, f1 % 60))
            container.timerBar.chunk2.text:SetText(format("%02d:%02d", f2 / 60, f2 % 60))
            if f3 < 0 then
                container.timerBar.chunk3.text:SetText(format("|cffff0000-%02d:%02d|r", abs(f3) / 60, abs(f3) % 60))
            else
                container.timerBar.chunk3.text:SetText(format("%02d:%02d", f3 / 60, f3 % 60))
            end
            
            container.timerBar.chunk1:SetStatusBarTexture(barTexture)
            container.timerBar.chunk2:SetStatusBarTexture(barTexture)
            container.timerBar.chunk3:SetStatusBarTexture(barTexture)
            
            container.timerBar.chunk1:SetStatusBarColor(unpack(conf.timerChunk1Color or {0, 1, 0.5, 1}))
            container.timerBar.chunk2:SetStatusBarColor(unpack(conf.timerChunk2Color or {1, 0.8, 0, 1}))
            container.timerBar.chunk3:SetStatusBarColor(unpack(conf.timerChunk3Color or {1, 0.3, 0.3, 1}))
            
            container.timerBar:SetMinMaxValues(0, state.timeLimit)
            container.timerBar:SetValue(0)
        else
            container.timerBar.text:SetText(format("%s%02d:%02d|r / %02d:%02d", color, abs(timeLeft) / 60, abs(timeLeft) % 60, state.timeLimit / 60, state.timeLimit % 60))
            container.timerBar:SetStatusBarTexture(barTexture)
            if container.timerBar.SetBackdropColor then container.timerBar:SetBackdropColor(0,0,0,0.6) end
            if container.timerBar.SetBackdropBorderColor then container.timerBar:SetBackdropBorderColor(0,0,0,1) end
            
            container.timerBar:SetMinMaxValues(0, state.timeLimit)
            container.timerBar:SetValue(state.currentTime)
            
            if conf.dynamicTimerColor ~= false then
                if state.currentTime < state.threeChestLimit then container.timerBar:SetStatusBarColor(0, 1, 0.5, 1) 
                elseif state.currentTime < state.twoChestLimit then container.timerBar:SetStatusBarColor(1, 0.8, 0, 1) 
                else container.timerBar:SetStatusBarColor(1, 0.3, 0.3, 1) end
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

    -- DİNAMİK BOSS SATIRLARI
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
                row.box:SetPoint("LEFT", row, "LEFT", 0, 0) -- Tam olarak hizaya yapışır
                
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
                row.time:SetPoint("RIGHT", row, "RIGHT", 0, 0) -- Sağ tarafa (bar sonuna) tam yapışır
                
                container.bossList.rows[i] = row
            end
            
            row:Show()
            row:SetPoint("TOPLEFT", container.bossList, "TOPLEFT", 0, -(i-1) * spacing)
            row:SetPoint("TOPRIGHT", container.bossList, "TOPRIGHT", 0, -(i-1) * spacing)
            
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
    
    -- Key level (top-right)
    if container.keyLevel then
        if state.keystoneLevel and state.keystoneLevel > 0 then
            container.keyLevel:SetText("+" .. state.keystoneLevel)
        else
            container.keyLevel:SetText("")
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
        state.keystoneLevel = 12
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
            MPlus.GlobalState.isCompleted = false
            MPlus:ShowDefaultTracker()
            for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
        elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
            MPlus:UpdateObjectivesData()
        elseif event == "PLAYER_ENTERING_WORLD" then
            if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then
                if not MPlus.GlobalState.activeRun and not MPlus.GlobalState.isCompleted then
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
            local isWidgetActive = MPlus.Instances and #MPlus.Instances > 0
            if isWidgetActive and MPlus.config and MPlus.config.Settings and MPlus.config.Settings.autoKeystone then
                C_Timer.After(0.3, function()
                    MPlus:TrySlotKeystone()
                end)
            end
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
            -- Primary: scan all world timers for M+ timer type
            local timeElapsed = GetChallengeElapsedTime()
            -- Last resort fallback: compute from GetTime() recorded at run start
            if (not timeElapsed or timeElapsed <= 0) and state.runStartTime then
                timeElapsed = GetTime() - state.runStartTime
            end
            if timeElapsed and timeElapsed >= 0 then state.currentTime = timeElapsed end
            MPlus:HideDefaultTracker()
            -- Also poll objectives every ~1s to catch kill count updates
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
    if not _G.C_ChallengeMode then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return end
    
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local state = MPlus.GlobalState

    local isChallengersPeril = false
    if C_ChallengeMode.GetActiveKeystoneInfo then
        -- Returns: level, affixes (table of affix IDs), wasEnergized
        local keystoneLevel, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
        if affixes and type(affixes) == "table" then
            state.affixIDs = {}
            for _, affixID in ipairs(affixes) do
                table.insert(state.affixIDs, affixID)
                if affixID == 152 then isChallengersPeril = true end
            end
        elseif affixes == nil then
            -- Fallback: try C_MythicPlus.GetCurrentAffixes
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
        -- Store keystone level in global state
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
    local state = MPlus.GlobalState
    state.activeRun = true
    state.isCompleted = false
    state.splits = {}
    -- Record wall-clock start time as a GetTime() fallback for the timer
    state.runStartTime = GetTime()
    MPlus:UpdateTimerData()
    MPlus:HideDefaultTracker()
    
    if C_ChallengeMode.GetActiveChallengeMapID then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        -- GetActiveKeystoneInfo returns: level, affixes, wasEnergized
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then state.keystoneLevel = level end
        state.bestRunCompare = MPlus:GetBestRun(mapID, level)
    end

    MPlus:UpdateObjectivesData()
    for _, inst in ipairs(MPlus.Instances) do MPlus:CheckVisibility(inst) end
    MPlus:UpdateAllInstances()
    
    -- Delayed retry: scenario data may not be available immediately at key start
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
    local state = MPlus.GlobalState
    state.activeRun = false
    state.isCompleted = true
    state.bestRunCompare = nil
    MPlus:ShowDefaultTracker()
    
    if C_ChallengeMode.GetActiveChallengeMapID and state.currentTime then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID()
        local level = C_ChallengeMode.GetActiveKeystoneInfo() or 0  -- first return value is the keystone level
        local entry = { level = level, time = state.currentTime, date = date("%Y-%m-%d %H:%M:%S"), completed = (state.currentTime <= (state.timeLimit or 0)), splits = state.splits }
        MPlus.config.History[mapID] = MPlus.config.History[mapID] or { Runs = {} }
        table.insert(MPlus.config.History[mapID].Runs, entry)
    end
    print("|cff00ffff[WidgetForge]|r Mythic+ Run Completed!")
end

-- Uses the official WoW API to slot the keystone
function MPlus:TrySlotKeystone()
    local slotted = false
    -- Method 1: C_ChallengeMode.SlotKeystone (modern API)
    if C_ChallengeMode and C_ChallengeMode.SlotKeystone then
        local success = C_ChallengeMode.SlotKeystone()
        if success then 
            slotted = true
        end
    end
    
    -- Method 2: Fallback - find keystone in bags and use it
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
    local state = MPlus.GlobalState
    if state.isCompleted then return end -- Don't clear bosses if completed
    
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
                -- isWeightedProgress = enemy forces bar (kill count)
                -- criteriaType 4 is also used for enemy forces in some versions
                if tbl.isWeightedProgress or criteriaType == 4 then isEnemyForces = true end
            end
        else
            -- Legacy fallback: returns description, criteriaType, completed, quantity, totalQuantity, ..., isWeightedProgress
            local c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12
            description, c2, completed, quantity, totalQuantity, c6, c7, quantityString, c9, c10, c11, isEnemyForces = C_Scenario.GetCriteriaInfo(i)
            criteriaType = c2
            -- Also check criteriaType 4 for enemy forces
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

-- --- AYARLAR (SETTINGS) İYİLEŞTİRİLMİŞ SIRALAMA ---
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

    sb:AddHeader("Layout & Visibility (Flexible UI)")
    sb:AddCheckbox("autoSize", "Auto-Adjust Height (Recommended)", true, globalSets, UpdateVisual)
    sb:AddCheckbox("hoverExpand", "Hover to Expand (Minimalist Mode)", false, globalSets, UpdateGlobal)
    sb:AddCheckbox("showTimer", "Show Timer Bar", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showForces", "Show Enemy Forces Bar", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showBosses", "Show Boss List", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showAffixes", "Show Affixes", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showDeathCounter", "Show Death Counter", true, globalSets, UpdateGlobal)

    sb:AddHeader("Visual Configuration")
    sb:AddSlider("widgetWidth", "Dashboard Width", 200, 600, 1, 300, elem, UpdateVisual)
    sb:AddSlider("widgetHeight", "Manual Height (If Auto-Size Off)", 50, 400, 1, 160, elem, UpdateVisual)
    sb:AddColor("bgColor", "Background Color", {0, 0, 0, 0.5}, elem, UpdateVisual)
    sb:AddDropdown("barTexture", "Bar Texture", textureItems, "Interface\\TargetingFrame\\UI-StatusBar", globalSets, UpdateGlobal)
    
    sb:AddHeader("Component Colors")
    sb:AddCheckbox("dynamicTimerColor", "Dynamic Timer Color", true, globalSets, UpdateGlobal)
    sb:AddCheckbox("showEnemyForcesAbsolute", "Show Absolute Forces", true, globalSets, UpdateGlobal)
    sb:AddColor("timerColor", "Timer Bar Color", {0, 0.8, 1, 1}, globalSets, UpdateGlobal)
    sb:AddColor("forcesColor", "Forces Bar Color", {0.8, 0, 0, 1}, globalSets, UpdateGlobal)
    
    sb:AddHeader("Splits & Mechanics")
    sb:AddDropdown("timerChestMode", "Timer Bar Style", {
        {text = "Lines (Markers)", value = "LINES"},
        {text = "Split into 3 Bars", value = "SPLIT"},
        {text = "No Marks", value = "NONE"}
    }, "LINES", globalSets, UpdateGlobal, true)
    
    sb:AddColor("timerChunk1Color", "Chunk 1 Color (3-Chest)", {0, 1, 0.5, 1}, globalSets, UpdateGlobal)
    sb:AddColor("timerChunk2Color", "Chunk 2 Color (2-Chest)", {1, 0.8, 0, 1}, globalSets, UpdateGlobal)
    sb:AddColor("timerChunk3Color", "Chunk 3 Color (Base)", {1, 0.3, 0.3, 1}, globalSets, UpdateGlobal)
    
    sb:AddCheckbox("showSplits", "Show Split Times", true, globalSets, UpdateGlobal)
    sb:AddDropdown("splitComparisonMode", "Compare Splits With:", {
        {text = "Best of Zone (Any Level)", value = "ZONE"},
        {text = "Best of Level", value = "LEVEL"},
        {text = "Exact Match", value = "EXACT"}
    }, "LEVEL", globalSets, UpdateGlobal, true)
    
    sb:AddHeader("Automation & Quality of Life")
    sb:AddCheckbox("autoKeystone", "Auto-Insert Keystone", true, globalSets, UpdateGlobal)
    
    sb:AddCheckbox("hideBlizzardTracker", "Hide Blizzard Tracker", true, globalSets, function(v)
        globalSets.hideBlizzardTracker = v
        if v then MPlus:HideDefaultTracker() else MPlus:ShowDefaultTracker() end
        UpdateGlobal()
    end)
    
    sb:AddCheckbox("autoCloseBags", "Auto Close Bags (Key slotting)", true, globalSets, UpdateGlobal)
    
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
    -- ChallengesKeystoneFrame is inside Blizzard_ChallengesUI (load-on-demand)
    if arg1 == "Blizzard_ChallengesUI" then
        MPlus:HookKeystoneFrame()
    end
end)