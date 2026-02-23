-- =========================================================================
--  WidgetForge - VaultEye Module
--  Comprehensive Great Vault & Currency Tracker
-- =========================================================================

local addonName, addonTable = ...
if not _G.WidgetForge then return end

_G.WidgetForge.VaultEye = {}
local VaultEye = _G.WidgetForge.VaultEye

local Skin = _G.ForgeSkin

function VaultEye:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("CENTER")
    
    local w = elem.widgetWidth or 250
    local h = elem.widgetHeight or 150
    container:SetSize(w, h)
    
    if Skin and Skin.ApplyBackdrop then
        Skin:ApplyBackdrop(container)
        container:SetBackdropColor(unpack(elem.bgColor or {0.05, 0.05, 0.05, 0.8}))
        container:SetBackdropBorderColor(unpack(Skin.Colors.border or {0.2, 0.2, 0.2, 1}))
    end

    -- State Data
    container.vaultData = {
        mythic = { slots = {}, unlocked = 0 },
        delves = { slots = {}, unlocked = 0 },
        raid = { slots = {}, unlocked = 0 }
    }
    container.currencyData = {}
    
    -- Compact Mode Elements
    container.compactView = CreateFrame("Frame", nil, container)
    container.compactView:SetAllPoints()
    
    local fontNormal = (Skin and Skin.Constants and Skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
    
    container.title = container.compactView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.title:SetPoint("TOP", 0, -10)
    container.title:SetFont(fontNormal, 14, "OUTLINE")
    container.title:SetText("|cffffcc00VaultEye|r")
    
    container.summaryText = container.compactView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.summaryText:SetPoint("CENTER", 0, -5)
    container.summaryText:SetFont(fontNormal, 12, "OUTLINE")
    container.summaryText:SetJustifyH("CENTER")

    -- Expanded Mode Elements
    container.expandedView = CreateFrame("Frame", nil, container)
    container.expandedView:SetAllPoints()
    container.expandedView:Hide()
    
    -- Scrollable content host for expanded view
    container.expandedContent = CreateFrame("Frame", nil, container.expandedView)
    container.expandedContent:SetPoint("TOPLEFT", 10, -30)
    container.expandedContent:SetPoint("BOTTOMRIGHT", -10, 10)
    
    container.accordions = {} -- Store accordion references
    
    -- Ensure the default text reflects empty state if data load fails initially
    container.summaryText:SetText("Loading Vault Data...")
    
    -- Hover Detection Overlay (Fixes blinking issue when moving mouse over child accordions)
    if elem.hoverExpand then
        local hoverFrame = CreateFrame("Frame", nil, container)
        hoverFrame:SetAllPoints()
        hoverFrame:SetHitRectInsets(-10, -10, -10, -10) -- Give a small buffer zone
        hoverFrame:SetFrameLevel(container.expandedView:GetFrameLevel() + 50) -- Ensure it sits above the accordions
        hoverFrame:EnableMouse(true)
        -- We propagate clicks so you can still click accordions
        hoverFrame:SetPropagateKeyboardInput(true)
        
        -- Hook mouse enter
        hoverFrame:SetScript("OnEnter", function(self)
            self:SetFrameLevel(container:GetFrameLevel() - 1) -- Drop behind children while expanded so clicks work
            container.compactView:Hide()
            container.expandedView:Show()
            VaultEye:UpdateDisplay(container, elem, true)
        end)
        
        -- Hook an update loop to check if mouse actually left the overall bounding box of the whole widget
        local leftCheckTimer = 0
        container:SetScript("OnUpdate", function(self, elapsed)
            if container.expandedView:IsShown() then
                leftCheckTimer = leftCheckTimer + elapsed
                if leftCheckTimer > 0.1 then
                    leftCheckTimer = 0
                    local isOver = hoverFrame:IsMouseOver(10, -10, -10, 10) or container.expandedView:IsMouseOver(10, -10, -10, 10)
                    if not isOver then
                        container.expandedView:Hide()
                        container.compactView:Show()
                        hoverFrame:SetFrameLevel(container.expandedView:GetFrameLevel() + 50) -- Rise to catch hover again
                        VaultEye:UpdateDisplay(container, elem, false)
                    end
                end
            end
        end)
    end
    
    -- Update Loop Callbacks
    container:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    container:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    container:RegisterEvent("PLAYER_ENTERING_WORLD")
    container:SetScript("OnEvent", function(self, event, ...)
        VaultEye:FetchData(self)
        VaultEye:UpdateDisplay(self, elem, self.expandedView:IsShown())
    end)
    
    -- Initial Fetch
    C_Timer.After(1, function()
        VaultEye:FetchData(container)
        VaultEye:UpdateDisplay(container, elem, false)
    end)
    
    return container
end

function VaultEye:Refresh(container, elem)
    container:SetSize(elem.widgetWidth or 250, elem.widgetHeight or 150)
    VaultEye:FetchData(container)
    VaultEye:UpdateDisplay(container, elem, container.expandedView:IsShown())
end

-- ============================================================================
-- Data Fetching
-- ============================================================================
local VAULT_ACTIVITIES = {
    [1] = "mythic",   -- Mythic (formerly Dungeons)
    [2] = "pvp",      -- Ranked PvP (Deprecated)
    [3] = "raid",     -- Raid
    [4] = "delves"    -- World/Delves
}


function VaultEye:FetchData(container)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return end

    local activities = C_WeeklyRewards.GetActivities()
    
    -- Reset state
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
    else
        -- Fallback empty state
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
                -- Clean up excessively long names
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
end

-- ============================================================================
-- Rendering
-- ============================================================================
function VaultEye:UpdateDisplay(container, elem, isExpanded)
    local data = container.vaultData
    
    if not isExpanded then
        -- COMPACT VIEW
        local lines = {}
        
        if elem.trackMythicPlus ~= false then
            local color = (data.mythic.unlocked == 3) and "|cff00ff00" or "|cffffffff"
            table.insert(lines, string.format("Mythic+: %s%d/3|r", color, data.mythic.unlocked))
        end
        if elem.trackDelves ~= false then
            local color = (data.delves.unlocked == 3) and "|cff00ff00" or "|cffffffff"
            table.insert(lines, string.format("Delves/World: %s%d/3|r", color, data.delves.unlocked))
        end
        if elem.trackRaid ~= false then
            local color = (data.raid.unlocked == 3) and "|cff00ff00" or "|cffffffff"
            table.insert(lines, string.format("Raid: %s%d/3|r", color, data.raid.unlocked))
        end
        if #lines == 0 then
            table.insert(lines, "|cffaaaaaaNo tracked Vault activities|r")
        end
        
        container.summaryText:SetText(table.concat(lines, "\n"))
    else
        -- EXPANDED VIEW: Accordion Style
        -- Hide the text display if it still somehow exists (we removed detailsText above)
        
        -- Helper to rebuild y-positions of all accordions dynamically
        local activeAccordions = {}
        
        local function UpdateLayout()
            local currentY = 0
            local PADDING = 5
            for _, acc in ipairs(activeAccordions) do
                if acc:IsShown() then
                    acc:ClearAllPoints()
                    acc:SetPoint("TOPLEFT", container.expandedContent, "TOPLEFT", 0, currentY)
                    acc:SetPoint("TOPRIGHT", container.expandedContent, "TOPRIGHT", 0, currentY)
                    currentY = currentY - acc:GetHeight() - PADDING
                end
            end
            container.expandedContent:SetHeight(math.abs(currentY))
            container.expandedView:SetHeight(math.abs(currentY) + 40)
        end
        
        -- Helper to create or get an accordion
        local function GetOrCreateAccordion(key, title, parent)
            if not container.accordions[key] then
                -- Add a callback to close others on expand
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
                
                container.accordions[key] = ForgeSkin:CreateAccordion(parent, title, 220, onAccToggle)
                container.accordions[key].onAnimUpdate = UpdateLayout -- Hook into ForgeSkin animation Loop
                container.accordions[key].content:Hide()
                container.accordions[key].isExpanded = false
                container.accordions[key].header.arrow:SetTexCoord(0, 1, 0, 1) -- Keep arrow state generic
            end
            local acc = container.accordions[key]
            acc:Show()
            table.insert(activeAccordions, acc)
            return acc
        end
        
        -- Helper to create or get a row inside an accordion
        local function GetOrCreateRow(acc, rowIndex)
            acc.rows = acc.rows or {}
            if not acc.rows[rowIndex] then
                local row = CreateFrame("Frame", nil, acc.content)
                row:SetSize(200, 20)
                
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.label:SetPoint("LEFT", 5, 0)
                row.label:SetJustifyH("LEFT")
                
                row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.value:SetPoint("RIGHT", -5, 0)
                row.value:SetJustifyH("RIGHT")
                
                acc.rows[rowIndex] = row
            end
            local r = acc.rows[rowIndex]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", acc.content, "TOPLEFT", 0, -(rowIndex - 1) * 22)
            r:SetPoint("TOPRIGHT", acc.content, "TOPRIGHT", 0, -(rowIndex - 1) * 22)
            r:Show()
            return r
        end

        local currentY = 0
        local PADDING = 5
        
        -- Hide all accordions initially to reset state
        for _, acc in pairs(container.accordions) do
            acc:Hide()
            if acc.rows then
                for _, r in ipairs(acc.rows) do r:Hide() end
            end
        end

        -- Build Activities
        local function BuildActivitySection(key, title, groupData, isEnabled)
            if not isEnabled or not groupData.slots or #groupData.slots == 0 then return end
            
            local acc = GetOrCreateAccordion(key, title, container.expandedContent)
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
            
            -- Size accordion content
            local contentHeight = #slots * 22
            acc.content:SetHeight(contentHeight)
            acc:SetHeight(24 + (acc.isExpanded and contentHeight or 0))
        end

        BuildActivitySection("mythic", "Mythic+ Dungeons", data.mythic, elem.trackMythicPlus ~= false)
        BuildActivitySection("delves", "Delves & World", data.delves, elem.trackDelves ~= false)
        BuildActivitySection("raid", "Raid Bosses", data.raid, elem.trackRaid ~= false)
        
        -- Build Currencies
        if elem.trackCurrencies ~= false and container.currencyData and #container.currencyData > 0 then
            local acc = GetOrCreateAccordion("currencies", "Currencies", container.expandedContent)
            
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
            
            local contentHeight = #container.currencyData * 22
            acc.content:SetHeight(contentHeight)
            acc:SetHeight(24 + (acc.isExpanded and contentHeight or 0))
        end
        
        -- Force initial layout once all elements are created
        UpdateLayout()
    end
end

-- Settings Registration
function VaultEye:CreateSettings(panel)
    local sb = panel.builder
    if not sb then
        sb = _G.WidgetForgeUtils:CreateSettingsBuilder(panel.content)
        panel.builder = sb
    end
    
    local config = panel.config
    local barIndex = panel.barIndex
    
    sb:AddHeader("VaultEye - Display Modules")
    sb:AddCheckbox("trackMythicPlus", "Track Mythic+ Dungeons", true, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    sb:AddCheckbox("trackDelves", "Track Delves & World", true, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    sb:AddCheckbox("trackRaid", "Track Raid Bosses", true, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    sb:AddCheckbox("trackCurrencies", "Track Upgrade Materials (Crests)", true, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    
    sb:AddHeader("VaultEye - Behavior")
    sb:AddCheckbox("hoverExpand", "Expand on Hover", true, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    
    sb:AddHeader("Widget Dimensions")
    sb:AddSlider("widgetWidth", "Width", 150, 400, 5, 250, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    sb:AddSlider("widgetHeight", "Height", 100, 300, 5, 150, config, function() _G.WidgetForge:RebuildBarComponents(barIndex) end)
    
    sb:Finish()
end

return VaultEye
