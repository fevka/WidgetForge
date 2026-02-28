-- =========================================================================
--  WidgetForge - VaultEye Module
--  Comprehensive Great Vault & Currency Tracker (Standalone HUD w/ Accordions)
-- =========================================================================

local addonName, addonTable = ...
if not _G.WidgetForge then return end

_G.WidgetForge.VaultEye = {}
local VaultEye = _G.WidgetForge.VaultEye
local Skin = _G.ForgeSkin

local mainFrame = nil

local function IsConfigOpen()
    return _G.WidgetForgeConfig and _G.WidgetForgeConfig:IsShown()
end

local function UpdateMainFrameScale()
    if not mainFrame then return end
    -- To prevent "huge size", we cannot blindly force scale to 1 on UIParent
    -- because UIParent itself is scaled by the game's Global UI Scale.
    -- If we use 1, it renders unscaled (massive on large monitors).
    -- We want the widget to match the standard UI scale.
    local uiScale = UIParent:GetEffectiveScale()
    mainFrame:SetScale(uiScale)
end

local function SavePosition()
    if not mainFrame then return end
    if not _G.WidgetForgeDB then return end
    local point, _, relPoint, x, y = mainFrame:GetPoint()
    _G.WidgetForgeDB.vaultEyePos = { point = point, x = x, y = y }
end

local function RestorePosition()
    if not mainFrame then return end
    local pos = _G.WidgetForgeDB and _G.WidgetForgeDB.vaultEyePos
    if pos and pos.point then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        -- Default: right side of PVEFrame if it exists, otherwise center
        mainFrame:ClearAllPoints()
        local pve = _G.PVEFrame
        if pve and pve:IsShown() then
            mainFrame:SetPoint("TOPLEFT", pve, "TOPRIGHT", 10, 0)
        else
            mainFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
        end
    end
end

-- Hook into ChallengesFrame visibility to show/hide VaultEye alongside the Mythic+ window
local hooksAdded = false
local function ApplyPVEHooks()
    if hooksAdded or not _G.ChallengesFrame then return end
    hooksAdded = true
    
    _G.ChallengesFrame:HookScript("OnShow", function()
        if not mainFrame then return end
        -- IMPORTANT: ChallengesFrame also appears inside the Great Vault.
        -- Only show when the PVEFrame (dungeon finder, I key) is open.
        if not (_G.PVEFrame and _G.PVEFrame:IsShown()) then return end
        RestorePosition()
        mainFrame:Show()
    end)
    
    _G.ChallengesFrame:HookScript("OnHide", function()
        if not mainFrame then return end
        -- Only hide/save if we were shown via PVEFrame context
        if mainFrame:IsShown() then
            SavePosition()
            mainFrame:Hide()
        end
    end)
    
    -- Also hide when the entire dungeon finder panel closes
    if _G.PVEFrame then
        _G.PVEFrame:HookScript("OnHide", function()
            if mainFrame and mainFrame:IsShown() then
                SavePosition()
                mainFrame:Hide()
            end
        end)
    end
end

local function IsPVEFrameOpen()
    return _G.PVEFrame and _G.PVEFrame:IsShown() and _G.ChallengesFrame and _G.ChallengesFrame:IsShown()
end

local function GetOrCreateMainFrame()
    if mainFrame then return mainFrame end
    
    mainFrame = CreateFrame("Frame", "WidgetForgeVaultEye_Frame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(280, 100)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetScale(1) -- Set dynamically by UpdateMainFrameScale later
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    -- Initial strata; restored position is set in RestorePosition() when PVE opens
    
    if Skin and Skin.ApplyBackdrop then
        Skin:ApplyBackdrop(mainFrame, 0.95, 1) -- Clean dark theme
    else
        mainFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    
    local fontNormal = (Skin and Skin.Constants and Skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
    
    -- Title
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOP", 0, -8)
    mainFrame.title:SetFont(fontNormal, 12, "OUTLINE")
    mainFrame.title:SetText("|cffffcc00VaultEye Tracker|r")
    
    -- Display Content Container
    mainFrame.contentFrame = CreateFrame("Frame", nil, mainFrame)
    mainFrame.contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -35)
    mainFrame.contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    
    -- Summary Panel
    mainFrame.summaryPanel = CreateFrame("Frame", nil, mainFrame.contentFrame, "BackdropTemplate")
    mainFrame.summaryPanel:SetPoint("TOPLEFT", 0, 0)
    mainFrame.summaryPanel:SetPoint("TOPRIGHT", 0, 0)
    mainFrame.summaryPanel:SetHeight(24)
    if Skin and Skin.ApplyBackdrop then
        Skin:ApplyBackdrop(mainFrame.summaryPanel, 0.2, 0.8)
    else
        mainFrame.summaryPanel:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        mainFrame.summaryPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        mainFrame.summaryPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    
    mainFrame.summaryText = mainFrame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.summaryText:SetPoint("CENTER", 0, 0)
    mainFrame.summaryText:SetFont(fontNormal, 10, "")
    mainFrame.summaryText:SetText("No Vault Data")
    
    mainFrame.vaultData = {
        mythic = { slots = {}, unlocked = 0, allRuns = {} },
        delves = { slots = {}, unlocked = 0, allRuns = {} },
        raid = { slots = {}, unlocked = 0, allRuns = {} }
    }
    mainFrame.currencyData = {}
    mainFrame.accordions = {}
    
    mainFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "Blizzard_ChallengesUI" then
                ApplyPVEHooks()
            end
            return
        end
        -- Refresh data only - NEVER show/hide here. ChallengesFrame hooks own visibility.
        if event == "WEEKLY_REWARDS_UPDATE" or event == "CHALLENGE_MODE_COMPLETED" or event == "BOSS_KILL" or event == "ZONE_CHANGED_NEW_AREA" then
            self.lastFetchTime = 0
        end
        if IsPVEFrameOpen() then
            VaultEye:FetchData(self)
            VaultEye:UpdateDisplay(self, self.config or {})
        end
    end)
    
    return mainFrame
end

-- Centralized sizing/scaling/visibility helper.
-- Every code path (Load, Refresh, Vault hooks) funnels through here
-- so the widget ALWAYS ends up with the exact same on-screen dimensions.
local function ApplyConfig(f, elemConfig)
    if not elemConfig then elemConfig = {} end
    local w = tonumber(elemConfig.widgetWidth) or 280
    if w < 200 then w = 200 end -- Minimum safe width
    if w > 600 then w = 600 end -- Maximum safe width
    f.sfWidth = w - 20
    f:SetWidth(w)
    UpdateMainFrameScale()
    f.config = elemConfig
end

local function IsPVEFrameOpen()
    return _G.PVEFrame and _G.PVEFrame:IsShown() and _G.ChallengesFrame and _G.ChallengesFrame:IsShown()
end

local loadedOnce = false

function VaultEye:Load(bar, elemConfig)
    local f = GetOrCreateMainFrame()
    f.parentBar = bar
    
    ApplyPVEHooks() -- Attach ChallengesFrame hooks (safe to call multiple times)
    
    if bar then
        bar:SetAlpha(0)   -- Hide the WidgetForge dummy bar placeholder
        bar:EnableMouse(false)
    end
    
    -- Apply config (width etc.)
    ApplyConfig(f, elemConfig)
    
    -- Register events only once
    if not loadedOnce then
        f:RegisterEvent("WEEKLY_REWARDS_UPDATE")
        f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        f:RegisterEvent("BOSS_KILL")
        f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        f:RegisterEvent("ADDON_LOADED")
        loadedOnce = true
    end
    
    -- Always hide on load; ChallengesFrame:OnShow controls when to appear
    f:Hide()
    
    -- Pre-fetch data in background so it's ready when the window opens
    C_Timer.After(0.1, function()
        f.lastFetchTime = 0
        VaultEye:FetchData(f)
        VaultEye:UpdateDisplay(f, f.config)
    end)
    
    return f
end

function VaultEye:Refresh(bar, elemConfig)
    local f = GetOrCreateMainFrame()
    ApplyConfig(f, elemConfig)
    -- Data refresh only; show if config is open so user can preview
    f.lastFetchTime = 0
    VaultEye:FetchData(f)
    VaultEye:UpdateDisplay(f, f.config)
    
    if IsPVEFrameOpen() or IsConfigOpen() then
        f:Show()
    end
end

function VaultEye:Unload()
    if mainFrame then
        mainFrame:Hide()
        mainFrame:UnregisterAllEvents()
        loadedOnce = false
        if mainFrame.parentBar then
            mainFrame.parentBar:SetAlpha(1)
            mainFrame.parentBar:EnableMouse(true)
            mainFrame.parentBar = nil
        end
    end
end

-- ============================================================================
-- Data Fetching
-- ============================================================================
-- Build activity type mapping dynamically from WoW's own Enum values.
-- This is immune to Blizzard changing the integer values between patches.
local VAULT_ACTIVITIES = {}
do
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    if E then
        if E.MythicPlus    then VAULT_ACTIVITIES[E.MythicPlus]    = "mythic" end
        if E.Raid           then VAULT_ACTIVITIES[E.Raid]           = "raid"   end
        if E.World          then VAULT_ACTIVITIES[E.World]          = "delves" end
        if E.Activities     then VAULT_ACTIVITIES[E.Activities]     = "mythic" end
        if E.RankedPvP      then VAULT_ACTIVITIES[E.RankedPvP]      = "pvp"    end
        -- TWW may add a dedicated Delves enum
        if E.Delves         then VAULT_ACTIVITIES[E.Delves]         = "delves" end
    else
        -- Ultimate fallback if the enum doesn't exist
        VAULT_ACTIVITIES = { [1] = "mythic", [2] = "pvp", [3] = "raid", [4] = "delves" }
    end
end

local function GetRunName(activityType, action)
    local E = Enum and Enum.WeeklyRewardChestThresholdType
    
    if E and activityType == E.MythicPlus then
        if action and action > 0 and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            local name = C_ChallengeMode.GetMapUIInfo(action)
            if name and name ~= "" then return name end
        end
    end
    
    if E and activityType == E.Raid then
        if action and action > 0 and C_EncounterJournal and C_EncounterJournal.GetEncounterInfo then
            local name = C_EncounterJournal.GetEncounterInfo(action)
            if name and name ~= "" then return name end
        end
    end
    
    if not action or action == 0 then 
        if E and activityType == E.World then return "Delve" end
        if E and activityType == E.Delves then return "Delve" end
        return "Unknown Activity"
    end
    
    -- Try to fallback to generic encounter/activity name
    if C_WeeklyRewards and C_WeeklyRewards.GetActivityEncounterInfo then
        local name = C_WeeklyRewards.GetActivityEncounterInfo(activityType, action)
        if name and name ~= "" then return name end
    end
    
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(action)
        if info and info.name and info.name ~= "" then return info.name end
    end
    
    return "Unknown Map"
end

function VaultEye:FetchData(container)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return end
    
    if container.lastFetchTime and (GetTime() - container.lastFetchTime < 10) then
        return
    end

    local activities = C_WeeklyRewards.GetActivities()
    
    container.vaultData = {
        mythic = { slots = {}, unlocked = 0, allRuns = {} },
        delves = { slots = {}, unlocked = 0, allRuns = {} },
        raid = { slots = {}, unlocked = 0, allRuns = {} }
    }
    
    -- Check if there are any claimable rewards
    container.hasAvailableRewards = C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or false
    
    if activities and #activities > 0 then
        for _, activity in ipairs(activities) do
            local group = VAULT_ACTIVITIES[activity.type]
            if not group or group == "pvp" then
                -- Skip PvP or unknown types (we don't track PvP)
            else
                local ilvl = 0
                
                -- Try to get expected item level from rewards
                if activity.rewards and #activity.rewards > 0 then
                    for _, reward in ipairs(activity.rewards) do
                        if reward.itemLevel and reward.itemLevel > ilvl then
                            ilvl = reward.itemLevel
                        elseif reward.level and reward.level > ilvl then
                            ilvl = reward.level  
                        end
                    end
                end
                
                -- Build run info from activity-level data
                -- (activity.runs array does NOT exist in the WoW API)
                local runHistory = {}
                if activity.progress and activity.progress > 0 and activity.level and activity.level > 0 then
                    local runName = nil
                    
                    if group == "raid" then
                        -- activity.level for raid = difficulty ID (14=Normal, 15=Heroic, 16=Mythic, 17=LFR)
                        local diffName = GetDifficultyInfo and GetDifficultyInfo(activity.level)
                        runName = diffName or ("Difficulty " .. activity.level)
                    elseif group == "delves" then
                        runName = "Delve"
                    elseif group == "mythic" then
                        runName = "Mythic+"
                    end
                    
                    table.insert(runHistory, {
                        level = activity.level,
                        action = 0,
                        name = runName
                    })
                end
                
                local slotInfo = {
                    progress = activity.progress or 0,
                    threshold = activity.threshold or 1,
                    isUnlocked = (activity.progress or 0) >= (activity.threshold or 1),
                    level = activity.level or 0,
                    itemLevel = ilvl,
                    runs = runHistory
                }
                
                -- Only store the highest-level entry for the group (first slot has the level)
                if #runHistory > 0 then
                    local existingRuns = container.vaultData[group].allRuns
                    if not existingRuns or #existingRuns == 0 then
                        container.vaultData[group].allRuns = runHistory
                    end
                end
                
                if slotInfo.isUnlocked then
                    container.vaultData[group].unlocked = container.vaultData[group].unlocked + 1
                end
                table.insert(container.vaultData[group].slots, slotInfo)
            end
        end
        
        -- Override Mythic+ allRuns using C_MythicPlus.GetRunHistory for maximum accuracy
        if C_MythicPlus and C_MythicPlus.GetRunHistory then
            local mythicRuns = C_MythicPlus.GetRunHistory(false, true)
            if mythicRuns and #mythicRuns > 0 then
                local realMythic = {}
                for _, r in ipairs(mythicRuns) do
                    if r.completed then
                        local mapName = "Unknown Dungeon"
                        if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                            local uiName = C_ChallengeMode.GetMapUIInfo(r.mapChallengeModeID)
                            if uiName and uiName ~= "" then mapName = uiName end
                        end
                        
                        table.insert(realMythic, {
                            level = r.level or 0,
                            action = r.mapChallengeModeID or 0,
                            name = mapName
                        })
                    end
                end
                
                table.sort(realMythic, function(a, b) return a.level > b.level end)
                container.vaultData["mythic"].allRuns = realMythic
                
                -- Also sync the slot.runs for tooltips
                for i, slot in ipairs(container.vaultData["mythic"].slots) do
                    local slotTopRuns = {}
                    for j = 1, math.min(slot.progress, #realMythic) do
                        table.insert(slotTopRuns, {
                            level = realMythic[j].level,
                            action = realMythic[j].action,
                            name = realMythic[j].name
                        })
                    end
                    slot.runs = slotTopRuns
                end
            end
        end
        
        -- Build Raid boss list using C_WeeklyRewards.GetActivityEncounterInfo
        local E = Enum and Enum.WeeklyRewardChestThresholdType
        if E and E.Raid then
            local raidRuns = container.vaultData["raid"].allRuns or {}
            local diffName = (#raidRuns > 0 and raidRuns[1].name) or "Raid"
            local raidLevel = (#raidRuns > 0 and raidRuns[1].level) or 0

            -- Try to get encounter names
            local maxProgress = 0
            for _, slot in ipairs(container.vaultData["raid"].slots) do
                if slot.progress > maxProgress then maxProgress = slot.progress end
            end
            
            if maxProgress > 0 then
                local bossRuns = {}
                
                -- Load Encounter Journal addon if needed for name resolution
                if C_AddOns and C_AddOns.LoadAddOn then
                    pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
                elseif LoadAddOn then
                    pcall(LoadAddOn, "Blizzard_EncounterJournal")
                end
                
                -- Use C_WeeklyRewards.GetActivityEncounterInfo to get the encounter list
                if C_WeeklyRewards and C_WeeklyRewards.GetActivityEncounterInfo then
                    local ok, encounterList = pcall(C_WeeklyRewards.GetActivityEncounterInfo, E.Raid, 1)
                    
                    if ok and encounterList and type(encounterList) == "table" and #encounterList > 0 then
                        -- Sort encounters by uiOrder (ascending = raid boss order)
                        local sortedEncounters = {}
                        for _, entry in ipairs(encounterList) do
                            if type(entry) == "table" and entry.encounterID then
                                table.insert(sortedEncounters, entry)
                            end
                        end
                        table.sort(sortedEncounters, function(a, b) return (a.uiOrder or 0) < (b.uiOrder or 0) end)
                        
                        -- Only take the bosses the user actually killed (maxProgress count)
                        for bi = 1, math.min(maxProgress, #sortedEncounters) do
                            local entry = sortedEncounters[bi]
                            local bossName = nil
                            
                            if entry.encounterID then
                                if C_EncounterJournal and C_EncounterJournal.GetEncounterInfo then
                                    local eName = C_EncounterJournal.GetEncounterInfo(entry.encounterID)
                                    if eName and eName ~= "" then bossName = eName end
                                end
                                -- Fallback: try EJ_GetEncounterInfo
                                if not bossName and EJ_GetEncounterInfo then
                                    local eName = EJ_GetEncounterInfo(entry.encounterID)
                                    if eName and eName ~= "" then bossName = eName end
                                end
                            end
                            
                            table.insert(bossRuns, {
                                level = raidLevel,
                                action = entry.encounterID or 0,
                                name = bossName or (diffName .. " Boss #" .. bi)
                            })
                        end
                        -- Resolve raid instance name from the first encounter
                        local firstInst = sortedEncounters[1] and sortedEncounters[1].instanceID
                        if firstInst and EJ_GetInstanceInfo then
                            local instName = EJ_GetInstanceInfo(firstInst)
                            if instName and instName ~= "" then
                                container.vaultData["raid"].raidName = instName
                            end
                        end
                    end
                end
                
                -- Fallback if API didn't work
                if #bossRuns == 0 then
                    for idx = 1, maxProgress do
                        table.insert(bossRuns, {
                            level = raidLevel,
                            action = idx,
                            name = diffName .. " Boss #" .. idx
                        })
                    end
                end
                
                if not container.vaultData["raid"].raidName then
                    container.vaultData["raid"].raidName = "Raid"
                end
                
                container.vaultData["raid"].allRuns = bossRuns
                for _, slot in ipairs(container.vaultData["raid"].slots) do
                    slot.runs = bossRuns
                end
            end
        end
        
        -- Build Delve runs using slot level data and GetActivityEncounterInfo
        local delveData = container.vaultData["delves"]
        if delveData then
            local maxProgress = 0
            for _, slot in ipairs(delveData.slots) do
                if slot.progress > maxProgress then maxProgress = slot.progress end
            end
            
            if maxProgress > 0 then
                local delveRuns = {}
                local E_Delve = E and (E.Delves or E.World)
                
                -- Try GetActivityEncounterInfo for delves (like we did for raid)
                if E_Delve and C_WeeklyRewards and C_WeeklyRewards.GetActivityEncounterInfo then
                    local ok, encounterList = pcall(C_WeeklyRewards.GetActivityEncounterInfo, E_Delve, 1)
                    if ok and encounterList and type(encounterList) == "table" and #encounterList > 0 then
                        for di, entry in ipairs(encounterList) do
                            if di > maxProgress then break end
                            local delveName = nil
                            if type(entry) == "table" then
                                -- Try to resolve name from encounterID or other fields
                                if entry.encounterID and C_EncounterJournal and C_EncounterJournal.GetEncounterInfo then
                                    delveName = C_EncounterJournal.GetEncounterInfo(entry.encounterID)
                                end
                                if not delveName and entry.name then delveName = entry.name end
                            end
                            table.insert(delveRuns, {
                                level = (entry and entry.level) or 0,
                                action = (entry and entry.encounterID) or di,
                                name = delveName or ("Delve #" .. di)
                            })
                        end
                    end
                end
                
                -- Fallback: build from slot level data (each slot's level = Nth best tier)
                if #delveRuns == 0 then
                    -- Collect level values from slots sorted by threshold
                    local sortedSlots = {}
                    for _, slot in ipairs(delveData.slots) do
                        table.insert(sortedSlots, slot)
                    end
                    table.sort(sortedSlots, function(a, b) return a.threshold < b.threshold end)
                    
                    -- The first slot with level > 0 tells us the Nth-best tier
                    -- Build runs: we know progress count and the slot levels
                    for si, slot in ipairs(sortedSlots) do
                        if slot.level and slot.level > 0 then
                            -- This slot's level = the (threshold)th best delve tier
                            -- E.g. threshold=2, level=2 means 2nd best run was Tier 2
                            table.insert(delveRuns, {
                                level = slot.level,
                                action = 0,
                                name = string.format("Delve (Tier %d)", slot.level)
                            })
                        end
                    end
                    
                    -- If no slot had a level, just show progress count
                    if #delveRuns == 0 then
                        table.insert(delveRuns, {
                            level = 0,
                            action = 0,
                            name = string.format("%d Delves completed", maxProgress)
                        })
                    end
                end
                
                table.sort(delveRuns, function(a, b) return (a.level or 0) > (b.level or 0) end)
                delveData.allRuns = delveRuns
                for _, slot in ipairs(delveData.slots) do
                    slot.runs = delveRuns
                end
            end
        end
    end
    
    container.currencyData = {}
    
    local TARGET_NAMES = {
        ["Valorstones"] = true, ["Twilight's Blade Insignia"] = true,
        ["Resonance Crystals"] = true, ["Restored Coffer Key"] = true,
        ["Kej"] = true, ["Undercoin"] = true,
        
        -- Ethereal / Midnight Crests
        ["Weathered Ethereal Crest"] = true, ["Carved Ethereal Crest"] = true, 
        ["Runed Ethereal Crest"] = true, ["Gilded Ethereal Crest"] = true,
        ["Adventurer Crest"] = true, ["Veteran Crest"] = true, 
        ["Champion Crest"] = true, ["Hero Crest"] = true,
        
        -- TWW Base Crests
        ["Weathered Harbinger Crest"] = true, ["Carved Harbinger Crest"] = true, 
        ["Runed Harbinger Crest"] = true, ["Gilded Harbinger Crest"] = true,
        
        -- Dragonflight Awakened/Dreaming
        ["Flightstones"] = true,
        ["Awakened Whelpling's Crest"] = true, ["Awakened Drake's Crest"] = true, 
        ["Awakened Wyrm's Crest"] = true, ["Awakened Aspect's Crest"] = true
    }

    if C_CurrencyInfo.ExpandCurrencyList then
        C_CurrencyInfo.ExpandCurrencyList(0, true)
    end

    local count = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, count do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader then
            if TARGET_NAMES[info.name] and info.quantity > 0 then
                local n = info.name or "Currency"
                n = string.gsub(n, " Ethereal Crest", "")
                n = string.gsub(n, " Harbinger Crest", "")
                n = string.gsub(n, " Dreaming Crest", "")
                n = string.gsub(n, " Awakened", "")
                
                table.insert(container.currencyData, {
                    name = n,
                    icon = info.iconFileID,
                    quantity = info.quantity or 0,
                    maxQuantity = (info.maxQuantity and info.maxQuantity > 0) and info.maxQuantity or nil
                })
            end
        end
    end
    
    container.lastFetchTime = GetTime()
end

-- ============================================================================
-- Rendering Elements
-- ============================================================================
function VaultEye:UpdateDisplay(container, cfg)
    if not cfg then return end
    
    local data = container.vaultData
    local activeAccordions = {}
    
    local function UpdateLayout()
        local currentY = -28 -- Offset for Summary Panel
        local PADDING = -5 -- Normal padding
        for _, acc in ipairs(activeAccordions) do
            if acc:IsShown() then
                acc:ClearAllPoints()
                acc:SetPoint("TOPLEFT", container.contentFrame, "TOPLEFT", 0, currentY)
                acc:SetPoint("TOPRIGHT", container.contentFrame, "TOPRIGHT", 0, currentY)
                currentY = currentY - acc:GetHeight() - PADDING
            end
        end
        local totalHeight = math.abs(currentY)
        container.contentFrame:SetHeight(totalHeight)
        container:SetHeight(totalHeight + 45) -- 35 for top offset + 10 for bottom padding
    end
    
    local function GetOrCreateAccordion(key, title, parent, useScroll)
        if not container.accordions[key] then
            local function onAccToggle(isExpanding)
                if isExpanding then
                    for k, other in pairs(container.accordions) do
                        if k ~= key and other.expanded then
                            other:SetExpanded(false)
                            if other.header then
                                other.header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                            end
                        end
                    end
                end
                UpdateLayout()
            end
            
            container.accordions[key] = ForgeSkin:CreateAccordion(parent, title, 200, onAccToggle, container.sfWidth)
            container.accordions[key].onAnimUpdate = UpdateLayout -- Hook into ForgeSkin animation Loop
            
            local anyExpanded = false
            for _, existing in pairs(container.accordions) do
                if existing.expanded and existing ~= container.accordions[key] then anyExpanded = true; break end
            end
            if not anyExpanded then
                container.accordions[key]:SetExpanded(true)
                -- Force instant snap for the very first accordion created so it doesn't animate out of bounds
                container.accordions[key].currentHeight = container.accordions[key].targetHeight
                container.accordions[key]:SetHeight(container.accordions[key].targetHeight)
                UpdateLayout() 
            end
            
            container.accordions[key].header.arrow:SetTexCoord(0, 1, 0, 1) -- Keep arrow state generic
            
            -- Balance Accordion Headers 
            container.accordions[key].header:SetHeight(24) 
            container.accordions[key].header.arrow:SetSize(12, 12) 
            if container.accordions[key].header.text then
                local currentFont, _, currentFlags = container.accordions[key].header.text:GetFont()
                container.accordions[key].header.text:SetFont(currentFont, 11, currentFlags)
                container.accordions[key].header.text:ClearAllPoints()
                container.accordions[key].header.text:SetPoint("LEFT", 6, 0)
            end
            
            local scrollTarget = container.accordions[key].content
            
            if useScroll then
                local accScroll, accChild = ForgeSkin:CreateScrollFrame(scrollTarget, container.sfWidth - 10, 100)
                accScroll:SetPoint("TOPLEFT", 2, -2)
                accScroll:SetPoint("BOTTOMRIGHT", 2, 2) -- Shifted 1px to the right
                
                container.accordions[key].scrollFrame = accScroll
                container.accordions[key].scrollChild = accChild
            else
                container.accordions[key].scrollChild = scrollTarget
            end
            
            ForgeSkin:ApplyBackdrop(scrollTarget, 0.1, 0.5)
            scrollTarget:SetBackdropColor(0, 0, 0, 0.3)
            scrollTarget:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        end
        local acc = container.accordions[key]
        -- Handle resize of container.sfWidth dynamically
        acc:SetWidth(container.sfWidth)
        acc.header:SetWidth(container.sfWidth)
        acc.content:SetWidth(container.sfWidth)
        
        acc:Show()
        table.insert(activeAccordions, acc)
        return acc
    end
    
    local function GetOrCreateRow(acc, rowIndex)
        acc.rows = acc.rows or {}
        local parentFrame = acc.scrollChild or acc.content
        
        if not acc.rows[rowIndex] then
            local row = CreateFrame("Frame", nil, parentFrame)
            row:SetSize(container.sfWidth - 10, 16) -- Normal row
            
            -- Background/Border for the Bar
            row.bg = CreateFrame("Frame", nil, row, "BackdropTemplate")
            row.bg:SetAllPoints()
            
            -- Tooltip Script block
            row.bg:EnableMouse(true)
            row.bg:SetScript("OnEnter", function(self)
                if not self:GetParent().tooltipText then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self:GetParent().tooltipTitle or "Vault Slot", 1, 1, 1)
                GameTooltip:AddLine(self:GetParent().tooltipText, 1, 0.82, 0, true)
                GameTooltip:Show()
            end)
            row.bg:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            -- Progress Bar
            row.bar = CreateFrame("StatusBar", nil, row.bg)
            row.bar:SetMinMaxValues(0, 1)
            
            row.label = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local lFont, _, lFlags = row.label:GetFont()
            row.label:SetFont(lFont, 10, "OUTLINE") -- Normal font
            row.label:SetPoint("LEFT", 5, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetShadowOffset(1, -1)
            
            row.value = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            local vFont, _, vFlags = row.value:GetFont()
            row.value:SetFont(vFont, 10, "OUTLINE") -- Normal font
            row.value:SetPoint("RIGHT", -15, 0)
            row.value:SetJustifyH("RIGHT")
            row.value:SetShadowOffset(1, -1)
            
            acc.rows[rowIndex] = row
        end
        local r = acc.rows[rowIndex]
        r:ClearAllPoints()
        r:SetSize(container.sfWidth - 10, 16)
        r:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 2, -(rowIndex - 1) * 16 - 2)
        r:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -2, -(rowIndex - 1) * 16 - 2)
        
        -- Apply Visual Configs to Row
        local barBorderColor = cfg.barBorderColor or {0.3, 0.3, 0.3, 1}
        local barBorderSize = cfg.barBorderSize or 1
        local barBgAlpha = (cfg.barBgAlpha or 80) / 100
        local textureName = cfg.barTexture or "Smooth"
        
        local texPath = "Interface\\TargetingFrame\\UI-StatusBar"
        if ForgeSkin and ForgeSkin.Media and ForgeSkin.Media.Textures[textureName] then
            texPath = ForgeSkin.Media.Textures[textureName]
        end
        r.bar:SetStatusBarTexture(texPath)
        
        if barBorderSize > 0 then
            r.bg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = barBorderSize})
            r.bg:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
            r.bg:SetBackdropBorderColor(unpack(barBorderColor))
            r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT", barBorderSize, -barBorderSize)
            r.bar:SetPoint("BOTTOMRIGHT", r.bg, "BOTTOMRIGHT", -barBorderSize, barBorderSize)
        else
            r.bg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
            r.bg:SetBackdropColor(0.1, 0.1, 0.1, barBgAlpha)
            r.bg:SetBackdropBorderColor(0, 0, 0, 0)
            r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT", 0, 0)
            r.bar:SetPoint("BOTTOMRIGHT", r.bg, "BOTTOMRIGHT", 0, 0)
        end
        
        r:Show()
        return r
    end

    -- Hide all initially
    for _, acc in pairs(container.accordions) do
        acc:Hide()
        if acc.rows then
            for _, r in ipairs(acc.rows) do r:Hide() end
        end
    end

    local function BuildActivitySection(key, title, groupData, isEnabled)
        if not isEnabled or not groupData.slots or #groupData.slots == 0 then return end
        
        local acc = GetOrCreateAccordion(key, title, container.contentFrame, false)
        local slots = groupData.slots
        table.sort(slots, function(a, b) return a.threshold < b.threshold end)
        
        local allRuns = groupData.allRuns or {}
        table.sort(allRuns, function(a, b) return (a.level or 0) > (b.level or 0) end)
        
        if not acc.summaryRow then
            local sr = CreateFrame("Frame", nil, acc.scrollChild or acc.content)
            sr:SetSize(container.sfWidth - 10, 16)
            sr.text = sr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local sfFont = (ForgeSkin and ForgeSkin.Constants and ForgeSkin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
            sr.text:SetFont(sfFont, 10, "OUTLINE")
            sr.text:SetPoint("LEFT", 5, 0)
            sr.text:SetJustifyH("LEFT")
            acc.summaryRow = sr
        end
        
        local sr = acc.summaryRow
        sr:ClearAllPoints()
        sr:SetPoint("TOPLEFT", acc.scrollChild or acc.content, "TOPLEFT", 2, -2)
        sr:SetPoint("TOPRIGHT", acc.scrollChild or acc.content, "TOPRIGHT", -2, -2)
        sr:Show()
        
        local totalProgress = 0
        for _, slot in ipairs(slots) do
            if slot.progress > totalProgress then totalProgress = slot.progress end
        end
        
        if key == "mythic" or key == "delves" then
            local top4 = {}
            for j = 1, math.min(4, #allRuns) do 
                local rData = allRuns[j]
                if rData.name then
                    if key == "delves" then
                        table.insert(top4, rData.name)
                    else
                        table.insert(top4, string.format("%s (+%d)", rData.name, rData.level))
                    end
                else
                    table.insert(top4, string.format("Lvl %d", rData.level))
                end
            end
            
            if #top4 > 0 then
                sr.text:SetText(string.format("|cffffff00Top %d:|r %s |cffaaaaaa(Total: %d)|r", #top4, table.concat(top4, ", "), totalProgress))
            elseif totalProgress > 0 then
                sr.text:SetText(string.format("|cffffff00Runs Completed:|r %d", totalProgress))
            else
                sr.text:SetText("|cffaaaaaaNo completed runs this week.|r")
            end
        else
            local raidName = groupData.raidName or "Raid"
            -- Show raid name + last killed boss only
            local lastBoss = #allRuns > 0 and allRuns[#allRuns] and allRuns[#allRuns].name
            
            if lastBoss then
                sr.text:SetText(string.format("|cffffff00%s|r - %s", raidName, lastBoss))
            elseif totalProgress > 0 then
                sr.text:SetText(string.format("|cffffff00%s|r - %d defeated", raidName, totalProgress))
            else
                sr.text:SetText(string.format("|cffaaaaaa%s|r", raidName))
            end
        end
        
        for i, slot in ipairs(slots) do
            local row = GetOrCreateRow(acc, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", acc.scrollChild or acc.content, "TOPLEFT", 2, -(i) * 16 - 2)
            row:SetPoint("TOPRIGHT", acc.scrollChild or acc.content, "TOPRIGHT", -2, -(i) * 16 - 2)
            
            local pct = math.min(1, slot.progress / slot.threshold)
            row.bar:SetValue(pct)
            
            if slot.isUnlocked then
                local actColor = cfg.colorUnlocked or {0.2, 0.8, 0.2, 0.8}
                
                row.bar:SetStatusBarColor(unpack(actColor))
                row.label:SetText(string.format("Slot %d: Unlocked", i))
                
                if slot.level and slot.level > 0 then
                    row.value:SetText(string.format("|cffffffffLvl %d|r (ilvl %s)", slot.level, slot.itemLevel > 0 and slot.itemLevel or "?"))
                else
                    row.value:SetText(string.format("(ilvl %s)", slot.itemLevel > 0 and slot.itemLevel or "?"))
                end
            else
                local actColorLocked = cfg.colorLocked or {0.4, 0.4, 0.4, 0.6}
                row.bar:SetStatusBarColor(unpack(actColorLocked))
                
                row.label:SetText(string.format("Slot %d: %d/%d", i, slot.progress, slot.threshold))
                row.value:SetText(string.format("|cffaaaaaa%d / %d|r", slot.progress, slot.threshold))
            end
            
            -- Prepare Tooltip text using global allRuns
            local slotRuns = {}
            for j = 1, math.min(slot.threshold, #allRuns) do
                local rData = allRuns[j]
                if rData then
                    if key == "mythic" then
                        table.insert(slotRuns, string.format("%d. %s (+%d)", j, rData.name or "Dungeon", rData.level))
                    elseif key == "raid" then
                        table.insert(slotRuns, string.format("%d. %s", j, rData.name or "Raid Boss"))
                    elseif key == "delves" then
                        if rData.name == "Highest Tier" then
                            table.insert(slotRuns, string.format("- Tier %d", rData.level))
                        else
                            table.insert(slotRuns, string.format("%d. %s (Tier %d)", j, rData.name or "Delve", rData.level))
                        end
                    end
                end
            end
            
            local typeName
            if key == "mythic" then
                typeName = "Mythic+ Dungeons"
            elseif key == "delves" then
                typeName = "Delves"
            else
                typeName = groupData.raidName or "Raid Bosses"
            end
            row.tooltipTitle = string.format("Slot %d: %s (Requires %d)", i, typeName, slot.threshold)
            
            if slot.progress > 0 then
                local needed = math.max(0, slot.threshold - slot.progress)
                if #slotRuns > 0 then
                    local runList = table.concat(slotRuns, "\n")
                    if slot.isUnlocked then
                        row.tooltipText = "|cff00ff00Completed Activities:|r\n" .. runList
                    else
                        row.tooltipText = string.format("Current Activities:\n%s\n\n|cffaaaaaa(Progress: %d/%d - Need %d more)|r", runList, slot.progress, slot.threshold, needed)
                    end
                else
                    if slot.isUnlocked then
                        row.tooltipText = string.format("Progress: %d / %d |cff00ff00(Unlocked)|r\n|cffaaaaaa(Detailed history unavailable)|r", slot.progress, slot.threshold)
                    else
                        row.tooltipText = string.format("Progress: %d / %d\n|cffaaaaaa(Need %d more)|r\n|cffaaaaaa(Detailed history unavailable)|r", slot.progress, slot.threshold, needed)
                    end
                end
            else
                row.tooltipText = "|cffaaaaaaNo activities completed for this bracket yet.|r"
            end
        end
        
        local rawHeight = ((#slots + 1) * 16) + 4
        local boundedHeight = rawHeight
        
        if acc.scrollChild then
            acc.scrollChild:SetHeight(rawHeight)
            acc.scrollChild:SetWidth(container.sfWidth - 10)
        end
        
        acc:SetContentHeight(boundedHeight)
    end

    BuildActivitySection("mythic", "Dungeons", data.mythic, cfg.trackMythicPlus ~= false)
    BuildActivitySection("delves", "Delves & World", data.delves, cfg.trackDelves ~= false)
    BuildActivitySection("raid", "Raid Bosses", data.raid, cfg.trackRaid ~= false)
    
    if cfg.trackCurrencies ~= false and container.currencyData and #container.currencyData > 0 then
        local acc = GetOrCreateAccordion("currencies", "Currencies", container.contentFrame, true)
        
        for i, curr in ipairs(container.currencyData) do
            local row = GetOrCreateRow(acc, i)
            local tex = curr.icon and string.format("|T%s:12:12:0:0:64:64:4:60:4:60|t ", curr.icon) or ""
            row.label:SetText(tex .. curr.name)
            
            local amt = tostring(curr.quantity or 0)
            if curr.maxQuantity and curr.maxQuantity > 0 then
                amt = amt .. " / " .. tostring(curr.maxQuantity)
                row.bar:SetValue(math.min(1, curr.quantity / curr.maxQuantity))
                row.bar:SetStatusBarColor(unpack(cfg.colorCurrency or {0.2, 0.6, 1.0, 0.8}))
            else
                row.bar:SetValue(0)
                row.bar:SetStatusBarColor(0, 0, 0, 0)
            end
            row.value:SetText("|cffffffff" .. amt .. "|r")
        end
        
        local rawHeight = (#container.currencyData * 16) + 4
        local boundedHeight = math.min(rawHeight, #container.currencyData > 7 and 116 or rawHeight)
        
        if acc.scrollChild then
            acc.scrollChild:SetHeight(rawHeight)
            acc.scrollChild:SetWidth(container.sfWidth - 10)
        end
        
        acc:SetContentHeight(boundedHeight)
    end
    
    -- Calculate and Display Summary
    local highestIlvl = 0
    local bestSource = "None"
    local totalUnlocked = 0
    local totalSlots = 0
    
    for key, groupData in pairs(data) do
        if groupData.slots then
            for _, slot in ipairs(groupData.slots) do
                totalSlots = totalSlots + 1
                if slot.isUnlocked then
                    totalUnlocked = totalUnlocked + 1
                    if slot.itemLevel and slot.itemLevel > highestIlvl then
                        highestIlvl = slot.itemLevel
                        bestSource = key == "mythic" and "M+" or (key == "raid" and "Raid" or (key == "delves" and "Delve" or key))
                    end
                end
            end
        end
    end
    
    if container.hasAvailableRewards then
        container.summaryText:SetText("|cff00ff00Vault Reward Available! Click to claim.|r")
    elseif highestIlvl > 0 then
        container.summaryText:SetText(string.format("Best Vault: |cff00ff00ilvl %d|r (%s) — %d/%d Slots", highestIlvl, bestSource, totalUnlocked, totalSlots))
    elseif totalUnlocked > 0 then
        container.summaryText:SetText(string.format("|cff00ff00%d/%d Vault Slots Unlocked|r", totalUnlocked, totalSlots))
    else
        container.summaryText:SetText(string.format("|cffaaaaaa%d/%d Vault Slots — No Rewards Yet|r", totalUnlocked, totalSlots))
    end
    
    UpdateLayout()
end

-- ============================================================================
-- Settings Panel
-- ============================================================================
function VaultEye:CreateSettings(panel)
    local sb = panel.builder
    if not sb then
        sb = _G.WidgetForgeUtils:CreateSettingsBuilder(panel.content)
        panel.builder = sb
    end
    
    local config = panel.config
    local barIndex = panel.barIndex
    
    local function Rebuild()
        if mainFrame then
            ApplyConfig(mainFrame, config)
            mainFrame.lastFetchTime = 0
            VaultEye:FetchData(mainFrame)
            VaultEye:UpdateDisplay(mainFrame, config)
            -- Show if config is open for live preview
            if IsConfigOpen() or IsPVEFrameOpen() then
                RestorePosition()
                mainFrame:Show()
            else
                mainFrame:Hide()
            end
        end
    end

    sb:AddHeader("VaultEye - Sections")
    sb:AddSwitch("trackMythicPlus", "Track Dungeons", true, config, Rebuild)
    sb:AddSwitch("trackDelves", "Track Delves & World", true, config, Rebuild)
    sb:AddSwitch("trackRaid", "Track Raid Bosses", true, config, Rebuild)
    sb:AddSwitch("trackCurrencies", "Track Upgrade Materials", true, config, Rebuild)
    sb:AddSwitch("showRunHistory", "Show Individual Run Levels", true, config, Rebuild)
    
    sb:AddHeader("Bar Styling")
    local textures = {"Smooth", "Minimalist", "Perl", "Flat"}
    if ForgeSkin and ForgeSkin.Media and ForgeSkin.Media.Textures then
        textures = {}
        for k in pairs(ForgeSkin.Media.Textures) do table.insert(textures, k) end
        table.sort(textures)
    end
    sb:AddDropdown("barTexture", "Bar Texture", textures, "Smooth", config, Rebuild)
    sb:AddSlider("barBorderSize", "Bar Border Size", 0, 3, 1, 1, config, Rebuild)
    sb:AddColor("barBorderColor", "Bar Border Color", {0.3, 0.3, 0.3, 1}, config, Rebuild)
    sb:AddSlider("barBgAlpha", "Bar Background Alpha (%)", 0, 100, 5, 80, config, Rebuild)
    
    sb:AddHeader("Window Size")
    sb:AddSlider("widgetWidth", "Width", 200, 600, 5, 280, config, Rebuild)
    
    sb:Finish()
end

-- End of VaultEye

return VaultEye
