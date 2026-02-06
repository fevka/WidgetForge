ForgeStats = {}
local Stats = ForgeStats

-- State variables
Stats.SessionStartMoney = GetMoney()

-- Helper for Money String
local function GetMoneyString(copper)
    return GetCoinTextureString(copper)
end

-- --- STAT LOGIC ---
-- Returns: ValueString, LabelString (optional), IconPath (optional, unused internal lookup mostly)
function Stats:GetStat(statType)
    if statType == "FPS" then return floor(GetFramerate()), "FPS" end
    if statType == "MS" then local _, _, _, lat = GetNetStats(); return lat, "MS" end
    if statType == "Clock" then return date("%H:%M"), "" end -- Format handled in WidgetForge for customization
    if statType == "RAM" then 
        local mem = collectgarbage("count")
        if mem > 1024 then return string.format("%.1f", mem/1024), "MB" else return floor(mem), "KB" end
    end
    if statType == "Durability" then
        local cur, max = 0, 0
        for i = 1, 18 do
            local c, m = GetInventoryItemDurability(i)
            if c and m then cur = cur + c; max = max + m end
        end
        if max == 0 then return "100%", "D" end
        return floor((cur/max)*100).."%", "D"
    end
    if statType == "Bag Space" or statType == "BagSpace" then
        local free, total = 0, 0
        for i = 0, NUM_BAG_SLOTS do
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + C_Container.GetContainerNumSlots(i)
        end
        return free .. "/" .. total, "Bag"
    end

    -- Economy & Nav
    if statType == "Gold" then return GetMoneyString(GetMoney()), "" end
    if statType == "Zone" then return GetMinimapZoneText() or "", "" end
    if statType == "Coords" then 
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos and pos.x and pos.y then 
                return string.format("%.1f, %.1f", pos.x*100, pos.y*100), "" 
            end
        end
        return "0, 0", ""
    end
    if statType == "Item Level" or statType == "ItemLevel" then local _, avg = GetAverageItemLevel(); return floor(avg), "ilvl" end
    
    -- Progression
    if statType == "XP" then
        if UnitLevel("player") == GetMaxPlayerLevel() then return "Max", "" end
        local curr, max = UnitXP("player"), UnitXPMax("player")
        return string.format("%.1f%%", (curr/max)*100), "XP"
    end
    
    -- Combat Timer
    if statType == "Combat Timer" or statType == "CombatTimer" then
        if UnitAffectingCombat("player") then
            if not Stats.CombatStart then Stats.CombatStart = GetTime() end
            local t = GetTime() - Stats.CombatStart
            local m = floor(t/60)
            local s = floor(t%60)
            return string.format("|cffff0000%02d:%02d|r", m, s), ""
        else
            return "00:00", ""
        end
    end

    -- Primary, Secondary, Tertiary... (Unchanged logic, just ensure return exists)
    if statType == "Strength" then local _, val = UnitStat("player", 1); return val, "Str" end
    if statType == "Agility" then local _, val = UnitStat("player", 2); return val, "Agi" end
    if statType == "Intellect" then local _, val = UnitStat("player", 3); return val, "Int" end
    if statType == "Stamina" then local _, val = UnitStat("player", 4); return val, "Sta" end
    if statType == "Crit" then return string.format("%.1f%%", GetCritChance()), "Crit" end
    if statType == "Haste" then return string.format("%.1f%%", GetHaste()), "Haste" end
    if statType == "Mastery" then return string.format("%.1f%%", GetMasteryEffect()), "Mastery" end
    if statType == "Versatility" then return string.format("%.1f%%", GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)), "Vers" end
    if statType == "Avoidance" then return string.format("%.1f%%", GetAvoidance()), "Avoid" end
    if statType == "Leech" then return string.format("%.1f%%", GetLifesteal()), "Leech" end
    if statType == "Speed" then return string.format("%.1f%%", GetUnitSpeed("player") / 7 * 100), "Spd" end
    if statType == "Dodge" then return string.format("%.1f%%", GetDodgeChance()), "Dodge" end
    if statType == "Parry" then return string.format("%.1f%%", GetParryChance()), "Parry" end
    
    return "", ""
end

-- --- TOOLTIP LOGIC ---
function Stats:AddTooltip(owner, statType, elemData)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR") -- Changed to Cursor for better visibility or stick to Anchor? Let's use ANCHOR_CURSOR or ANCHOR_TOP.
    -- Actually ANCHOR_TOP relative to the frame is better for bars.
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local added = false
    
    if statType == "Zone" or statType == "Coords" then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo(mapID)
            GameTooltip:AddLine(info and info.name or "Unknown Zone", 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            -- Coords
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                GameTooltip:AddDoubleLine("Coordinates:", string.format("%.1f, %.1f", pos.x*100, pos.y*100), 1,0.8,0, 1,1,1)
            end
            
            -- PVP Info
            local pvpType, _, factionName = GetZonePVPInfo()
            local pvpText = ""
            if pvpType == "sanctuary" then pvpText = "|cff00ff00Sanctuary|r"
            elseif pvpType == "arena" then pvpText = "|cffff0000Arena|r"
            elseif pvpType == "friendly" then pvpText = "|cff00ff00Friendly|r"
            elseif pvpType == "hostile" then pvpText = "|cffff0000Hostile|r"
            elseif pvpType == "contested" then pvpText = "|cffffaa00Contested|r"
            else pvpText = pvpType or "Normal" end
            
            GameTooltip:AddDoubleLine("PVP Status:", pvpText, 1,0.8,0, 1,1,1)
            added = true
        end
    end
    
    if statType == "Gold" then
        GameTooltip:AddLine("Economy", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local current = GetMoney()
        local start = Stats.SessionStartMoney or current
        local diff = current - start
        
        GameTooltip:AddDoubleLine("Current:", GetMoneyString(current), 1,0.8,0, 1,1,1)
        GameTooltip:AddDoubleLine("Session Start:", GetMoneyString(start), 1,0.8,0, 1,1,1)
        
        local diffColor = (diff >= 0) and {0,1,0} or {1,0,0}
        GameTooltip:AddDoubleLine("Session Profit:", GetMoneyString(abs(diff)), 1,0.8,0, diffColor[1], diffColor[2], diffColor[3])
        added = true
    end
    
    if statType == "System" or statType == "RAM" or statType == "FPS" or statType == "MS" then
        GameTooltip:AddLine("System Performance", 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        -- Latency
        local _, _, diffHome, diffWorld = GetNetStats()
        GameTooltip:AddDoubleLine("Home Latency:", diffHome.." ms", 1,0.8,0, 1,1,1)
        GameTooltip:AddDoubleLine("World Latency:", diffWorld.." ms", 1,0.8,0, 1,1,1)
        GameTooltip:AddLine(" ")
        
        -- Top Addons
        UpdateAddOnMemoryUsage()
        local addons = {}
        for i=1, C_AddOns.GetNumAddOns() do
            if C_AddOns.IsAddOnLoaded(i) then
                local mem = GetAddOnMemoryUsage(i)
                table.insert(addons, {name = C_AddOns.GetAddOnInfo(i), mem = mem})
            end
        end
        table.sort(addons, function(a,b) return a.mem > b.mem end)
        
        GameTooltip:AddLine("Top 5 Addons (Memory):")
        for i=1, math.min(5, #addons) do
            local memStr = ""
            if addons[i].mem > 1000 then memStr = string.format("%.1f MB", addons[i].mem/1000)
            else memStr = string.format("%.0f KB", addons[i].mem) end
            GameTooltip:AddDoubleLine(i..". "..addons[i].name, memStr, 1,1,1, 1,0.8,0)
        end
        
        -- Garbage Collection
        local totalMem = collectgarbage("count")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Memory:", string.format("%.1f MB", totalMem/1024), 1,0.8,0, 0,1,0)
        added = true
    end -- Close System Block Properly

    if statType == "Durability" then
        GameTooltip:AddLine("Durability Status", 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        local totalCost = 0
        local damagedItems = false
        
        for i = 1, 18 do
            local cur, max = GetInventoryItemDurability(i)
            if cur and max and cur < max then
                local link = GetInventoryItemLink("player", i)
                local pct = floor((cur/max)*100)
                if link then
                     local r, g, b = 0, 1, 0
                     if pct < 50 then r,g,b = 1, 0, 0 elseif pct < 80 then r,g,b = 1, 1, 0 end
                     GameTooltip:AddDoubleLine(link, pct.."%", 1,1,1, r,g,b)
                     damagedItems = true
                end
            end
            
            -- Repair cost
            local hasItem, _, cost = C_TooltipInfo.GetInventoryItem("player", i)
            if hasItem and cost then totalCost = totalCost + cost end
        end
        
        if not damagedItems then
            GameTooltip:AddLine("All items are fully repaired.", 0, 1, 0)
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Repair Cost:", GetMoneyString(totalCost), 1,0.8,0, 1,1,1)
        end
        added = true
    end
    
    if statType == "Bag Space" or statType == "BagSpace" then
        GameTooltip:AddLine("Bag Usage", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local totalFree, totalSlots = 0, 0
        for i = 0, NUM_BAG_SLOTS do
            local free = C_Container.GetContainerNumFreeSlots(i)
            local total = C_Container.GetContainerNumSlots(i)
            local name = (i==0) and "Backpack" or ("Bag " .. i)
            if total > 0 then
                 GameTooltip:AddDoubleLine(name, free.." / "..total, 1,1,1, 1,0.8,0)
                 totalFree = totalFree + free
                 totalSlots = totalSlots + total
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Free:", totalFree.." / "..totalSlots, 1,0.8,0, 0,1,0)
        added = true
    end
    
    if statType == "Clock" then
        GameTooltip:AddLine("Time Info", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Server Time:", date("%H:%M:%S"), 1,1,1, 1,0.8,0)
        GameTooltip:AddDoubleLine("Local Time:", date("%H:%M:%S", time()), 1,1,1, 1,0.8,0)
        
        -- Date
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Date:", date("%A, %B %d, %Y"), 1,0.8,0, 1,1,1)
        added = true
    end
    
    if statType == "XP" then
       GameTooltip:AddLine("Experience", 1, 1, 1)
       local curr, max = UnitXP("player"), UnitXPMax("player")
       local rested = GetXPExhaustion() or 0
       
       GameTooltip:AddDoubleLine("Current:", BreakUpLargeNumbers(curr).." / "..BreakUpLargeNumbers(max), 1,1,1, 1,1,1)
       GameTooltip:AddDoubleLine("Remaining:", BreakUpLargeNumbers(max-curr), 1,1,1, 1,0.8,0)
       
       if rested > 0 then
           GameTooltip:AddDoubleLine("Rested:", BreakUpLargeNumbers(rested), 1,1,1, 0,1,0)
           GameTooltip:AddDoubleLine("Rested %:", string.format("%.1f%%", (rested/max)*100), 1,1,1, 0,1,0)
       end
       added = true
    end

    if not added then
        -- Default Tooltip
        GameTooltip:AddLine(statType, 1, 1, 1)
        -- Could add description maps later
    end

    GameTooltip:Show()
end
