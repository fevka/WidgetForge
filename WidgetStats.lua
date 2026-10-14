ForgeStats = {}
local Stats = ForgeStats
Stats.Data = {
    ["FPS"] = "0", ["MS"] = "0", ["Clock"] = "00:00", ["RAM"] = "0MB",
    ["Gold"] = "0g", ["Zone"] = "Unknown", ["Coords"] = "0, 0",
    ["Durability"] = "100%", ["Bag Space"] = "0/0",
    ["Item Level"] = "0", ["XP"] = "0%", ["Combat Timer"] = "00:00",
    ["Strength"] = "0", ["Agility"] = "0", ["Intellect"] = "0",
    ["Stamina"] = "0", ["Crit"] = "0%", ["Haste"] = "0%",
    ["Mastery"] = "0%", ["Versatility"] = "0%", ["Avoidance"] = "0%",
    ["Leech"] = "0%", ["Speed"] = "0%", ["Run Speed"] = "0%", ["Dodge"] = "0%", ["Parry"] = "0%",
    ["Main Stat"] = "0", ["Armor"] = "0", ["Max HP"] = "0",
    ["DragonVigor"] = 0, ["DragonVigorMax"] = 0, ["DragonSpeed"] = 0, ["DragonActive"] = false,
    ["Guild"] = "0", ["Friends"] = "0",
    ["Difficulty"] = "World",
    ["Talent Loadout"] = "Default", 
    ["Talent Loadout Icon"] = 132222
}
Stats.ActiveMainStat = "Strength" 
Stats.CombatStart = nil
local function SafeGetCoinTextureString(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    elseif _G.GetCoinTextureString then
        return _G.GetCoinTextureString(copper)
    end
    local gold = math.floor((copper or 0) / 10000)
    local silver = math.floor(((copper or 0) % 10000) / 100)
    local copperOnly = (copper or 0) % 100
    return string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t", gold, silver, copperOnly)
end

if not _G.GetCoinTextureString then
    _G.GetCoinTextureString = SafeGetCoinTextureString
end

local function GetMoneyString(copper, separatorStyle)
    copper = tonumber(copper) or 0
    if separatorStyle then
        local sep = ","
        if separatorStyle == "DOT" then
            sep = "."
        elseif separatorStyle == "SPACE" then
            sep = " "
        elseif separatorStyle == "NONE" then
            sep = ""
        end
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        local copperOnly = copper % 100
        local goldText = tostring(gold)
        if sep ~= "" then
            while true do
                local k
                goldText, k = string.gsub(goldText, "^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
                if k == 0 then break end
            end
        end
        return string.format("%sg %02ds %02dc", goldText, silver, copperOnly)
    end
    return SafeGetCoinTextureString(copper)
end
local function GetCurrentCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return (name .. "-" .. realm), name, realm
end
function Stats:PersistCurrentCharacterGold()
    if not WidgetForgeDB then return end
    if type(WidgetForgeDB.goldCache) ~= "table" then
        WidgetForgeDB.goldCache = {}
    end
    local key, name, realm = GetCurrentCharacterKey()
    WidgetForgeDB.goldCache[key] = {
        name = name,
        realm = realm,
        money = GetMoney() or 0,
        updatedAt = time(),
    }
end
function Stats:Initialize()
    if self.Initialized then return end
    Stats.SessionStartMoney = GetMoney()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_MONEY")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    f:RegisterEvent("UPDATE_INSTANCE_INFO")
    f:RegisterEvent("UNIT_STATS")
    f:RegisterEvent("UNIT_AURA") 
    f:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:RegisterEvent("FRIENDLIST_UPDATE")
    f:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    f:SetScript("OnEvent", function(self, event, ...)
        Stats:UpdateEventStat(event, ...)
    end)
    self.EventFrame = f
    self.Initialized = true
    self:UpdateSpecInfo()
    self:UpdateAllStats()
end
function Stats:UpdateSpecInfo()
    local specIndex = GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        if specID and WIDGETFORGE_SPECS[specID] then
            Stats.ActiveMainStat = WIDGETFORGE_SPECS[specID]
        else
            local _, classFilename = UnitClassBase("player")
            Stats.ActiveMainStat = WIDGETFORGE_CLASS_DEFAULTS[classFilename] or "Strength"
        end
    else
        local _, classFilename = UnitClassBase("player")
        Stats.ActiveMainStat = WIDGETFORGE_CLASS_DEFAULTS[classFilename] or "Strength"
    end
end
function Stats:UpdatePolledStats(elapsed)
    Stats.Data["FPS"] = floor(GetFramerate())
    local _, _, _, lat = GetNetStats()
    Stats.Data["MS"] = lat
    Stats.Data["Clock"] = date("%H:%M")
    local mem = collectgarbage("count")
    if mem > 1024 then Stats.Data["RAM"] = string.format("%.1f", mem/1024)
    else Stats.Data["RAM"] = tostring(floor(mem)) end
    if UnitAffectingCombat("player") then
        if not Stats.CombatStart then Stats.CombatStart = GetTime() end
        local t = GetTime() - Stats.CombatStart
        local m = floor(t/60)
        local s = floor(t%60)
        Stats.Data["Combat Timer"] = string.format("|cffff0000%02d:%02d|r", m, s)
    else
        Stats.Data["Combat Timer"] = "00:00"
    end
    local ok_speed, speed_result = pcall(function()
        local unitSpeed = GetUnitSpeed("player")
        if unitSpeed and unitSpeed > 0 then
            return string.format("%.0f%%", (unitSpeed / 7) * 100)
        end
        return "0%"
    end)
    Stats.Data["Run Speed"] = ok_speed and speed_result or "0%"
    local vigorData = C_Spell.GetSpellCharges(372608)
    if vigorData then
        local current = vigorData.currentCharges or 0
        local max = vigorData.maxCharges or 6
        local fractional = 0
        local now = GetTime()
        if vigorData.cooldownStartTime and vigorData.cooldownDuration and vigorData.cooldownDuration > 0 then
            fractional = (now - vigorData.cooldownStartTime) / vigorData.cooldownDuration
            if fractional < 0 then fractional = 0 end
            if fractional > 1 then fractional = 1 end
        end
        if current < max then
             Stats.Data["DragonVigor"] = current + fractional
        else
             Stats.Data["DragonVigor"] = current
        end
        Stats.Data["DragonVigorMax"] = max
    else
        Stats.Data["DragonVigor"] = 0
        Stats.Data["DragonVigorMax"] = 0
    end
    local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    Stats.Data["DragonSpeed"] = forwardSpeed or 0
    Stats.Data["DragonActive"] = (GetBonusBarIndex() == 11)
    local loadoutName = nil
    local loadoutIcon = nil
    local playerKey = UnitName("player") .. "-" .. GetRealmName()
    if WidgetForgeDB and not WidgetForgeDB.talentCache then WidgetForgeDB.talentCache = {} end
    if _G.TLX and _G.TLX.GetLoadedData then
        local success, tlxData = pcall(_G.TLX.GetLoadedData)
        if success and type(tlxData) == "table" then
            loadoutName = tlxData.name
            loadoutIcon = tlxData.icon
            if WidgetForgeDB then
                if loadoutName and loadoutName ~= "" then
                    WidgetForgeDB.talentCache[playerKey] = {
                        name = loadoutName,
                        icon = loadoutIcon
                    }
                else
                    WidgetForgeDB.talentCache[playerKey] = nil
                end
            end
        end
    end
    if (not loadoutName or loadoutName == "") and WidgetForgeDB and WidgetForgeDB.talentCache and WidgetForgeDB.talentCache[playerKey] then
        loadoutName = WidgetForgeDB.talentCache[playerKey].name
        loadoutIcon = WidgetForgeDB.talentCache[playerKey].icon
    end
    if not loadoutName or loadoutName == "" then
        if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
            local configID = C_ClassTalents.GetActiveConfigID()
            if configID then
                local info = C_Traits.GetConfigInfo(configID)
                if info and info.name and info.name ~= "" then
                    loadoutName = info.name
                else
                    loadoutName = "Default"
                end
            end
        end
    end
    if not loadoutIcon then
        local specIndex = GetSpecialization()
        if specIndex then
            local _, _, _, specIcon = GetSpecializationInfo(specIndex)
            loadoutIcon = specIcon
        end
    end
    Stats.Data["Talent Loadout"] = loadoutName or "Unknown"
    Stats.Data["Talent Loadout Icon"] = loadoutIcon or 132222
end
function Stats:UpdateEventStat(event, arg1)
    if event == "PLAYER_MONEY" or event == "PLAYER_ENTERING_WORLD" then
        Stats.Data["Gold"] = GetMoneyString(GetMoney())
        self:PersistCurrentCharacterGold()
    end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
        Stats.Data["Zone"] = GetMinimapZoneText() or ""
    end
    if event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local free, total = 0, 0
        for i = 0, 5 do
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + C_Container.GetContainerNumSlots(i)
        end
        local used = total - free
        Stats.Data["Bag Space"] = used .. "/" .. total
    end
    if event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_ENTERING_WORLD" then
        local cur, max = 0, 0
        for i = 1, 18 do
            local c, m = GetInventoryItemDurability(i)
            if c and m then cur = cur + c; max = max + m end
        end
        if max == 0 then Stats.Data["Durability"] = "100%"
        else Stats.Data["Durability"] = floor((cur/max)*100).."%" end
    end
    if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
        if UnitLevel("player") == GetMaxPlayerLevel() then 
            Stats.Data["XP"] = "Max"
        else
            local curr, max = UnitXP("player"), UnitXPMax("player")
            if max and max > 0 then
                Stats.Data["XP"] = string.format("%.1f%%", (curr/max)*100)
            else
                Stats.Data["XP"] = "0%"
            end
        end
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        local _, avg = GetAverageItemLevel()
        Stats.Data["Item Level"] = floor(avg or 0)
        Stats:UpdateEventStat("UPDATE_INVENTORY_DURABILITY")
        self:UpdateCharacterStats()
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        self:UpdateSpecInfo()
        self:UpdateCharacterStats()
    end
    if event == "UNIT_STATS" or event == "UNIT_AURA" or event == "PLAYER_DAMAGE_DONE_MODS" or event == "PLAYER_ENTERING_WORLD" then
        if not arg1 or arg1 == "player" then
            self:UpdateCharacterStats()
        end
    end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" then
        local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
        if name and difficultyName and difficultyName ~= "" and instanceType ~= "none" then
            Stats.Data["Difficulty"] = difficultyName
        else
            Stats.Data["Difficulty"] = "World"
        end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if IsInGuild() then C_GuildInfo.GuildRoster() end
        C_FriendList.ShowFriends()
    end
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if IsInGuild() then
            local _, numOnline = GetNumGuildMembers()
            Stats.Data["Guild"] = tostring(numOnline or 0)
        else
            Stats.Data["Guild"] = "0"
        end
    end
    if event == "FRIENDLIST_UPDATE" or event == "BN_FRIEND_INFO_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        local bnetOnline = select(2, BNGetNumFriends()) or 0
        local wowOnline = C_FriendList.GetNumOnlineFriends() or 0
        Stats.Data["Friends"] = tostring(bnetOnline + wowOnline)
    end
end
function Stats:UpdateCharacterStats()
    local function SafeFmt(fn, ...)
        local args = {...}
        local ok, val = pcall(fn, unpack(args))
        if ok and val then
            local ok2, result = pcall(BreakUpLargeNumbers, val)
            return ok2 and result or "0"
        end
        return "0"
    end
    local function SafePct(fmt, fn, ...)
        local args = {...}
        local ok, val = pcall(fn, unpack(args))
        if ok and val then
            local ok2, result = pcall(string.format, fmt, val)
            return ok2 and result or "0%"
        end
        return "0%"
    end
    Stats.Data["Strength"] = SafeFmt(UnitStat, "player", 1)
    Stats.Data["Agility"]  = SafeFmt(UnitStat, "player", 2)
    Stats.Data["Stamina"]  = SafeFmt(UnitStat, "player", 3)
    Stats.Data["Intellect"]= SafeFmt(UnitStat, "player", 4)
    local ok_armor, a1, a2, a3, a4 = pcall(UnitArmor, "player")
    local armorVal = 0
    if ok_armor then
        for _, v in ipairs({a1, a2, a3, a4}) do
            local ok_v, num = pcall(function() return v + 0 end)
            if ok_v and num and num > armorVal then armorVal = num end
        end
    end
    local ok_armorFmt, armorStr = pcall(BreakUpLargeNumbers, armorVal)
    Stats.Data["Armor"] = ok_armorFmt and armorStr or "0"
    Stats.Data["Max HP"]   = SafeFmt(UnitHealthMax, "player")
    Stats.Data["Main Stat"]= Stats.Data[Stats.ActiveMainStat] or "0"
    Stats.Data["Crit"]        = SafePct("%.1f%%", GetCritChance)
    Stats.Data["Haste"]       = SafePct("%.1f%%", GetHaste)
    Stats.Data["Mastery"]     = SafePct("%.1f%%", GetMasteryEffect)
    Stats.Data["Avoidance"]   = SafePct("%.1f%%", GetAvoidance)
    Stats.Data["Leech"]       = SafePct("%.1f%%", GetLifesteal)
    Stats.Data["Speed"]       = SafePct("%.1f%%", GetSpeed)
    Stats.Data["Dodge"]       = SafePct("%.1f%%", GetDodgeChance)
    Stats.Data["Parry"]       = SafePct("%.1f%%", GetParryChance)
    local ok_vers, versResult = pcall(function()
        return string.format("%.1f%%",
            GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) +
            GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
    end)
    Stats.Data["Versatility"] = ok_vers and versResult or "0%"
end
function Stats:UpdateAllStats()
    self:UpdatePolledStats(0)
    self:UpdateEventStat("PLAYER_ENTERING_WORLD")
    self:UpdateCharacterStats()
end
function Stats:GetStat(statType)
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
    if statType == "Main Stat" then
        local labelMap = { ["Strength"]="Str", ["Agility"]="Agi", ["Intellect"]="Int" }
        return Stats.Data["Main Stat"], labelMap[Stats.ActiveMainStat] or "Stat"
    end
    local val = Stats.Data[statType]
    local lbl = ""
    if statType == "FPS" then lbl = "FPS"
    elseif statType == "MS" then lbl = "MS"
    elseif statType == "RAM" then lbl = (tonumber(val) and tonumber(val) > 100) and "MB" or "KB"
    elseif statType == "Durability" then lbl = "D"
    elseif statType == "Bag Space" then lbl = "Bag"
    elseif statType == "Item Level" then lbl = "ilvl"
    elseif statType == "XP" then lbl = "XP"
    elseif statType == "Stamina" then lbl = "Sta"
    elseif statType == "Crit" then lbl = "Crit"
    elseif statType == "Haste" then lbl = "Haste"
    elseif statType == "Mastery" then lbl = "Mast"
    elseif statType == "Versatility" then lbl = "Vers"
    elseif statType == "Avoidance" then lbl = "Avoid"
    elseif statType == "Leech" then lbl = "Leech"
    elseif statType == "Speed" then lbl = "Speed"
    elseif statType == "Run Speed" then lbl = "Run"
    elseif statType == "Dodge" then lbl = "Dodg"
    elseif statType == "Parry" then lbl = "Pry"
    elseif statType == "Armor" then lbl = "Armor"
    elseif statType == "Max HP" then lbl = "HP"
    elseif statType == "Guild" then lbl = "Guild"
    elseif statType == "Friends" then lbl = "Friends"
    elseif statType == "Difficulty" then lbl = "Diff"
    elseif statType == "Talent Loadout" then lbl = "Talent"
    end
    return val or "", lbl
end
function Stats:AddTooltip(owner, statType, elemData)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    local added = false
    if statType == "Talent Loadout" then
        GameTooltip:AddLine("Active Talent Loadout", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Displays your current talent build.", 1, 0.8, 0)
        GameTooltip:AddLine("Fully supports standard WoW API and", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("'Talent Loadout Ex' addon data.", 0.7, 0.7, 0.7)
        added = true
    end
    if statType == "Zone" or statType == "Coords" then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo(mapID)
            GameTooltip:AddLine(info and info.name or "Unknown Zone", 1, 1, 1)
            GameTooltip:AddLine(" ")
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then GameTooltip:AddDoubleLine("Coordinates:", string.format("%.1f, %.1f", pos.x*100, pos.y*100), 1,0.8,0, 1,1,1) end
            local pvpType, _, _ = GetZonePVPInfo()
            GameTooltip:AddDoubleLine("PVP Status:", pvpType or "Normal", 1,0.8,0, 1,1,1)
            added = true
        end
    end
    if statType == "Gold" then
        GameTooltip:AddLine("Economy", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local moneySep = (elemData and elemData.separator) or "COMMA"
        local current = GetMoney()
        local start = Stats.SessionStartMoney or current
        local diff = current - start
        GameTooltip:AddDoubleLine("Current:", GetMoneyString(current, moneySep), 1,0.8,0, 1,1,1)
        GameTooltip:AddDoubleLine("Session Start:", GetMoneyString(start, moneySep), 1,0.8,0, 1,1,1)
        local diffColor = (diff >= 0) and {0,1,0} or {1,0,0}
        GameTooltip:AddDoubleLine("Session Profit:", GetMoneyString(math.abs(diff), moneySep), 1,0.8,0, diffColor[1], diffColor[2], diffColor[3])
        local myKey = GetCurrentCharacterKey()
        local goldCache = WidgetForgeDB and WidgetForgeDB.goldCache
        local accountTotal = 0
        local rows = {}
        if type(goldCache) == "table" then
            for key, data in pairs(goldCache) do
                if type(data) == "table" and type(data.money) == "number" then
                    accountTotal = accountTotal + data.money
                    if key ~= myKey then
                        local rowName = data.name or key
                        if data.realm and data.realm ~= "" then
                            rowName = rowName .. "-" .. data.realm
                        end
                        table.insert(rows, { name = rowName, money = data.money })
                    end
                end
            end
        end
        table.sort(rows, function(a, b) return a.money > b.money end)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Other Characters", 1, 1, 1)
        if #rows == 0 then
            GameTooltip:AddLine("No other character data yet.", 0.7, 0.7, 0.7)
        else
            for _, row in ipairs(rows) do
                GameTooltip:AddDoubleLine(row.name, GetMoneyString(row.money, moneySep), 1, 1, 1, 1, 1, 1)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Account Total:", GetMoneyString(accountTotal, moneySep), 1,0.8,0, 1,1,1)
        added = true
    end
    if statType == "System" or statType == "RAM" or statType == "FPS" or statType == "MS" then
        GameTooltip:AddLine("System Performance", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local _, _, diffHome, diffWorld = GetNetStats()
        GameTooltip:AddDoubleLine("Home Latency:", diffHome.." ms", 1,0.8,0, 1,1,1)
        GameTooltip:AddDoubleLine("World Latency:", diffWorld.." ms", 1,0.8,0, 1,1,1)
        local totalMem = collectgarbage("count")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Memory:", string.format("%.1f MB", totalMem/1024), 1,0.8,0, 0,1,0)
        added = true
    end 
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
            local ok_tip, tipResult = pcall(function()
                local data = C_TooltipInfo.GetInventoryItem("player", i)
                if data and type(data) == "table" and data.repairCost then
                    return data.repairCost
                end
                return 0
            end)
            if ok_tip and tipResult then totalCost = totalCost + tipResult end
        end
        if not damagedItems then GameTooltip:AddLine("All items are fully repaired.", 0, 1, 0)
        else GameTooltip:AddLine(" "); GameTooltip:AddDoubleLine("Repair Cost:", GetMoneyString(totalCost), 1,0.8,0, 1,1,1) end
        added = true
    end
    if statType == "Bag Space" or statType == "BagSpace" then
        GameTooltip:AddLine("Bag Usage", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local totalFree, totalSlots = 0, 0
        for i = 0, 5 do
            local free = C_Container.GetContainerNumFreeSlots(i)
            local total = C_Container.GetContainerNumSlots(i)
            local name = (i==0) and "Backpack" or (i==5 and "Reagent Bag" or "Bag " .. i)
            if total > 0 then
                 local used = total - free
                 GameTooltip:AddDoubleLine(name, used.." / "..total, 1,1,1, 1,0.8,0)
                 totalFree = totalFree + free; totalSlots = totalSlots + total
            end
        end
        GameTooltip:AddLine(" ")
        local totalUsed = totalSlots - totalFree
        GameTooltip:AddDoubleLine("Total Used:", totalUsed.." / "..totalSlots, 1,0.8,0, 0,1,0)
        added = true
    end
    if statType == "Clock" then
        GameTooltip:AddLine("Time Info", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Server Time:", date("%H:%M:%S"), 1,1,1, 1,0.8,0)
        GameTooltip:AddDoubleLine("Local Time:", date("%H:%M:%S", time()), 1,1,1, 1,0.8,0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Date:", date("%A, %B %d, %Y"), 1,0.8,0, 1,1,1)
        added = true
    end
    if statType == "Main Stat" then
        GameTooltip:AddLine(Stats.ActiveMainStat .. " (Main Stat)", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("This element automatically switches between", 1, 1, 1, true)
        GameTooltip:AddLine("Strength, Agility, or Intellect", 1, 0.8, 0, true)
        GameTooltip:AddLine("based on your current specialization.", 1, 1, 1, true)
        added = true
    end
    if statType == "Guild" then
        GameTooltip:AddLine("Online Guild Members", 1, 1, 1)
        GameTooltip:AddLine(" ")
        if IsInGuild() then
            local numTotal, numOnline = GetNumGuildMembers()
            local showCount = 0
            for i = 1, numTotal do
                local name, rankName, rankIndex, level, classDisplayName, zone, note, officernote, isOnline, status, class = GetGuildRosterInfo(i)
                if isOnline then
                    local color = RAID_CLASS_COLORS[class]
                    local hex = color and color.colorStr or "ffffffff"
                    local cleanName = strsplit("-", name)
                    GameTooltip:AddDoubleLine(string.format("|c%s%s|r (Lvl %d)", hex, cleanName, level), zone or "", 1, 1, 1, 0.7, 0.7, 0.7)
                    showCount = showCount + 1
                    if showCount >= 30 then
                        GameTooltip:AddLine("...and more", 0.5, 0.5, 0.5)
                        break
                    end
                end
            end
        else
            GameTooltip:AddLine("You are not in a guild.", 1, 0, 0)
        end
        added = true
    end
    if statType == "Friends" then
        GameTooltip:AddLine("Online Friends", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local showCount = 0
        local maxShow = 30
        local numWoW = C_FriendList.GetNumOnlineFriends()
        for i = 1, numWoW do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                local color = RAID_CLASS_COLORS[info.className]
                local hex = color and color.colorStr or "ffffffff"
                GameTooltip:AddDoubleLine(string.format("|c%s%s|r (Lvl %d)", hex, info.name, info.level), info.area or "", 1, 1, 1, 0.7, 0.7, 0.7)
                showCount = showCount + 1
            end
            if showCount >= maxShow then break end
        end
        if showCount < maxShow then
            local numBNet, numBNetOnline = BNGetNumFriends()
            for i = 1, numBNet do
                local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
                if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                    local client = accountInfo.gameAccountInfo.clientProgram
                    local charName = accountInfo.gameAccountInfo.characterName
                    local bnetName = accountInfo.accountName
                    local zone = accountInfo.gameAccountInfo.areaName or ""
                    if client == "WoW" then
                        GameTooltip:AddDoubleLine(string.format("|cff82c5ff%s|r (|cffffffff%s|r)", bnetName, charName), zone, 1, 1, 1, 0.7, 0.7, 0.7)
                    else
                        GameTooltip:AddDoubleLine(string.format("|cff82c5ff%s|r", bnetName), client, 1, 1, 1, 0.5, 0.5, 0.5)
                    end
                    showCount = showCount + 1
                    if showCount >= maxShow then break end
                end
            end
        end
        if showCount == 0 then
            GameTooltip:AddLine("No friends online.", 0.5, 0.5, 0.5)
        elseif showCount >= maxShow then
            GameTooltip:AddLine("...and more", 0.5, 0.5, 0.5)
        end
        added = true
    end
    if statType == "Difficulty" then
        GameTooltip:AddLine("Instance Info", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local name, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
        if name and difficultyName and difficultyName ~= "" and instanceType ~= "none" then
            GameTooltip:AddDoubleLine("Instance:", name, 1,0.8,0, 1,1,1)
            GameTooltip:AddDoubleLine("Difficulty:", difficultyName, 1,0.8,0, 1,1,1)
            if maxPlayers and maxPlayers > 0 then
                GameTooltip:AddDoubleLine("Max Players:", tostring(maxPlayers), 1,0.8,0, 1,1,1)
            end
        else
            GameTooltip:AddLine("You are currently in the open world.", 0.7, 0.7, 0.7)
        end
        added = true
    end
    if not added then
        GameTooltip:AddLine(statType, 1, 1, 1)
    end
    GameTooltip:Show()
end
