ForgeStats = {}
local Stats = ForgeStats

-- Cache Table (The "View Model" for our UI)
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
    -- Dragonriding / Skyriding
    ["DragonVigor"] = 0, ["DragonVigorMax"] = 0, ["DragonSpeed"] = 0, ["DragonActive"] = false
}
-- Helper mappings
Stats.ActiveMainStat = "Strength" -- Default
Stats.CombatStart = nil

-- Helper for Money String
local function GetMoneyString(copper)
    return GetCoinTextureString(copper)
end

-- =========================================================================
--  INITIALIZATION & EVENTS
-- =========================================================================

function Stats:Initialize()
    if self.Initialized then return end
    
    Stats.SessionStartMoney = GetMoney()
    
    -- Creation of Event Frame
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
    -- Stat Events
    f:RegisterEvent("UNIT_STATS")
    f:RegisterEvent("UNIT_AURA") -- Sometimes needed for buffs affecting stats
    f:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
    
    f:SetScript("OnEvent", function(self, event, ...)
        Stats:UpdateEventStat(event, ...)
    end)
    
    self.EventFrame = f
    self.Initialized = true
    
    -- Initial Force Update
    self:UpdateSpecInfo()
    self:UpdateAllStats()
end

function Stats:UpdateSpecInfo()
    local specIndex = GetSpecialization()
    WIDGETFORGE_DEBUG("UpdateSpecInfo Triggered. SpecIndex:", specIndex)
    
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        WIDGETFORGE_DEBUG("SpecID Found:", specID)
        
        if specID and WIDGETFORGE_SPECS[specID] then
            Stats.ActiveMainStat = WIDGETFORGE_SPECS[specID]
            WIDGETFORGE_DEBUG("ActiveMainStat Set to (from spec):", Stats.ActiveMainStat)
        else
            -- Fallback to Class Default
            local _, classFilename = UnitClassBase("player")
            Stats.ActiveMainStat = WIDGETFORGE_CLASS_DEFAULTS[classFilename] or "Strength"
            WIDGETFORGE_DEBUG("ActiveMainStat Fallback (class):", Stats.ActiveMainStat)
        end
    else
        local _, classFilename = UnitClassBase("player")
        Stats.ActiveMainStat = WIDGETFORGE_CLASS_DEFAULTS[classFilename] or "Strength"
        WIDGETFORGE_DEBUG("ActiveMainStat Default (no spec):", Stats.ActiveMainStat)
    end
end

-- =========================================================================
--  UPDATE LOGIC ( The Motor )
-- =========================================================================

-- Called by WidgetForge main loop (Throttled but frequent, e.g. 0.5s)
function Stats:UpdatePolledStats(elapsed)
    -- 1. FPS
    Stats.Data["FPS"] = floor(GetFramerate())
    
    -- 2. MS (Latency)
    local _, _, _, lat = GetNetStats()
    Stats.Data["MS"] = lat
    
    -- 3. Clock (System Time) - Format is handled in UI, raw is sufficient but we store generic here
    Stats.Data["Clock"] = date("%H:%M")
    
    -- 4. RAM (Memory)
    local mem = collectgarbage("count")
    if mem > 1024 then Stats.Data["RAM"] = string.format("%.1f", mem/1024)
    else Stats.Data["RAM"] = floor(mem) end
    
    -- 5. Combat Timer
    if UnitAffectingCombat("player") then
        if not Stats.CombatStart then Stats.CombatStart = GetTime() end
        local t = GetTime() - Stats.CombatStart
        local m = floor(t/60)
        local s = floor(t%60)
        Stats.Data["Combat Timer"] = string.format("|cffff0000%02d:%02d|r", m, s)
    else
        Stats.Data["Combat Timer"] = "00:00"
    end

    -- 6. Run Speed (Dynamic)
    local unitSpeed = GetUnitSpeed("player")
    if unitSpeed then
        Stats.Data["Run Speed"] = string.format("%.0f%%", (unitSpeed / 7) * 100)
    else
        Stats.Data["Run Speed"] = "0%"
    end

    -- 7. Dragonriding / Skyriding Data (Falcon Logic)
    -- Vigor (Spell ID 372608 is the Vigor resource tracker)
    local vigorData = C_Spell.GetSpellCharges(372608)
    if vigorData then
        local current = vigorData.currentCharges or 0
        local max = vigorData.maxCharges or 6
        -- Calculate fractional progress if recharging
        local fractional = 0
        local now = GetTime()
        if vigorData.cooldownStartTime and vigorData.cooldownDuration and vigorData.cooldownDuration > 0 then
            fractional = (now - vigorData.cooldownStartTime) / vigorData.cooldownDuration
            if fractional < 0 then fractional = 0 end
            if fractional > 1 then fractional = 1 end
        end
        
        -- If full, fractional is 0 (or 1 depending on logic, but usually we just want current)
        -- Falcon logic: if recharging, add fractional. 
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

    -- Speed (Forward Speed from Gliding Info)
    local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    Stats.Data["DragonSpeed"] = forwardSpeed or 0
    
    -- Active State (Bonus Bar 11 is Dragonriding)
    local isSkyriding = (GetBonusBarIndex() == 11)
    Stats.Data["DragonActive"] = isSkyriding
end

-- Called on Events (Efficient)
function Stats:UpdateEventStat(event, arg1)
    
    if event == "PLAYER_MONEY" or event == "PLAYER_ENTERING_WORLD" then
        Stats.Data["Gold"] = GetMoneyString(GetMoney())
    end
    
    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
        Stats.Data["Zone"] = GetMinimapZoneText() or ""
        
        -- Coords (Only update heavily if map changes or polled separate? Coords need polling actually)
        -- We will leave Coords to be polled in GetStat or separate Loop as they change effectively every frame moving
    end
    
    if event == "BAG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local free, total = 0, 0
        for i = 0, NUM_BAG_SLOTS do
            free = free + C_Container.GetContainerNumFreeSlots(i)
            total = total + C_Container.GetContainerNumSlots(i)
        end
        Stats.Data["Bag Space"] = free .. "/" .. total
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
            Stats.Data["XP"] = string.format("%.1f%%", (curr/max)*100)
        end
    end
    
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        local _, avg = GetAverageItemLevel()
        Stats.Data["Item Level"] = floor(avg)
        -- Re-check durability on equip change
        Stats:UpdateEventStat("UPDATE_INVENTORY_DURABILITY")
        -- Force update stats (Leech, Speed, etc change with gear)
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
end

function Stats:UpdateCharacterStats()
    -- Helper for formatting
    local function Fmt(val)
        if not val then return "0" end
        return BreakUpLargeNumbers(val)
    end

    -- Primary Stats: WoW API indices: 1=Str, 2=Agi, 3=Sta, 4=Int
    Stats.Data["Strength"] = Fmt(UnitStat("player", 1))
    Stats.Data["Agility"] = Fmt(UnitStat("player", 2))
    Stats.Data["Stamina"] = Fmt(UnitStat("player", 3))
    Stats.Data["Intellect"] = Fmt(UnitStat("player", 4))
    
    -- Armor: Pick the highest return value (2nd is effective with gear)
    local a1, a2, a3, a4 = UnitArmor("player")
    local armorVal = 0
    if a1 and type(a1) == "number" then armorVal = math.max(armorVal, a1) end
    if a2 and type(a2) == "number" then armorVal = math.max(armorVal, a2) end
    if a3 and type(a3) == "number" then armorVal = math.max(armorVal, a3) end
    if a4 and type(a4) == "number" then armorVal = math.max(armorVal, a4) end
    Stats.Data["Armor"] = Fmt(armorVal)
    
    -- Max HP
    Stats.Data["Max HP"] = Fmt(UnitHealthMax("player"))

    -- Main Stat Dynamic Update
    Stats.Data["Main Stat"] = Stats.Data[Stats.ActiveMainStat] or "0"

    -- Secondary
    Stats.Data["Crit"] = string.format("%.1f%%", GetCritChance())
    Stats.Data["Haste"] = string.format("%.1f%%", GetHaste())
    Stats.Data["Mastery"] = string.format("%.1f%%", GetMasteryEffect())
    Stats.Data["Versatility"] = string.format("%.1f%%", GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
    Stats.Data["Avoidance"] = string.format("%.1f%%", GetAvoidance())
    Stats.Data["Leech"] = string.format("%.1f%%", GetLifesteal())
    Stats.Data["Speed"] = string.format("%.1f%%", GetSpeed()) -- Tertiary Stat
    Stats.Data["Dodge"] = string.format("%.1f%%", GetDodgeChance())
    Stats.Data["Parry"] = string.format("%.1f%%", GetParryChance())
end

function Stats:UpdateAllStats()
    self:UpdatePolledStats(0)
    self:UpdateEventStat("PLAYER_ENTERING_WORLD")
    self:UpdateCharacterStats()
end

-- =========================================================================
--  GETTER ( The View Access )
-- =========================================================================

-- Returns: ValueString, LabelString (optional)
function Stats:GetStat(statType)
    -- Handle Special Cases that MUST be live or logic-heavy
    
    -- Coords are polled because they change constantly when moving, 
    -- and we don't want to register a high-frequency OnUpdate just for coords unless needed.
    -- Ideally, we only calc if requested.
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
    
    -- Main Stat Label Logic
    if statType == "Main Stat" then
        -- Return cached numeric value, and Short Label of active stat
        -- We construct the label dynamically based on ActiveMainStat
        local labelMap = { ["Strength"]="Str", ["Agility"]="Agi", ["Intellect"]="Int" }
        return Stats.Data["Main Stat"], labelMap[Stats.ActiveMainStat] or "Stat"
    end
    
    -- Normal Cached Access
    local val = Stats.Data[statType]
    
    -- Label Mapping (Could be table based)
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
    end
    
    return val or "", lbl
end

-- =========================================================================
--  TOOLTIP LOGIC (Unchanged mostly, but optimized slightly if needed)
-- =========================================================================

function Stats:AddTooltip(owner, statType, elemData)
    -- ... [Same as before, logic is fine for OnEnter] ...
    -- We will keep the original tooltip logic but ensure it pulls fresh data where critical
    -- or uses the cache if sufficient. For Tooltips, pulling fresh data is usually fine/preferred.
    
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    
    local added = false
    
    -- [Previous Tooltip Code Logic here - preserved for functionality]
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
        local _, _, diffHome, diffWorld = GetNetStats()
        GameTooltip:AddDoubleLine("Home Latency:", diffHome.." ms", 1,0.8,0, 1,1,1)
        GameTooltip:AddDoubleLine("World Latency:", diffWorld.." ms", 1,0.8,0, 1,1,1)
        -- Garbage Collection
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
            local hasItem, _, cost = C_TooltipInfo.GetInventoryItem("player", i)
            if hasItem and cost then totalCost = totalCost + cost end
        end
        if not damagedItems then GameTooltip:AddLine("All items are fully repaired.", 0, 1, 0)
        else GameTooltip:AddLine(" "); GameTooltip:AddDoubleLine("Repair Cost:", GetMoneyString(totalCost), 1,0.8,0, 1,1,1) end
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
                 totalFree = totalFree + free; totalSlots = totalSlots + total
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
    
    if not added then
        GameTooltip:AddLine(statType, 1, 1, 1)
    end

    GameTooltip:Show()
end
