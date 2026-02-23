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
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("CENTER")
    
    local w = elem.widgetWidth or 250
    local h = elem.widgetHeight or 150
    container:SetSize(w, h)

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

    -- Expanded Mode Elements (Popout Dropdown Style to Prevent UI Overflow)
    container.expandedView = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.expandedView:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.expandedView:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    container.expandedView:SetHeight(150)
    container.expandedView:SetFrameStrata("TOOLTIP") -- Pop over other elements unconditionally
    ForgeSkin:ApplyBackdrop(container.expandedView, 0.95, 1) -- Opaque dark background
    container.expandedView:Hide()
    -- Adaptive content host for expanded view (No main scrollbar, grows with children)
    container.sfWidth = (elem.widgetWidth or 250) - 20
    container.expandedContent = CreateFrame("Frame", nil, container.expandedView)
    container.expandedContent:SetSize(container.sfWidth, 120)
    container.expandedContent:SetPoint("TOP", 0, -15)
    
    container.accordions = {} -- Store accordion references
    
    -- Ensure the default text reflects empty state if data load fails initially
    container.summaryText:SetText("Loading Vault Data...")
    
    -- Hover Detection Overlay (Fixes blinking issue when moving mouse over child accordions)
    if elem.hoverExpand then
        local hoverFrame = CreateFrame("Frame", nil, container)
        hoverFrame:SetAllPoints()
        hoverFrame:SetHitRectInsets(-10, -10, -10, -10) -- Give a small buffer zone
        hoverFrame:SetFrameStrata("TOOLTIP")
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
    container:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    container:RegisterEvent("BOSS_KILL")
    container:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    container:SetScript("OnEvent", function(self, event, ...)
        -- Force a fresh read on critical events that signal a run finish
        if event == "WEEKLY_REWARDS_UPDATE" or event == "CHALLENGE_MODE_COMPLETED" or event == "BOSS_KILL" or event == "ZONE_CHANGED_NEW_AREA" then
            self.lastFetchTime = 0
        end
        VaultEye:FetchData(self)
        VaultEye:UpdateDisplay(self, elem, self.expandedView:IsShown())
    end)
    
    -- Initial Fetch
    C_Timer.After(1, function()
        container.lastFetchTime = 0
        VaultEye:FetchData(container)
        VaultEye:UpdateDisplay(container, elem, false)
    end)
    
    return container
end

function VaultEye:Refresh(container, elem)
    container:SetSize(elem.widgetWidth or 250, elem.widgetHeight or 150)
    
    container.sfWidth = (elem.widgetWidth or 250) - 20
    if container.expandedContent then
        container.expandedContent:SetWidth(container.sfWidth)
    end
    
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
    
    -- Cache check: Don't read raw data more than once every 10 seconds to prevent API spam
    if container.lastFetchTime and (GetTime() - container.lastFetchTime < 10) then
        return
    end

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
    
    container.lastFetchTime = GetTime()
end

-- ============================================================================
-- Rendering
-- ============================================================================
function VaultEye:UpdateDisplay(container, elem, isExpanded)
    local data = container.vaultData
    
    -- Force hide WidgetForge's global backdrop manually just in case the type string check fails
    local rootParent = container:GetParent()
    if rootParent and rootParent.SetBackdrop then
        rootParent:SetBackdrop(nil)
        rootParent:SetBackdropColor(0,0,0,0)
        rootParent:SetBackdropBorderColor(0,0,0,0)
    end
    
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
            local totalHeight = math.abs(currentY)
            container.expandedContent:SetHeight(totalHeight)
            container.expandedView:SetHeight(totalHeight + 30) -- exactly 15px top offset + 15px bottom padding
        end
        
        -- Helper to create or get an accordion
        local function GetOrCreateAccordion(key, title, parent, useScroll)
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
                container.accordions[key] = ForgeSkin:CreateAccordion(parent, title, 200, onAccToggle, container.sfWidth)
                container.accordions[key].onAnimUpdate = UpdateLayout -- Hook into ForgeSkin animation Loop
                container.accordions[key].content:Hide()
                container.accordions[key].isExpanded = false
                container.accordions[key].header.arrow:SetTexCoord(0, 1, 0, 1) -- Keep arrow state generic
                
                local scrollTarget = container.accordions[key].content
                
                if useScroll then
                    -- Replace standard content frame with a ScrollFrame to limit expansion height
                    local accScroll, accChild = ForgeSkin:CreateScrollFrame(scrollTarget, container.sfWidth - 10, 100)
                    accScroll:SetPoint("TOPLEFT", 2, -2)
                    accScroll:SetPoint("BOTTOMRIGHT", -2, 2)
                    
                    container.accordions[key].scrollFrame = accScroll
                    container.accordions[key].scrollChild = accChild
                else
                    container.accordions[key].scrollChild = scrollTarget
                end
                
                -- Add a subtle border to the content area for better visual separation
                ForgeSkin:ApplyBackdrop(scrollTarget, 0.1, 0.5)
                scrollTarget:SetBackdropColor(0, 0, 0, 0.3)
                scrollTarget:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            end
            local acc = container.accordions[key]
            acc:Show()
            table.insert(activeAccordions, acc)
            return acc
        end
        
        -- Helper to create or get a row inside an accordion
        local function GetOrCreateRow(acc, rowIndex)
            acc.rows = acc.rows or {}
            
            -- We put the rows inside the scrollChild, not the base content frame
            local parentFrame = acc.scrollChild or acc.content
            
            if not acc.rows[rowIndex] then
                local row = CreateFrame("Frame", nil, parentFrame)
                row:SetSize(container.sfWidth - 10, 20)
                
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.label:SetPoint("LEFT", 5, 0)
                row.label:SetJustifyH("LEFT")
                
                row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.value:SetPoint("RIGHT", -25, 0) -- Moved 5px away from potential scrollbars
                row.value:SetJustifyH("RIGHT")
                
                acc.rows[rowIndex] = row
            end
            local r = acc.rows[rowIndex]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -(rowIndex - 1) * 22)
            r:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, -(rowIndex - 1) * 22)
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
            
            local acc = GetOrCreateAccordion(key, title, container.expandedContent, false)
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
            
            -- Size accordion content. Cap the physical size to ~106px (10% more than 97)
            local rawHeight = #slots * 22
            local boundedHeight = math.min(rawHeight, 106)
            
            if acc.scrollChild then
                acc.scrollChild:SetHeight(rawHeight)
                acc.scrollChild:SetWidth(container.sfWidth - 10)
            end
            
            -- Use the library's proper sizing API instead of manually mutating frame height
            acc:SetContentHeight(boundedHeight)
        end

        BuildActivitySection("mythic", "Mythic+ Dungeons", data.mythic, elem.trackMythicPlus ~= false)
        BuildActivitySection("delves", "Delves & World", data.delves, elem.trackDelves ~= false)
        BuildActivitySection("raid", "Raid Bosses", data.raid, elem.trackRaid ~= false)
        
        -- Build Currencies
        if elem.trackCurrencies ~= false and container.currencyData and #container.currencyData > 0 then
            local acc = GetOrCreateAccordion("currencies", "Currencies", container.expandedContent, true)
            
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
            
            -- Cap currency height since there are usually many
            local rawHeight = #container.currencyData * 22
            local boundedHeight = math.min(rawHeight, 133) -- 10% more than 121
            
            if acc.scrollChild then
                acc.scrollChild:SetHeight(rawHeight)
                acc.scrollChild:SetWidth(container.sfWidth - 10)
            end
            
            -- Use the library's proper sizing API instead of manually mutating frame height
            acc:SetContentHeight(boundedHeight)
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
