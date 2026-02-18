local addonName, addon = ...
addon.MythicPlus = {}
local MPlus = addon.MythicPlus

-- Constants
local WIDGET_FRAME_Name = "WidgetForge_MythicPlusFrame"

-- Variables
MPlus.frame = nil
MPlus.config = {}
MPlus.initialized = false

-- Deferred Initialize
function MPlus:Init()
    if MPlus.initialized then return end
    
    -- Access global SavedVariables
    if not _G.WidgetForgeDB then return end
    
    if not _G.WidgetForgeDB.MythicPlus then
        _G.WidgetForgeDB.MythicPlus = {
            History = {},
            Settings = {
                showEnemyForcesAbsolute = true,
                autoKeystone = true,
                autoCloseBags = true,
                hideBlizzardTracker = true,
                customThresholds = { 90, 80, 60 } 
            }
        }
    end
    MPlus.config = _G.WidgetForgeDB.MythicPlus

    MPlus:CreateFrame()
    MPlus:RegisterEvents()
    MPlus.initialized = true
end

-- --- MODERN UI UTILS ---
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

-- Create Main Frame
function MPlus:CreateFrame()
    if MPlus.frame then return end
    
    local Skin = _G.ForgeSkin

    local f = CreateFrame("Frame", WIDGET_FRAME_Name, UIParent, "BackdropTemplate")
    f:SetSize(350, 160)
    f:SetPoint("CENTER")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    
    -- Modern Glassmorphism Backdrop
    if Skin and Skin.ApplyBackdrop then
        Skin:ApplyBackdrop(f, 0.2, 0.8)
    end
    f:SetBackdropColor(0, 0, 0, 0.7)
    
    -- Title/Header
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 15, -12)
    f.title:SetText("MYTHIC+ DASHBOARD")
    local font = (Skin and Skin.Constants and Skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
    f.title:SetFont(font, 14, "OUTLINE")
    f.title:SetTextColor(unpack((Skin and Skin.Colors.accent) or {0, 0.8, 1, 1}))

    -- Affix Container (TOP RIGHT - Anchored to main frame)
    f.affixFrame = CreateFrame("Frame", nil, f)
    f.affixFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -3) -- Moved up to align centers with title
    f.affixFrame:SetSize(120, 32)
    f.affixFrame.icons = {}

    -- BOSS LIST (Below Title)
    f.bossList = CreateFrame("Frame", nil, f)
    f.bossList:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -45)
    f.bossList:SetSize(320, 100) -- Room for ~5 bosses
    f.bossList.rows = {}

    -- Timer Bar (Below Boss List)
    f.timerBar = CreateProgressBar(f, "RUN TIMER")
    f.timerBar:SetPoint("TOPLEFT", f.bossList, "BOTTOMLEFT", 0, -10)
    f.timerBar:SetPoint("TOPRIGHT", f.bossList, "BOTTOMRIGHT", 0, -10)
    f.timerBar:SetMinMaxValues(0, 100)
    f.timerBar:SetValue(0)
    
    -- Forces Bar (Below Timer)
    f.forcesBar = CreateProgressBar(f, "ENEMY FORCES")
    f.forcesBar:SetPoint("TOPLEFT", f.timerBar, "BOTTOMLEFT", 0, -25)
    f.forcesBar:SetPoint("TOPRIGHT", f.timerBar, "BOTTOMRIGHT", 0, -25)
    f.forcesBar:SetMinMaxValues(0, 100)
    f.forcesBar:SetValue(0)
    
    -- Hide initially
    f:Hide()
    
    MPlus.frame = f
end

-- Modular Load
function MPlus:Load(parent, elem)
    MPlus:Init()
    
    if not MPlus.frame then return end
    
    local f = MPlus.frame
    f:SetParent(parent)
    f:ClearAllPoints()
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    
    if elem.widgetWidth then f:SetWidth(elem.widgetWidth) end
    if elem.widgetHeight then f:SetHeight(elem.widgetHeight) end
    
    MPlus:CheckVisibility()
    return f
end

function MPlus:Unload()
    if MPlus.frame then
        MPlus.frame:Hide()
        MPlus.frame:SetParent(UIParent)
    end
end

-- Events
function MPlus:RegisterEvents()
    if MPlus.eventFrame then return end
    
    local eventFrame = CreateFrame("Frame")
    MPlus.eventFrame = eventFrame
    
    local coreEvents = {
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "SCENARIO_UPDATE",
        "PLAYER_ENTERING_WORLD",
        "ADDON_LOADED"
    }
    
    for _, e in ipairs(coreEvents) do
        pcall(function() eventFrame:RegisterEvent(e) end)
    end
    
    pcall(function() eventFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN") end)
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHALLENGE_MODE_START" then
            MPlus:StartRun()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            MPlus:EndRun()
        elseif event == "SCENARIO_UPDATE" then
            MPlus:UpdateObjectives()
        elseif event == "PLAYER_ENTERING_WORLD" then
            MPlus:CheckVisibility()
            MPlus:UpdateTimerData()
            
            -- Auto-detect active run if in dungeon
            local _, _, difficultyID = GetInstanceInfo()
            if difficultyID == 8 or difficultyID == 23 then
                if not MPlus.activeRun then
                    MPlus.activeRun = true
                    MPlus.splits = MPlus.splits or {}
                end
            end
            
            -- Request Affix Data
            if _G.C_MythicPlus and C_MythicPlus.RequestMapInfo then
                C_MythicPlus.RequestMapInfo()
            end
        elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN" then
            MPlus:OnKeystoneOpen()
        elseif event == "ADDON_LOADED" then
            local name = ...
            if name == "Blizzard_ChallengesUI" then
                pcall(function() self:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTACLE_OPEN") end)
            end
        end
    end)
    
    MPlus.timerFrame = CreateFrame("Frame")
    MPlus.timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if MPlus.activeRun then
            MPlus:OnUpdate(elapsed)
        end
    end)
end

function MPlus:UpdateTimerData()
    if not _G.C_ChallengeMode then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return end
    
    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    if timeLimit then
        MPlus.timeLimit = timeLimit
        MPlus.threeChestLimit = timeLimit * 0.6
        MPlus.twoChestLimit = timeLimit * 0.8
        
        if MPlus.frame and MPlus.frame.timerBar then
            MPlus.frame.timerBar:SetMinMaxValues(0, timeLimit)
        end
    end
end

function MPlus:StartRun()
    MPlus.activeRun = true
    MPlus.splits = {} -- Reset split times
    MPlus:UpdateTimerData()
    MPlus:UpdateObjectives()
    if MPlus.frame then MPlus.frame:Show() end
    
    if MPlus.config.Settings and MPlus.config.Settings.hideBlizzardTracker then
        if ScenarioObjectiveTracker then ScenarioObjectiveTracker:Hide() end
    end
    
    print("|cff00ffff[WidgetForge]|r Mythic+ Run Started!")
end

function MPlus:EndRun()
    MPlus.activeRun = false
    
    if MPlus.config.Settings and MPlus.config.Settings.hideBlizzardTracker then
        if ScenarioObjectiveTracker then ScenarioObjectiveTracker:Show() end
    end
    
    if not _G.C_ChallengeMode then return end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapID and MPlus.currentTime then
        local level = select(2, C_ChallengeMode.GetActiveKeystoneInfo()) or 0
        local entry = {
            level = level,
            time = MPlus.currentTime,
            date = date("%Y-%m-%d %H:%M:%S"),
            completed = (MPlus.currentTime <= (MPlus.timeLimit or 0)),
            splits = MPlus.splits -- Save splits too
        }
        
        MPlus.config.History[mapID] = MPlus.config.History[mapID] or { Runs = {} }
        table.insert(MPlus.config.History[mapID].Runs, entry)
        
        local currentBest = MPlus.config.History[mapID].bestRun
        if not currentBest or (entry.completed and entry.time < currentBest.time) then
            MPlus.config.History[mapID].bestRun = entry
        end
    end
    
    print("|cff00ffff[WidgetForge]|r Mythic+ Run Completed!")
end

function MPlus:OnKeystoneOpen()
    if not MPlus.config.Settings or not MPlus.config.Settings.autoKeystone then return end
    
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == 158923 then 
                C_Container.UseContainerItem(bag, slot)
                if MPlus.config.Settings.autoCloseBags then
                    C_Timer.After(0.5, function() CloseAllBags() end)
                end
                return
            end
        end
    end
end

function MPlus:OnUpdate(elapsed)
    -- Timer Fallback for M0
    if MPlus.activeRun and not MPlus.startTime then
        MPlus.startTime = GetTime()
    end
    
    local _, timeElapsed = GetWorldElapsedTimers()
    if timeElapsed then
        MPlus.currentTime = timeElapsed
    elseif MPlus.startTime then
        -- Fallback for M0 (No official timer)
        MPlus.currentTime = GetTime() - MPlus.startTime
    end
    
    MPlus:UpdateUI()
end

function MPlus:UpdateObjectives()
    if not _G.C_Scenario or not C_Scenario.GetStepInfo then return end
    local _, _, numStages = C_Scenario.GetStepInfo()
    if not numStages or numStages == 0 then return end
    
    -- Ensure splits and run state are initialized
    if not MPlus.splits then MPlus.splits = {} end
    if not MPlus.bossStatus then MPlus.bossStatus = {} end
    if not MPlus.activeRun then 
        local _, _, diff = GetInstanceInfo()
        if diff == 8 or diff == 23 then 
            MPlus.activeRun = true 
            MPlus.startTime = GetTime() -- Set start time for M0 fallback 
        end
    end

    MPlus.objectives = {}
    MPlus.bosses = {}
    local numCriteria = select(3, C_Scenario.GetStepInfo())
    if not numCriteria then return end
    
    for i = 1, numCriteria do
        local description, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID
        
        if _G.C_ScenarioInfo and _G.C_ScenarioInfo.GetCriteriaInfo then
            local tbl = C_ScenarioInfo.GetCriteriaInfo(i)
            if tbl then
                description = tbl.description; criteriaType = tbl.criteriaType; completed = tbl.completed
                quantity = tbl.quantity; totalQuantity = tbl.totalQuantity; quantityString = tbl.quantityString
                assetID = tbl.assetID
                if not quantityString and quantity and totalQuantity and totalQuantity > 0 then
                    local pct = (quantity / totalQuantity) * 100
                    quantityString = format("%.1f%%", pct)
                end
            end
        elseif _G.C_Scenario and _G.C_Scenario.GetCriteriaInfo then
            description, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID = C_Scenario.GetCriteriaInfo(i)
        end
        
        local isEnemyForces = (quantityString and quantityString:find("%%")) or (totalQuantity and totalQuantity > 5)
        
        local obj = {
            name = description or "Unknown",
            done = completed,
            cur = quantity or 0,
            max = totalQuantity or 0,
            isEnemyForces = isEnemyForces,
            text = quantityString or "",
            icon = assetID,
            id = i -- Scenario index
        }
        
        if isEnemyForces then
            MPlus.enemyForces = { cur = quantity, max = totalQuantity, pct = (totalQuantity and totalQuantity > 0) and (quantity / totalQuantity) * 100 or 0 }
        else
            -- Boss Split Tracking / Objective Tracking
            
            -- Initialize tracking state if needed
            if MPlus.bossStatus[i] == nil then
                MPlus.bossStatus[i] = completed -- Mark initial state
            end
            
            -- Check for state change: Alive -> Dead
            if completed and MPlus.bossStatus[i] == false then
                -- WE witnessed the kill! Record it.
                if MPlus.splits and not MPlus.splits[i] then
                    MPlus.splits[i] = MPlus.currentTime or 0
                end
            end
            
            -- Update status
            MPlus.bossStatus[i] = completed

            -- Always add non-trash objectives to the list (Matches Blizzard UI)
            table.insert(MPlus.bosses, obj)
        end
        table.insert(MPlus.objectives, obj)
    end
    
    MPlus:UpdateUI()
end

function MPlus:UpdateUI()
    if not MPlus.frame then return end
    local f = MPlus.frame
    local Skin = _G.ForgeSkin
    
    -- TIMER BAR
    if MPlus.currentTime and MPlus.timeLimit then
        f.timerBar:SetValue(MPlus.currentTime)
        local timeLeft = MPlus.timeLimit - MPlus.currentTime
        local isOver = timeLeft < 0
        local color = isOver and "|cffff0000" or "|cffffffff"
        f.timerBar.text:SetText(format("%s%02d:%02d|r / %02d:%02d", color, abs(timeLeft) / 60, abs(timeLeft) % 60, MPlus.timeLimit / 60, MPlus.timeLimit % 60))
        
        -- Color transitions
        if MPlus.currentTime < (MPlus.threeChestLimit or 0) then
            f.timerBar:SetStatusBarColor(0, 1, 0.5, 1) -- Greenish
        elseif MPlus.currentTime < (MPlus.twoChestLimit or 0) then
            f.timerBar:SetStatusBarColor(1, 0.8, 0, 1) -- Golden
        else
            f.timerBar:SetStatusBarColor(1, 0.3, 0.3, 1) -- Reddish
        end
    else
        f.timerBar:SetValue(0)
        f.timerBar.text:SetText("00:00 / 00:00")
    end
    
    -- FORCES BAR
    if MPlus.enemyForces then
        f.forcesBar:SetValue(MPlus.enemyForces.pct)
        local fmt = (MPlus.config.Settings and MPlus.config.Settings.showEnemyForcesAbsolute) and 
                    format("%.1f%% (%d/%d)", MPlus.enemyForces.pct, MPlus.enemyForces.cur, MPlus.enemyForces.max) or
                    format("%.2f%%", MPlus.enemyForces.pct)
        f.forcesBar.text:SetText(fmt)
    else
        f.forcesBar:SetValue(0)
        f.forcesBar.text:SetText("0.0%")
    end

    -- BOSS LIST (TEXT BASED)
    if MPlus.bosses then
        local spacing = 20
        local mediaPath = "Interface\\AddOns\\WidgetForge\\media\\"
        
        for i, boss in ipairs(MPlus.bosses) do
            local row = f.bossList.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, f.bossList)
                row:SetSize(350, 18)
                
                -- Custom WidgetForge Checkbox Style
                row.box = row:CreateTexture(nil, "OVERLAY")
                row.box:SetSize(12, 12)
                row.box:SetPoint("LEFT", 0, 0)
                row.box:SetTexture(mediaPath .. "square_emty.tga")
                
                row.check = row:CreateTexture(nil, "OVERLAY")
                row.check:SetSize(12, 12)
                row.check:SetPoint("CENTER", row.box, "CENTER", 0, 0)
                row.check:SetTexture(mediaPath .. "square_full.tga")
                
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetPoint("LEFT", row.box, "RIGHT", 5, 0) -- Reduced spacing (was 10)
                row.name:SetFont(Skin and Skin.Constants.FONT_NORMAL or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                
                row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.time:SetPoint("RIGHT", 0, 0) -- Right align within the fixed width row
                
                f.bossList.rows[i] = row
            end
            
            row:Show()
            -- Reduced left padding (x=5) to align correctly to left
            row:SetPoint("TOPLEFT", 5, -(i-1) * spacing)
            row:SetWidth(300) -- Increased width slightly for better fit
            row.name:SetText(boss.name)
            
            if boss.done then
                row.name:SetTextColor(1, 0.2, 0.2, 1) -- Dead = RED
                row.check:Show()
                row.check:SetVertexColor(0, 0.8, 1, 1) -- Blue "Tick"
                row.box:SetVertexColor(0.2, 0.2, 0.2, 1)
                
                local split = MPlus.splits and MPlus.splits[boss.id]
                if split then
                    row.time:SetText(format("[%02d:%02d]", split / 60, split % 60))
                else
                    row.time:SetText("")
                end
            else
                row.name:SetTextColor(1, 0.82, 0, 1) -- Alive = GOLDEN YELLOW
                row.check:Hide()
                row.box:SetVertexColor(0, 0.8, 1, 1) -- Blue border for empty box
                row.time:SetText("")
            end
        end
        for i = #MPlus.bosses + 1, #f.bossList.rows do f.bossList.rows[i]:Hide() end
    end

    -- AFFIXES
    local affixIDs = {}
    
    -- 1. Try to get from Active Key (if in M+)
    if MPlus.activeRun and _G.C_ChallengeMode then
        local activeAffixes = select(2, C_ChallengeMode.GetActiveKeystoneInfo())
        if activeAffixes and #activeAffixes > 0 then
            affixIDs = activeAffixes
        end
    end

    -- 2. Fallback to Weekly Affixes if no active key affixes found (e.g. M0 or just login)
    if #affixIDs == 0 and _G.C_MythicPlus and C_MythicPlus.GetCurrentAffixes then
        local current = C_MythicPlus.GetCurrentAffixes()
        if current then
            for _, info in ipairs(current) do table.insert(affixIDs, info.id) end
        end
    end
    
    -- Ensure visibility (High Frame Level)
    f.affixFrame:SetFrameLevel(f:GetFrameLevel() + 10)

    if affixIDs and #affixIDs > 0 then
        local iconSize = 24
        local spacing = 4
        for i, id in ipairs(affixIDs) do
            local aFrame = f.affixFrame.icons[i]
            if not aFrame then
                aFrame = CreateFrame("Frame", nil, f.affixFrame, "BackdropTemplate")
                aFrame:SetSize(iconSize, iconSize)
                
                aFrame.icon = aFrame:CreateTexture(nil, "ARTWORK")
                aFrame.icon:SetAllPoints()
                aFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                if Skin and Skin.ApplyBackdrop then 
                    Skin:ApplyBackdrop(aFrame, 0, 1) 
                    if aFrame.SetBackdropBorderColor then 
                        aFrame:SetBackdropBorderColor(0, 0.7, 1, 1) -- Blue border
                    end
                end
                f.affixFrame.icons[i] = aFrame
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
        for i = #affixIDs + 1, #f.affixFrame.icons do f.affixFrame.icons[i]:Hide() end
    end
end

function MPlus:CheckVisibility()
    local _, _, difficultyID = GetInstanceInfo()
    local unlocked = _G.WidgetForge and _G.WidgetForge.BarsLocked == false
    
    if difficultyID == 8 or difficultyID == 23 or unlocked then 
        if MPlus.frame then MPlus.frame:Show() end
        if difficultyID == 8 or difficultyID == 23 then
            MPlus:UpdateObjectives()
        end
        MPlus:UpdateUI() -- Update for affixes outside
    else
        if MPlus.frame then MPlus.frame:Hide() end
    end
end

-- Settings UI
function MPlus:CreateSettings(parentFrame)
    local f = parentFrame
    local Skin = _G.ForgeSkin
    
    local lastY = -25
    local fullWidth = 400
    local startX = 25

    local function AddSlider(key, label, minVal, maxVal, step, defaultVal)
         local val = f.config[key] or defaultVal
         local slider = Skin:CreateSlider(f.content, minVal, maxVal, step, val, function(v)
             f.config[key] = v
             if MPlus.frame then
                if key == "widgetWidth" then MPlus.frame:SetWidth(v) end
                if key == "widgetHeight" then MPlus.frame:SetHeight(v) end
             end
         end, fullWidth)
         slider:SetPoint("TOPLEFT", startX, lastY)
         
         local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
         lbl:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
         lbl:SetText(label)
         lastY = lastY - 55
    end

    local function AddCheckbox(key, label, defaultVal)
        local val = MPlus.config.Settings[key]
        if val == nil then val = defaultVal end
        
        local chk = Skin:CreateCheckbox(f.content, label, val, function(v)
            MPlus.config.Settings[key] = v
            MPlus:UpdateUI()
        end)
        chk:SetPoint("TOPLEFT", startX, lastY)
        lastY = lastY - 30
    end

    -- SECTION: Visuals
    if Skin and Skin.CreateSectionHeader then
        local h = Skin:CreateSectionHeader(f.content, "Visual Settings", fullWidth)
        h:SetPoint("TOPLEFT", startX, lastY)
        lastY = lastY - 35
    end

    AddSlider("widgetWidth", "Dashboard Width", 200, 600, 1, 350)
    AddSlider("widgetHeight", "Dashboard Height", 100, 400, 1, 160)
    AddCheckbox("showEnemyForcesAbsolute", "Show Enemy Forces Absolute (e.g. 250/300)", true)

    -- SECTION: Automation
    if Skin and Skin.CreateSectionHeader then
        local h = Skin:CreateSectionHeader(f.content, "Automation", fullWidth)
        h:SetPoint("TOPLEFT", startX, lastY)
        lastY = lastY - 35
    end
    
    AddCheckbox("autoKeystone", "Auto-Insert Keystone", true)
    AddCheckbox("autoCloseBags", "Auto-Close Bags after Key", true)
    AddCheckbox("hideBlizzardTracker", "Hide Blizzard Objective Tracker", true)
end

-- Inject into Config
if _G.ForgeConfig then
    function _G.ForgeConfig:OpenMythicPlusSettings(barIndex, elemIndex, elem)
        local Skin = _G.ForgeSkin
        local f = _G.ForgeMythicPlusSettings
        if not f then
            f = CreateFrame("Frame", "ForgeMythicPlusSettings", UIParent, "BackdropTemplate")
            f:SetSize(450, 420)
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            f:EnableMouse(true); f:SetMovable(true)
            Skin:ApplyBackdrop(f)
            
            local title = Skin:CreateTitleBar(f, "Mythic+ Dashboard Settings", function() f:Hide() end)
            title:RegisterForDrag("LeftButton")
            title:SetScript("OnDragStart", function() f:StartMoving() end)
            title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
            
            local content = CreateFrame("Frame", nil, f)
            content:SetPoint("TOPLEFT", 0, -40)
            content:SetPoint("BOTTOMRIGHT", 0, 0)
            f.content = content
        end
        
        f.config = elem
        f:Show()
        
        local kids = { f.content:GetChildren() }
        for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
        local rgns = { f.content:GetRegions() }
        for _, r in ipairs(rgns) do r:Hide() end
        
        MPlus:CreateSettings(f)
    end
end

-- Hook ADDON_LOADED for early initialization if possible
local fEvents = CreateFrame("Frame")
fEvents:RegisterEvent("ADDON_LOADED")
fEvents:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        MPlus:Init()
    end
end)
