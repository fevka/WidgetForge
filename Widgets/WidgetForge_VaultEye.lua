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

local function GetOrCreateMainFrame()
    if mainFrame then return mainFrame end
    
    mainFrame = CreateFrame("Frame", "WidgetForgeVaultEye_Frame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(280, 100)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("HIGH") -- Put on top of most other frames including Vault
    mainFrame:SetToplevel(true) -- Bring to front when clicked
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    
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
    
    mainFrame.vaultData = {
        mythic = { slots = {}, unlocked = 0 },
        delves = { slots = {}, unlocked = 0 },
        raid = { slots = {}, unlocked = 0 }
    }
    mainFrame.currencyData = {}
    mainFrame.accordions = {}
    
    mainFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "WEEKLY_REWARDS_UPDATE" or event == "CHALLENGE_MODE_COMPLETED" or event == "BOSS_KILL" or event == "ZONE_CHANGED_NEW_AREA" then
            self.lastFetchTime = 0
        end
        VaultEye:FetchData(self)
        VaultEye:UpdateDisplay(self, self.config or {})
    end)
    
    return mainFrame
end

function VaultEye:Load(bar, elemConfig)
    local f = GetOrCreateMainFrame()
    f.config = elemConfig
    f.parentBar = bar
    
    if bar then
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    end
    
    f:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    
    f.sfWidth = (elemConfig.widgetWidth or 280) - 20
    f:SetWidth(elemConfig.widgetWidth or 280)
    
    C_Timer.After(1, function()
        f.lastFetchTime = 0
        VaultEye:FetchData(f)
        VaultEye:UpdateDisplay(f, f.config)
        
        -- Start hidden unless Vault is active
        if _G.WeeklyRewardsFrame and _G.WeeklyRewardsFrame:IsShown() then
            f:Show()
        else
            f:Hide()
        end
    end)
    
    return f
end

function VaultEye:Refresh(bar, elemConfig)
    local f = GetOrCreateMainFrame()
    f.config = elemConfig
    f.sfWidth = (elemConfig.widgetWidth or 280) - 20
    f:SetWidth(elemConfig.widgetWidth or 280)
    
    f.lastFetchTime = 0
    VaultEye:FetchData(f)
    VaultEye:UpdateDisplay(f, f.config)
end

function VaultEye:Unload()
    if mainFrame then
        mainFrame:Hide()
        mainFrame:UnregisterAllEvents()
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
local VAULT_ACTIVITIES = {
    [1] = "mythic",
    [2] = "pvp",
    [3] = "raid",
    [4] = "delves"
}

function VaultEye:FetchData(container)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return end
    
    if container.lastFetchTime and (GetTime() - container.lastFetchTime < 10) then
        return
    end

    local activities = C_WeeklyRewards.GetActivities()
    
    container.vaultData = {
        mythic = { slots = {}, unlocked = 0 },
        delves = { slots = {}, unlocked = 0 },
        raid = { slots = {}, unlocked = 0 }
    }
    
    if activities and #activities > 0 then
        for _, activity in ipairs(activities) do
            local group = VAULT_ACTIVITIES[activity.type] or "delves"
            local ilvl = 0
            if activity.rewards and activity.rewards[1] then
                ilvl = activity.rewards[1].level or 0
            end
            
            local slotInfo = {
                progress = activity.progress,
                threshold = activity.threshold,
                isUnlocked = activity.progress >= activity.threshold,
                level = activity.level,
                itemLevel = ilvl
            }
            if slotInfo.isUnlocked then
                container.vaultData[group].unlocked = container.vaultData[group].unlocked + 1
            end
            table.insert(container.vaultData[group].slots, slotInfo)
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
        local currentY = 0
        local PADDING = -5 -- Slightly increased spacing by ~20% from previous tight gap
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
                        if k ~= key and other.isExpanded then
                            other:SetExpanded(false)
                            other.isExpanded = false
                        end
                    end
                end
                UpdateLayout()
            end
            
            container.accordions[key] = ForgeSkin:CreateAccordion(parent, title, 200, onAccToggle, container.sfWidth)
            container.accordions[key].onAnimUpdate = UpdateLayout -- Hook into ForgeSkin animation Loop
            container.accordions[key].content:Hide()
            container.accordions[key].isExpanded = false
            container.accordions[key].header.arrow:SetTexCoord(0, 1, 0, 1) -- Keep arrow state generic
            
            -- Balance Accordion Headers
            container.accordions[key].header:SetHeight(24) -- Thickened by another 2px (total 24px)
            container.accordions[key].header.arrow:SetSize(12, 12) -- Shrunk by 2 points
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
            row:SetSize(container.sfWidth - 10, 16)
            
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local lFont, _, lFlags = row.label:GetFont()
            row.label:SetFont(lFont, 10, "")
            row.label:SetPoint("LEFT", 5, 0)
            row.label:SetJustifyH("LEFT")
            
            row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            local vFont, _, vFlags = row.value:GetFont()
            row.value:SetFont(vFont, 10, "")
            row.value:SetPoint("RIGHT", -25, 0)
            row.value:SetJustifyH("RIGHT")
            
            acc.rows[rowIndex] = row
        end
        local r = acc.rows[rowIndex]
        r:ClearAllPoints()
        r:SetSize(container.sfWidth - 10, 16)
        r:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -(rowIndex - 1) * 16)
        r:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, -(rowIndex - 1) * 16)
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
        
        for i, slot in ipairs(slots) do
            local row = GetOrCreateRow(acc, i)
            row.label:SetText(string.format("Slot %d (%d/%d)", i, slot.progress, slot.threshold))
            
            if slot.isUnlocked then
                if slot.level and slot.level > 0 then
                    row.value:SetText(string.format("|cff00ff00Lvl %d|r (ilvl %s)", slot.level, slot.itemLevel > 0 and slot.itemLevel or "?"))
                else
                    row.value:SetText(string.format("|cff00ff00Unlocked|r (ilvl %s)", slot.itemLevel > 0 and slot.itemLevel or "?"))
                end
            else
                row.value:SetText("|cffaaaaaaLocked|r")
            end
        end
        
        local rawHeight = #slots * 16
        local boundedHeight = math.min(rawHeight, #slots > 4 and 64 or rawHeight)
        
        if acc.scrollChild then
            acc.scrollChild:SetHeight(rawHeight)
            acc.scrollChild:SetWidth(container.sfWidth - 10)
        end
        
        acc:SetContentHeight(boundedHeight)
    end

    BuildActivitySection("mythic", "Mythic+ Dungeons", data.mythic, cfg.trackMythicPlus ~= false)
    BuildActivitySection("delves", "Delves & World", data.delves, cfg.trackDelves ~= false)
    BuildActivitySection("raid", "Raid Bosses", data.raid, cfg.trackRaid ~= false)
    
    if cfg.trackCurrencies ~= false and container.currencyData and #container.currencyData > 0 then
        local acc = GetOrCreateAccordion("currencies", "Currencies", container.contentFrame, true)
        
        for i, curr in ipairs(container.currencyData) do
            local row = GetOrCreateRow(acc, i)
            local tex = curr.icon and string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t ", curr.icon) or ""
            row.label:SetText(tex .. curr.name)
            
            local amt = tostring(curr.quantity or 0)
            if curr.maxQuantity and curr.maxQuantity > 0 then
                amt = amt .. " / " .. tostring(curr.maxQuantity)
            end
            row.value:SetText("|cffffffff" .. amt .. "|r")
        end
        
        local rawHeight = #container.currencyData * 16
        local boundedHeight = math.min(rawHeight, #container.currencyData > 7 and 112 or rawHeight)
        
        if acc.scrollChild then
            acc.scrollChild:SetHeight(rawHeight)
            acc.scrollChild:SetWidth(container.sfWidth - 10)
        end
        
        acc:SetContentHeight(boundedHeight)
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
            VaultEye:Refresh(nil, config)
        end
    end

    sb:AddHeader("VaultEye - Sections")
    sb:AddCheckbox("trackMythicPlus", "Track Mythic+ Dungeons", true, config, Rebuild)
    sb:AddCheckbox("trackDelves", "Track Delves & World", true, config, Rebuild)
    sb:AddCheckbox("trackRaid", "Track Raid Bosses", true, config, Rebuild)
    sb:AddCheckbox("trackCurrencies", "Track Upgrade Materials", true, config, Rebuild)
    
    sb:AddHeader("Window Size")
    sb:AddSlider("widgetWidth", "Width", 200, 600, 5, 280, config, Rebuild)
    
    sb:Finish()
end

-- ============================================================================
-- Great Vault (WeeklyRewardsFrame) Integration (Auto Show/Hide)
-- ============================================================================
local vaultHookFrame = CreateFrame("Frame")
vaultHookFrame:RegisterEvent("ADDON_LOADED")
local hooksApplied = false

local function ApplyVaultHooks()
    if hooksApplied then return end
    
    if _G.WeeklyRewardsFrame then
        _G.WeeklyRewardsFrame:HookScript("OnShow", function()
            if mainFrame then mainFrame:Show() end
        end)
        
        _G.WeeklyRewardsFrame:HookScript("OnHide", function()
            if mainFrame then mainFrame:Hide() end
        end)
        
        hooksApplied = true
    end
end

-- If Blizzard_WeeklyRewards is already loaded (e.g. on /reload)
if C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
    ApplyVaultHooks()
end

vaultHookFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_WeeklyRewards" then
        ApplyVaultHooks()
    end
end)

return VaultEye
