-- =========================================================================
--  WidgetForge - Prep Checker Module
--  [WoW 12 Compliant - Midnight API]
--  Dungeon & Raid consumable readiness panel
--  Flask, Food, Rune, Potion, Healthstone, Trinkets
--
--  ID GÃœNCELLEMESÄ°: Midnight 12.0.1 (Åžubat 2026)
--  Kaynak: Wowhead Live 12.0.1, method.gg, icy-veins.com
--
--  DOÄžRULAMA NOTU:
--    [âœ“] = Wowhead 12.0.1 Live'dan doÄŸrulandÄ±
--    [~] = Wowhead Beta/PTR'den alÄ±ndÄ±, live'da aynÄ± olmalÄ±
--    [?] = Oyun iÃ§i doÄŸrulama Ã¶nerilir
--
--  EÄŸer herhangi bir ID Ã§alÄ±ÅŸmazsa, oyun iÃ§inde ÅŸu macro ile
--  aktif buff spell ID'lerini kontrol edebilirsin:
--  /run for i=1,40 do local d=C_UnitAuras.GetBuffDataByIndex("player",i) if d then print(d.spellId, d.name) end end
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.PrepChecker = {}

local PrepChecker = _G.WidgetForge.PrepChecker
addonTable.PrepChecker = PrepChecker

PrepChecker.Instances = {}

-- =========================================================================
--  TRACKED BUFF & ITEM IDs  â€” YALNIZCA MIDNIGHT (12.0.1)
-- =========================================================================

PrepChecker.FlaskBuffIDs = {
    -- -----------------------------------------------------------------------
    -- MIDNIGHT Flasklar â€” Buff Spell ID'leri (aura olarak Ã¼stÃ¼nÃ¼ze uygulanan)
    -- -----------------------------------------------------------------------
    1235057, -- [âœ“] Flask of Thalassian Resistance   (+Versatility)
    1235108, -- [âœ“] Flask of the Magisters            (+Mastery)
    1235110, -- [âœ“] Flask of the Blood Knights        (+Haste)
    1235111, -- [âœ“] Flask of the Shattered Sun        (+Critical Strike)
    1239355, -- [âœ“] Vicious Thalassian Flask of Honor (PvP, +%15 Honor)

    -- -----------------------------------------------------------------------
    -- MIDNIGHT Phiallar â€” Meslek stat'larÄ± (Craft yaparken kullanÄ±lÄ±r)
    -- -----------------------------------------------------------------------
    1236763, -- [âœ“] Haranir Phial of Perception  (+Perception & Deftness)
    1239755, -- [âœ“] Haranir Phial of Ingenuity   (+Ingenuity & Crafting Speed)
}

PrepChecker.FoodBuffIDs = {
    -- -----------------------------------------------------------------------
    -- MIDNIGHT Yemek Buff'larÄ±
    --
    -- Midnight'ta her yemeÄŸin kendine Ã¶zgÃ¼ "Well Fed" spell ID'si vardÄ±r.
    -- HenÃ¼z Wowhead'de tek bir tablo olarak listelenemedi.
    -- AÅŸaÄŸÄ±daki ID'lere ek olarak, kod zaten "Well Fed" adÄ±na
    -- gÃ¶re fallback yapÄ±yor â€” bu sayede bilinmeyen ID'ler de yakalanÄ±r.
    --
    -- Bilinen yemekler ve item ID'leri (buff spell ID'leri â‰  item ID'leri):
    --   Silvermoon Parade (feast)      â€” item 255845
    --   Harandar Celebration (feast)   â€” item ID teyit bekleniyor
    --   Blooming Feast (feast)         â€” item ID teyit bekleniyor
    --   Royal Roast (main stat)        â€” item 242275
    --   Impossibly Royal Roast         â€” item ID teyit bekleniyor
    --   Champion's Bento (sec stat)    â€” item ID teyit bekleniyor
    --   Quel'dorei Medley (sec stat)   â€” item ID teyit bekleniyor
    --   Flora Frenzy (sec stat)        â€” item ID teyit bekleniyor
    --   Sun-Seared Lumifin (budget)    â€” item ID teyit bekleniyor
    --   Arcano Cutlets (budget)        â€” item ID teyit bekleniyor
    --
    -- Hearty versiyonlar (Ã¶lÃ¼mde kaybolmaz):
    --   Hearty Royal Roast, Hearty Silvermoon Parade vb.
    --
    -- Oyun iÃ§i macro ile kendi Well Fed spell ID'lerini bul:
    -- /run for i=1,40 do local d=C_UnitAuras.GetBuffDataByIndex("player",i) if d then print(d.spellId, d.name) end end
    -- Yemek yedikten sonra Ã§alÄ±ÅŸtÄ±r, "Well Fed" yazan satÄ±rÄ±n spellId'sini buraya ekle.
    -- -----------------------------------------------------------------------
    -- Åžimdilik boÅŸ; "Well Fed" isim fallback'i tÃ¼m yemekleri yakalar.
    -- Kendi bulduklarÄ±nÄ± customFoodIDs alanÄ±ndan ya da buraya ekle.
}

PrepChecker.RuneBuffIDs = {
    -- -----------------------------------------------------------------------
    -- MIDNIGHT Augment Rune'larÄ± â€” Buff Spell ID'leri
    -- -----------------------------------------------------------------------
    1264426, -- [âœ“] Void-Touched Augment Rune   (item 259085 â€” ana Midnight consumable rune)
             --     +25 Primary Stat, 1 saat, Ã¶lÃ¼mde sÄ±fÄ±rlanÄ±r
             --     Patron Order'lardan, AH'ten gelir.

    1234969, -- [âœ“] Ethereal Augment Rune        (item 243191 â€” TWW S3 kalÄ±cÄ± rune)
             --     K'aresh Trust Renown 18 + 100.000g gerektirir.
             --     Midnight'a taÅŸÄ±nÄ±r, hÃ¢lÃ¢ aktif.
             --     Buff adÄ±: "Ethereal Augmentation"

    -- [?] Soulgorged Augment Rune (item ? â€” Manaforge Vandals Renown 9 drop)
    --     Void-Touched ile aynÄ± stat, ama Ã¶lÃ¼mde KAYBOLMAZ.
    --     Spell ID henÃ¼z teyit edilemedi; aÅŸaÄŸÄ±ya ekle:
    -- XXXX, -- Soulgorged Augment Rune buff spell ID (teyit gerekiyor)
}

PrepChecker.PotionItemIDs = {
    -- -----------------------------------------------------------------------
    -- MIDNIGHT Combat & Utility PotionlarÄ± â€” Item ID'leri (envanterde sayÄ±lÄ±r)
    --
    -- Her potionun Silver ve Gold olmak Ã¼zere 2 kalite seviyesi vardÄ±r.
    -- Ä°ki kaliteyi de sayabilmek iÃ§in her ikisi de listelenmiÅŸtir.
    -- -----------------------------------------------------------------------

    -- --- COMBAT (DPS) POTIONLARI ---
    241289, -- [âœ“] Potion of Recklessness (Silver) â€” En yÃ¼ksek secondary stat +1585, en dÃ¼ÅŸÃ¼k â€‘213, 30 sn
    241290, -- [~] Potion of Recklessness (Gold)
    241292, -- [âœ“] Draught of Rampant Abandon (Silver) â€” +Primary stat; negatif: void zone spawnar
    241293, -- [~] Draught of Rampant Abandon (Gold)
    241296, -- [âœ“] Potion of Zealotry (Silver)    â€” Single target DPS potionÄ±
    241297, -- [~] Potion of Zealotry (Gold)

    -- --- HEALER / PRIMARY STAT POTIONLARI ---
    241309, -- [âœ“] Light's Potential (Silver)     â€” Primary stat burst (healer + DPS)
    241310, -- [~] Light's Potential (Gold)

    -- --- MANA POTIONLARI ---
    241300, -- [âœ“] Lightfused Mana Potion (Silver) â€” AnlÄ±k mana (cooldown yok, kanala gerek yok)
    241301, -- [~] Lightfused Mana Potion (Gold)
    -- Potion of Devoured Dreams â€” item ID teyit bekleniyor, tahminen 241302/241303
    -- 241302, -- [?] Potion of Devoured Dreams (Silver) â€” Raid healer mana potionÄ± (channeled, daha fazla mana)
    -- 241303, -- [?] Potion of Devoured Dreams (Gold)

    -- --- SAÄžLIK POTIONLARI ---
    241304, -- [~] Silvermoon Health Potion (Silver)
    241305, -- [âœ“] Silvermoon Health Potion (Gold)  â€” Ana healing potion, Healthstone ile CD paylaÅŸmaz

    -- --- UTILITY POTIONLARI ---
    -- Void-Shrouded Tincture â€” M+ trash skip iÃ§in gÃ¶rÃ¼nmezlik potionÄ±
    -- item ID teyit bekleniyor; eklemek istersen aÅŸaÄŸÄ±ya ekle.
}

PrepChecker.HealthstoneItemID = 5512

-- =========================================================================
--  HELPERS: Custom ID parsing
-- =========================================================================

local function ParseIDString(str)
    local ids = {}
    if not str or str == "" then return ids end
    for idStr in string.gmatch(str, "([^,%s]+)") do
        local n = tonumber(idStr)
        if n then table.insert(ids, n) end
    end
    return ids
end

local function MergeIDs(base, extra)
    local merged = {}
    for _, id in ipairs(base) do merged[#merged + 1] = id end
    for _, id in ipairs(extra) do merged[#merged + 1] = id end
    return merged
end

-- =========================================================================
--  ITEM COUNT (WoW 12: C_Item namespace)
-- =========================================================================

local function SafeGetItemCount(itemID)
    if not itemID then return 0 end
    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID, false)
        if ok then return count or 0 end
    end
    if GetItemCount then
        local ok, count = pcall(GetItemCount, itemID, false)
        if ok then return count or 0 end
    end
    return 0
end

-- =========================================================================
--  TRINKET INFO (WoW 12: C_Item & inventory APIs)
-- =========================================================================

local function GetTrinketInfo(slot)
    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not itemLink then return nil, nil, nil end

    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)

    -- Most reliable source for equipped-slot icon.
    local itemTexture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)

    if not itemTexture and itemID and C_Item and C_Item.GetItemIconByID then
        local ok, tex = pcall(C_Item.GetItemIconByID, itemID)
        if ok and tex then itemTexture = tex end
    end
    if not itemTexture and itemLink and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, _, _, _, tex = pcall(C_Item.GetItemInfoInstant, itemLink)
        if ok and tex then itemTexture = tex end
    end
    if not itemTexture and GetItemInfo then
        local ok, n,l,q,r,s,t,u,e,tex = pcall(GetItemInfo, itemLink)
        if ok then itemTexture = tex end
    end

    return itemTexture, itemID, itemLink
end

-- =========================================================================
--  BUFF DETECTION (WoW 12: C_UnitAuras)
-- =========================================================================

local function FindBuffByIDs(spellIDs)
    if not C_UnitAuras then return false end

    -- Combat-safe: avoid comparing potentially secret aura spellId values.
    if C_UnitAuras.GetPlayerAuraBySpellID then
        for _, id in ipairs(spellIDs) do
            local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and data then
                return true, data.name, id, data.applications
            end
        end
        return false
    end
    return false
end

local function FindBuffByNameFragments(fragments)
    if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then return false end
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if not ok or not data then break end
        local name = data.name
        if name then
            for _, frag in ipairs(fragments) do
                local okFind, findPos = pcall(string.find, name, frag, 1, true)
                if okFind and findPos then
                    return true, name, data.spellId, data.applications
                end
            end
        end
    end
    return false
end

local function IsFlaskActive(allFlaskIDs)
    local ok, name, sid = FindBuffByIDs(allFlaskIDs)
    if ok then return true, name, sid end
    -- Midnight phiallar "Phial" adÄ± yerine benzersiz isimler taÅŸÄ±yor.
    -- "Flask" adÄ± iÃ§eren buff'larÄ± yakala + bilinen Midnight flask adlarÄ±nÄ±.
    return FindBuffByNameFragments({
        "Flask",
        "Phial",
        "Thalassian Resistance",
        "Blood Knights",
        "Magisters",
        "Shattered Sun",
        "Haranir Phial",
    })
end

local function IsFoodActive(allFoodIDs)
    local ok, name, sid = FindBuffByIDs(allFoodIDs)
    if ok then return true, name, sid end
    return FindBuffByNameFragments({"Well Fed", "Well-Fed"})
end

local function IsRuneActive(allRuneIDs)
    local ok, name, sid = FindBuffByIDs(allRuneIDs)
    if ok then return true, name, sid end
    return FindBuffByNameFragments({
        "Augment Rune",
        "Void-Touched",
        "Ethereal Augmentation",
        "Soulgorged",
    })
end

-- =========================================================================
--  POTION COUNT
-- =========================================================================

local function GetPotionCount(itemIDs)
    local total = 0
    for _, id in ipairs(itemIDs) do
        total = total + SafeGetItemCount(id)
    end
    return total
end

-- =========================================================================
--  SLOT LIST BUILDER
-- =========================================================================

local function BuildSlotList(elem)
    local slots = {}

    local customFlaskIDs  = ParseIDString(elem.customFlaskIDs)
    local customFoodIDs   = ParseIDString(elem.customFoodIDs)
    local customRuneIDs   = ParseIDString(elem.customRuneIDs)
    local customPotionIDs = ParseIDString(elem.customPotionIDs)
    local customItemIDs   = ParseIDString(elem.customItemIDs)

    local allFlaskIDs  = MergeIDs(PrepChecker.FlaskBuffIDs, customFlaskIDs)
    local allFoodIDs   = MergeIDs(PrepChecker.FoodBuffIDs, customFoodIDs)
    local allRuneIDs   = MergeIDs(PrepChecker.RuneBuffIDs, customRuneIDs)
    local allPotionIDs = MergeIDs(PrepChecker.PotionItemIDs, customPotionIDs)

    if elem.showFlask ~= false then
        table.insert(slots, {
            id = "flask", label = "Flask",
            icon = "Interface\\Icons\\INV_Potion_93",
            type = "BUFF",
            checkFn = function() return IsFlaskActive(allFlaskIDs) end,
            tooltip = "Flask / Phial buff status",
        })
    end

    if elem.showFood ~= false then
        table.insert(slots, {
            id = "food", label = "Food",
            icon = "Interface\\Icons\\INV_Misc_Food_16",
            type = "BUFF",
            checkFn = function() return IsFoodActive(allFoodIDs) end,
            tooltip = "Well Fed buff status",
        })
    end

    if elem.showRune ~= false then
        table.insert(slots, {
            id = "rune", label = "Rune",
            icon = "Interface\\Icons\\INV_Stone_04",
            type = "BUFF",
            checkFn = function() return IsRuneActive(allRuneIDs) end,
            tooltip = "Augment Rune buff status",
        })
    end

    if elem.showPotion ~= false then
        table.insert(slots, {
            id = "potion", label = "Pot",
            icon = "Interface\\Icons\\INV_Potion_92",
            type = "COUNT",
            countFn = function() return GetPotionCount(allPotionIDs) end,
            minWarn = elem.potionWarnBelow or 1,
            tooltip = "Combat potions in inventory",
        })
    end

    if elem.showHealthstone ~= false then
        table.insert(slots, {
            id = "healthstone", label = "HS",
            icon = "Interface\\Icons\\INV_Stone_04",
            type = "COUNT",
            countFn = function()
                local count = SafeGetItemCount(PrepChecker.HealthstoneItemID)
                for _, id in ipairs(customItemIDs) do
                    count = count + SafeGetItemCount(id)
                end
                return count
            end,
            minWarn = 1,
            tooltip = "Healthstone + custom items in inventory",
        })
    end

    if elem.showTrinket1 ~= false then
        local t1tex = GetTrinketInfo(13)
        if t1tex then
        table.insert(slots, {
            id = "trinket1", label = "T1",
            icon = nil, type = "TRINKET", trinketSlot = 13,
            tooltip = "Equipped Trinket slot 1 (slot 13)",
        })
        end
    end

    if elem.showTrinket2 ~= false then
        local t2tex = GetTrinketInfo(14)
        if t2tex then
        table.insert(slots, {
            id = "trinket2", label = "T2",
            icon = nil, type = "TRINKET", trinketSlot = 14,
            tooltip = "Equipped Trinket slot 2 (slot 14)",
        })
        end
    end

    return slots
end

-- =========================================================================
--  ICON FRAME CREATION
-- =========================================================================

local function CreateIconSlotFrame(container)
    local f = CreateFrame("Frame", nil, container, "BackdropTemplate")
    f:SetAlpha(0)

    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints(f)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.overlay = f:CreateTexture(nil, "OVERLAY")
    f.overlay:SetAllPoints(f)
    f.overlay:SetColorTexture(0, 0, 0, 0.18)
    f.overlay:Hide()

    -- Keep warning badge above icon/overlay using valid draw layer + high sublevel.
    f.warnTex = f:CreateTexture(nil, "OVERLAY")
    if f.warnTex.SetDrawLayer then
        f.warnTex:SetDrawLayer("OVERLAY", 7)
    end
    f.warnTex:SetSize(16, 16)
    f.warnTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    f.warnTex:SetTexture("Interface\\AddOns\\WidgetForge\\media\\close.tga")
    f.warnTex:SetVertexColor(1, 0.1, 0.1, 1)
    f.warnTex:Hide()

    f.countBadge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.countBadge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.countBadge:SetSize(13, 13)
    f.countBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f.countBadge:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
    f.countBadge:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
    f.countBadge:SetFrameLevel(f:GetFrameLevel() + 6)
    f.countBadge:Hide()

    f.countText = f.countBadge:CreateFontString(nil, "OVERLAY")
    f.countText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    f.countText:SetPoint("CENTER", f.countBadge, "CENTER", 0, 0)
    f.countText:SetTextColor(1, 1, 1, 1)
    f.countText:SetJustifyH("CENTER")
    f.countText:SetJustifyV("MIDDLE")
    f.countText:SetText("")

    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    f.label:SetTextColor(0.8, 0.8, 0.8, 1)
    f.label:SetJustifyH("CENTER")
    f.label:Hide()

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.slotDef then return end
        local def = self.slotDef
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(def.label or def.id, 1, 1, 1)

        if def.type == "BUFF" then
            local active, name = def.checkFn()
            if active then
                GameTooltip:AddLine("|cff00ff00Active: " .. (name or "Unknown") .. "|r")
            else
                GameTooltip:AddLine("|cffff4444Buff not active!|r")
            end
        elseif def.type == "COUNT" then
            local count = def.countFn()
            local col = count >= (def.minWarn or 1) and "|cff00ff00" or "|cffff4444"
            GameTooltip:AddLine(col .. "Count: " .. count .. "|r")
        elseif def.type == "TRINKET" then
            local _, _, itemLink = GetTrinketInfo(def.trinketSlot)
            if itemLink then
                GameTooltip:SetHyperlink(itemLink)
            else
                GameTooltip:AddLine("|cffff4444No trinket equipped!|r")
            end
        end

        if def.tooltip then
            GameTooltip:AddLine("|cff888888" .. def.tooltip .. "|r")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    return f
end

-- =========================================================================
--  FRAME POOL MANAGEMENT
-- =========================================================================

local function ManagePool(container, count)
    container.iconSlots = container.iconSlots or {}
    while #container.iconSlots < count do
        local f = CreateIconSlotFrame(container)
        f:Hide()
        table.insert(container.iconSlots, f)
    end
end

-- =========================================================================
--  STYLE APPLICATION
-- =========================================================================

local function ApplyIconStyle(f, elem)
    local size   = elem.iconSize or 32
    local zoom   = elem.iconZoom or 0.07
    local bSize  = (elem.showBorder ~= false) and (elem.borderSize or 1) or 0
    local bc     = elem.borderColor or {0, 0, 0, 1}

    f:SetSize(size, size)

    if bSize > 0 then
        f:SetBackdrop({
            bgFile  = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = bSize,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:SetBackdropBorderColor(unpack(bc))
    else
        f:SetBackdrop(nil)
    end

    -- Keep icon fill inside the border so status border stays visible.
    f.tex:ClearAllPoints()
    f.overlay:ClearAllPoints()
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", bSize, -bSize)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bSize, bSize)
    f.overlay:SetPoint("TOPLEFT", f, "TOPLEFT", bSize, -bSize)
    f.overlay:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bSize, bSize)

    f.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)

    local warnSize = math.max(10, math.floor(size * 0.4))
    f.warnTex:SetSize(warnSize, warnSize)

    local badgeSize = math.max(11, math.floor(size * 0.34))
    local badgeInset = math.max(1, bSize)
    f.countBadge:ClearAllPoints()
    f.countBadge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -badgeInset, badgeInset)
    f.countBadge:SetSize(badgeSize, badgeSize)
    f.countText:SetFont("Fonts\\FRIZQT__.TTF", math.max(7, math.floor(size * 0.22)), "OUTLINE")

    if elem.showLabel then
        f.label:SetPoint("BOTTOM", f, "BOTTOM", 0, -(bSize + 2))
        f.label:Show()
    else
        f.label:Hide()
    end
end

local function SetCountBadge(iconFrame, text)
    if text and text ~= "" then
        iconFrame.countText:SetText(text)
        iconFrame.countBadge:Show()
    else
        iconFrame.countText:SetText("")
        iconFrame.countBadge:Hide()
    end
end

-- =========================================================================
--  SLOT FRAME UPDATE
-- =========================================================================

local function UpdateSlotFrame(iconFrame, slotDef, elem)
    if not slotDef then iconFrame:Hide(); return end

    iconFrame.slotDef = slotDef
    iconFrame:Show()

    local showCount = (elem.showCount ~= false)
    local colorOk      = elem.colorOk      or {0.0, 1.0, 0.2, 1}
    local colorWarn    = elem.colorWarn    or {1.0, 0.15, 0.15, 1}
    local colorNeutral = elem.colorNeutral or {0.4, 0.4, 0.8, 1}

    local function SetOK()
        if iconFrame.tex and iconFrame.tex.SetDesaturated then
            iconFrame.tex:SetDesaturated(false)
        end
        iconFrame.tex:SetVertexColor(1, 1, 1, 1)
        iconFrame.overlay:Hide()
        iconFrame.warnTex:Hide()
        if elem.showBorder ~= false then
            iconFrame:SetBackdropBorderColor(unpack(colorOk))
        end
    end

    local function SetWarn()
        if iconFrame.tex and iconFrame.tex.SetDesaturated then
            iconFrame.tex:SetDesaturated(true)
        end
        iconFrame.tex:SetVertexColor(0.82, 0.82, 0.82, 1)
        iconFrame.overlay:SetColorTexture(0, 0, 0, 0.18)
        iconFrame.overlay:Show()
        iconFrame.warnTex:Hide()
        if elem.showBorder ~= false then
            iconFrame:SetBackdropBorderColor(unpack(colorWarn))
        end
    end

    if slotDef.type == "BUFF" then
        iconFrame.tex:SetTexture(slotDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local active, _, _, stacks = slotDef.checkFn()
        if showCount and slotDef.id == "flask" then
            local cnt = 0
            if active then
                cnt = tonumber(stacks) or 1
                if cnt < 1 then cnt = 1 end
            end
            local col = active and "|cff66ff66" or "|cffff8080"
            SetCountBadge(iconFrame, col .. cnt .. "|r")
        else
            SetCountBadge(iconFrame, "")
        end
        if active then SetOK() else SetWarn() end
        iconFrame.label:SetText(slotDef.label or "")

    elseif slotDef.type == "COUNT" then
        iconFrame.tex:SetTexture(slotDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local count   = slotDef.countFn()
        local minWarn = slotDef.minWarn or 1
        if showCount then
            local col = count >= minWarn and "|cff66ff66" or "|cffff8080"
            SetCountBadge(iconFrame, col .. count .. "|r")
        else
            SetCountBadge(iconFrame, "")
        end
        if count >= minWarn then SetOK() else SetWarn() end
        iconFrame.label:SetText(slotDef.label or "")

    elseif slotDef.type == "TRINKET" then
        local tex = GetTrinketInfo(slotDef.trinketSlot)
        if not tex then
            iconFrame:Hide()
            return
        end
        SetCountBadge(iconFrame, "")
        iconFrame.overlay:Hide()
        iconFrame.warnTex:Hide()
        iconFrame.tex:SetTexture(tex)
        if iconFrame.tex and iconFrame.tex.SetDesaturated then
            iconFrame.tex:SetDesaturated(false)
        end
        iconFrame.tex:SetVertexColor(1, 1, 1, 1)
        if elem.showBorder ~= false then
            iconFrame:SetBackdropBorderColor(unpack(colorNeutral))
        end
        iconFrame.label:SetText(slotDef.label or "")
    end

    iconFrame:SetAlpha(1)
end

-- =========================================================================
--  ICON LAYOUT (shared by preview and live)
-- =========================================================================

local function LayoutIcons(container, slots, elem)
    local size      = elem.iconSize or 32
    local spacing   = elem.spacing or 4
    local direction = elem.direction or "LEFT_TO_RIGHT"

    for i, iconFrame in ipairs(container.iconSlots) do
        if i <= #slots then
            ApplyIconStyle(iconFrame, elem)
            iconFrame:ClearAllPoints()
            local offset = (i - 1) * (size + spacing)
            if direction == "LEFT_TO_RIGHT" then
                iconFrame:SetPoint("LEFT", container, "LEFT", offset, 0)
            elseif direction == "RIGHT_TO_LEFT" then
                iconFrame:SetPoint("RIGHT", container, "RIGHT", -offset, 0)
            elseif direction == "TOP_TO_BOTTOM" then
                iconFrame:SetPoint("TOP", container, "TOP", 0, -offset)
            elseif direction == "BOTTOM_TO_TOP" then
                iconFrame:SetPoint("BOTTOM", container, "BOTTOM", 0, offset)
            end
        else
            iconFrame:Hide()
        end
    end
end

-- =========================================================================
--  PREVIEW MODE (id-based; no index drift)
-- =========================================================================

local PREVIEW_BY_ID = {
    flask       = { icon = "Interface\\Icons\\INV_Potion_93",                   ok = true,  count = 1 },
    food        = { icon = "Interface\\Icons\\INV_Misc_Food_16",               ok = true  },
    rune        = { icon = "Interface\\Icons\\INV_Stone_04",                    ok = false },
    potion      = { icon = "Interface\\Icons\\INV_Potion_92",                 ok = true,  count = 2 },
    healthstone = { icon = "Interface\\Icons\\INV_Stone_04",                  ok = false, count = 0 },
    trinket1    = { icon = "Interface\\Icons\\INV_Jewelry_Trinket_02",         ok = true  },
    trinket2    = { icon = "Interface\\Icons\\INV_Jewelry_Trinket_05",         ok = true  },
}

local function RenderPreview(container, slots, elem)
    LayoutIcons(container, slots, elem)

    local colorOk   = elem.colorOk   or {0.0, 1.0, 0.2, 1}
    local colorWarn = elem.colorWarn or {1.0, 0.15, 0.15, 1}

    for i, iconFrame in ipairs(container.iconSlots) do
        if i <= #slots then
            local slotDef = slots[i]
            iconFrame.slotDef = slotDef

            local p = PREVIEW_BY_ID[slotDef.id] or {}
            local icon = p.icon or slotDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            iconFrame.tex:SetTexture(icon)

            local ok = (p.ok ~= nil) and p.ok or true
            if ok then
                if iconFrame.tex and iconFrame.tex.SetDesaturated then
                    iconFrame.tex:SetDesaturated(false)
                end
                iconFrame.tex:SetVertexColor(1, 1, 1, 1)
                iconFrame.overlay:Hide()
                iconFrame.warnTex:Hide()
                if elem.showBorder ~= false then
                    iconFrame:SetBackdropBorderColor(unpack(colorOk))
                end
            else
                if iconFrame.tex and iconFrame.tex.SetDesaturated then
                    iconFrame.tex:SetDesaturated(true)
                end
                iconFrame.tex:SetVertexColor(0.82, 0.82, 0.82, 1)
                iconFrame.overlay:SetColorTexture(0, 0, 0, 0.18)
                iconFrame.overlay:Show()
                iconFrame.warnTex:Hide()
                if elem.showBorder ~= false then
                    iconFrame:SetBackdropBorderColor(unpack(colorWarn))
                end
            end

            if elem.showCount ~= false and (slotDef.type == "COUNT" or slotDef.id == "flask") then
                local cnt = p.count
                if cnt == nil then cnt = ok and 1 or 0 end
                local minWarn = (slotDef.id == "flask") and 1 or (slotDef.minWarn or 1)
                local col = (cnt >= minWarn) and "|cff66ff66" or "|cffff8080"
                SetCountBadge(iconFrame, col .. cnt .. "|r")
            else
                SetCountBadge(iconFrame, "")
            end

            iconFrame.label:SetText(elem.showLabel and (slotDef.label or "") or "")
            iconFrame:SetAlpha(0.85)
            iconFrame:Show()
        else
            iconFrame:Hide()
        end
    end
end

-- =========================================================================
--  LIVE UPDATE
-- =========================================================================

local UPDATE_INTERVAL = 0.5

local function UpdateContainer(container)
    local elem = container.elem
    if not elem then return end

    local slots = BuildSlotList(elem)
    ManagePool(container, #slots)
    LayoutIcons(container, slots, elem)

    for i, slotDef in ipairs(slots) do
        UpdateSlotFrame(container.iconSlots[i], slotDef, elem)
    end
    for i = #slots + 1, #container.iconSlots do
        container.iconSlots[i]:Hide()
    end
end

-- =========================================================================
--  LOAD / UNLOAD
-- =========================================================================

function PrepChecker:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    container.timeSinceUpdate = 0

    local slots = BuildSlotList(elem)
    ManagePool(container, math.max(#slots, 7))

    container:SetScript("OnUpdate", function(self, elapsed)
        local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false)
                        or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())

        if isUnlocked then
            local previewSlots = BuildSlotList(self.elem)
            ManagePool(self, math.max(#previewSlots, 1))
            RenderPreview(self, previewSlots, self.elem)
            return
        end

        self.timeSinceUpdate = (self.timeSinceUpdate or 0) + elapsed
        if self.timeSinceUpdate >= UPDATE_INTERVAL then
            self.timeSinceUpdate = 0
            UpdateContainer(self)
        end
    end)

    container.eventFrame = CreateFrame("Frame")
    container.eventFrame:RegisterEvent("UNIT_AURA")
    container.eventFrame:RegisterEvent("BAG_UPDATE")
    container.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    container.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    container.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_AURA" then
            local unit = ...
            if unit ~= "player" then return end
        end
        container.timeSinceUpdate = UPDATE_INTERVAL
    end)

    table.insert(PrepChecker.Instances, container)

    container.Unload = function(self)
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
        end
        for i, inst in ipairs(PrepChecker.Instances) do
            if inst == self then table.remove(PrepChecker.Instances, i); break end
        end
    end

    return container
end

-- =========================================================================
--  DIMENSION HELPER (for WidgetForge layout engine)
-- =========================================================================

function PrepChecker:GetDimensions(elem)
    local size      = elem.iconSize or 32
    local spacing   = elem.spacing or 4
    local direction = elem.direction or "LEFT_TO_RIGHT"
    local slots     = BuildSlotList(elem)
    local count     = math.max(#slots, 1)
    local totalLen  = (count * size) + ((count - 1) * spacing)
    if direction == "TOP_TO_BOTTOM" or direction == "BOTTOM_TO_TOP" then
        return size, totalLen
    else
        return totalLen, size
    end
end

-- =========================================================================
--  SETTINGS BUILDER
-- =========================================================================

-- ---------------------------------------------------------------------------
--  Custom ID Manager â€” yardÄ±mcÄ± fonksiyonlar
--
--  elem'de ID'ler ÅŸu ÅŸekilde saklanÄ±r (her slot iÃ§in ayrÄ± string):
--    elem.customFlaskIDs  = "1235057,999999"
--    elem.customFoodIDs   = "..."
--    elem.customRuneIDs   = "..."
--    elem.customPotionIDs = "..."
--    elem.customItemIDs   = "..."
--
--  ParseIDString zaten bu formatÄ± okuyor, biz sadece UI'Ä± gÃ¼zelleÅŸtiriyoruz.
-- ---------------------------------------------------------------------------

-- Slot tanÄ±mlarÄ±: dropdown metni, saklama anahtarÄ±, kÄ±sa renk etiketi
local CUSTOM_ID_SLOTS = {
    { label = "Flask / Phial  (Spell ID)",  key = "customFlaskIDs",  tag = "FLASK",  color = "|cff88ddff" },
    { label = "Food  (Spell ID)",            key = "customFoodIDs",   tag = "FOOD",   color = "|cffaaffaa" },
    { label = "Potion  (Item ID)",           key = "customPotionIDs", tag = "POT",    color = "|cffff9966" },
}

-- VirgÃ¼llÃ¼ string'den ID listesi
local function SplitIDs(str)
    local t = {}
    if not str or str == "" then return t end
    for s in string.gmatch(str, "([^,%s]+)") do
        if tonumber(s) then t[#t + 1] = s end
    end
    return t
end

-- ID listesini virgÃ¼llÃ¼ string'e dÃ¶nÃ¼ÅŸtÃ¼r
local function JoinIDs(t)
    return table.concat(t, ",")
end

-- Belirli bir slot'a ID ekle
local function AddIDToSlot(elem, key, idStr)
    local id = tonumber(idStr)
    if not id then return false end
    local list = SplitIDs(elem[key])
    for _, v in ipairs(list) do
        if tonumber(v) == id then return false end -- zaten var
    end
    list[#list + 1] = tostring(id)
    elem[key] = JoinIDs(list)
    return true
end

-- Belirli bir slot'tan ID sil
local function RemoveIDFromSlot(elem, key, idStr)
    local id = tonumber(idStr)
    if not id then return end
    local list = SplitIDs(elem[key])
    local new = {}
    for _, v in ipairs(list) do
        if tonumber(v) ~= id then new[#new + 1] = v end
    end
    elem[key] = JoinIDs(new)
end

-- ---------------------------------------------------------------------------
--  Havuz (pool) oluÅŸturucu
--  TÃ¼m slot'lardaki kayÄ±tlÄ± ID'leri tek bir scrollable listede gÃ¶sterir.
--  Her satÄ±r: [RENK TAG]  ID  [X butonu]
-- ---------------------------------------------------------------------------
local POOL_ROW_H   = 22
local POOL_MAX_VIS = 8   -- kaÃ§ satÄ±r gÃ¶sterilsin (scroll)

local function ApplyForgeSkinBackdrop(frame, bgColor, borderColor)
    local skin = _G.ForgeSkin
    if not frame or not skin or not skin.ApplyBackdrop then return end

    skin:ApplyBackdrop(frame)

    local bg = bgColor or skin.Colors.button or {0.15, 0.15, 0.15, 0.9}
    local bc = borderColor or skin.Colors.border or {0.2, 0.2, 0.2, 1}
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
end

local function HookForgeSkinButton(btn)
    local skin = _G.ForgeSkin
    if not btn or not skin or btn.__wfForgeSkinHooked then return end
    btn.__wfForgeSkinHooked = true

    local normalBg = skin.Colors.button or {0.15, 0.15, 0.15, 0.9}
    local hoverBg = skin.Colors.buttonHover or {0.25, 0.25, 0.25, 0.9}
    local normalBorder = skin.Colors.border or {0.2, 0.2, 0.2, 1}
    local hoverBorder = skin.Colors.accent or {0, 0.8, 1, 1}

    btn:HookScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(hoverBg[1], hoverBg[2], hoverBg[3], hoverBg[4] or 1)
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(hoverBorder[1], hoverBorder[2], hoverBorder[3], hoverBorder[4] or 1)
        end
    end)

    btn:HookScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(normalBg[1], normalBg[2], normalBg[3], normalBg[4] or 1)
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(normalBorder[1], normalBorder[2], normalBorder[3], normalBorder[4] or 1)
        end
    end)
end

local function BuildPoolWidget(parent, elem, refreshFn, onlyKey, viewRows, innerWidth)
    -- DÄ±ÅŸ Ã§erÃ§eve
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ApplyForgeSkinBackdrop(container, {0.05, 0.05, 0.05, 0.85})

    -- ScrollFrame (ForgeSkin standard)
    local sf, scrollChild
    local maxVis = viewRows or POOL_MAX_VIS
    local contentW = innerWidth or 330

    if _G.ForgeSkin and _G.ForgeSkin.CreateScrollFrame then
        sf, scrollChild = _G.ForgeSkin:CreateScrollFrame(container, contentW, maxVis * POOL_ROW_H)
        sf:SetPoint("TOPLEFT",     container, "TOPLEFT",  4,  -4)
        sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 4)
    else
        sf = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT",     container, "TOPLEFT",  4,  -4)
        sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 4)
        scrollChild = CreateFrame("Frame", nil, sf)
        scrollChild:SetWidth(sf:GetWidth() or 330)
        scrollChild:SetHeight(1)
        sf:SetScrollChild(scrollChild)
    end

    -- TÃ¼m satÄ±r frame'lerini saklayan tablo
    container.rows = {}

    -- Yeniden Ã§iz
    function container:Rebuild()
        -- Eski satÄ±rlarÄ± gizle
        for _, row in ipairs(self.rows) do row:Hide() end
        self.rows = {}

        local y = 0

        for _, slotDef in ipairs(CUSTOM_ID_SLOTS) do
            if (not onlyKey) or slotDef.key == onlyKey then
            local ids = SplitIDs(elem[slotDef.key])
            for _, idStr in ipairs(ids) do
                -- SatÄ±r frame
                local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(POOL_ROW_H)
                row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, -y)
                row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)

                -- Ã‡ift satÄ±r rengi
                if (#self.rows % 2 == 0) then
                    ApplyForgeSkinBackdrop(row, {0.10, 0.10, 0.10, 0.7})
                else
                    ApplyForgeSkinBackdrop(row, {0.08, 0.08, 0.08, 0.65})
                end

                -- Etiket  (TAG renkli + ID)
                local lbl = row:CreateFontString(nil, "OVERLAY")
                local skin = _G.ForgeSkin
                local fontPath = (skin and skin.Constants and skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
                lbl:SetFont(fontPath, 10, "OUTLINE")
                lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
                lbl:SetText(slotDef.color .. "[" .. slotDef.tag .. "]|r  " .. idStr)

                -- [X] sil butonu
                local delBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                delBtn:SetSize(18, 18)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                ApplyForgeSkinBackdrop(delBtn)
                HookForgeSkinButton(delBtn)

                local delTxt = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                delTxt:SetPoint("CENTER", 0, 0)
                delTxt:SetFont(fontPath, 10, "OUTLINE")
                delTxt:SetText("x")
                delTxt:SetTextColor(1, 0.35, 0.35, 1)

                -- Closure iÃ§in local kopyalar
                local captureKey = slotDef.key
                local captureID  = idStr
                delBtn:SetScript("OnClick", function()
                    RemoveIDFromSlot(elem, captureKey, captureID)
                    refreshFn()
                    container:Rebuild()
                end)

                y = y + POOL_ROW_H
                self.rows[#self.rows + 1] = row
                row:Show()
            end
            end
        end

        -- HiÃ§ kayÄ±t yoksa "boÅŸ" mesajÄ±
        if #self.rows == 0 then
            local empty = scrollChild:CreateFontString(nil, "OVERLAY")
            local skin = _G.ForgeSkin
            local fontPath = (skin and skin.Constants and skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
            empty:SetFont(fontPath, 10, "")
            empty:SetTextColor(0.5, 0.5, 0.5, 1)
            empty:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
            empty:SetText("No IDs registered yet.")
            self.rows[1] = empty
            empty:Show()
            y = POOL_ROW_H
        end

        -- ScrollChild yÃ¼ksekliÄŸini gÃ¼ncelle
        local visH = math.min(#self.rows, maxVis) * POOL_ROW_H
        scrollChild:SetHeight(math.max(y, 1))
        container:SetHeight(visH + 8)
    end

    return container
end

-- ---------------------------------------------------------------------------
--  CreateSettings â€” ana fonksiyon
-- ---------------------------------------------------------------------------
function PrepChecker:CreateSettings(parentFrame)
    local f        = parentFrame
    local elem     = f.config
    local barIndex = f.barIndex

    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb

    local function RefreshLive()
        for _, inst in ipairs(PrepChecker.Instances) do
            if inst.elem == elem then UpdateContainer(inst) end
        end
        if barIndex and _G.WidgetForge then
            _G.WidgetForge:RebuildBarComponents(barIndex)
            _G.WidgetForge:UpdateBarValues(barIndex)
        end
        for _, inst in ipairs(PrepChecker.Instances) do
            if inst.elem == elem then
                inst.timeSinceUpdate = UPDATE_INTERVAL
                local isUnlocked = (_G.WidgetForge and _G.WidgetForge.BarsLocked == false)
                               or (_G.EsrefConfigFrame and _G.EsrefConfigFrame:IsShown())
                if isUnlocked then
                    local ps = BuildSlotList(inst.elem)
                    ManagePool(inst, math.max(#ps, 1))
                    RenderPreview(inst, ps, inst.elem)
                end
            end
        end
    end

    -- â”€â”€ GÃ¶rÃ¼nÃ¼r Slotlar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    sb:AddHeader("Visible Slots")
    sb:AddSwitch("showFlask",       "Flask / Phial Buff",        true,  elem, RefreshLive)
    sb:AddSwitch("showFood",        "Well Fed Food Buff",        true,  elem, RefreshLive)
    sb:AddSwitch("showRune",        "Augment Rune Buff",         true,  elem, RefreshLive)
    sb:AddSwitch("showPotion",      "Combat Potion (Inventory)", true,  elem, RefreshLive)
    sb:AddSwitch("showHealthstone", "Healthstone (Inventory)",   true,  elem, RefreshLive)
    sb:AddSwitch("showTrinket1",    "Trinket Slot 1 (Slot 13)",  true,  elem, RefreshLive)
    sb:AddSwitch("showTrinket2",    "Trinket Slot 2 (Slot 14)",  true,  elem, RefreshLive)

    -- â”€â”€ Ä°kon GÃ¶rÃ¼nÃ¼mÃ¼ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    sb:AddHeader("Icon Appearance")
    local dirList = {
        {text = "Left to Right", value = "LEFT_TO_RIGHT"},
        {text = "Right to Left", value = "RIGHT_TO_LEFT"},
        {text = "Top to Bottom", value = "TOP_TO_BOTTOM"},
        {text = "Bottom to Top", value = "BOTTOM_TO_TOP"},
    }
    sb:AddDropdown("direction", "Flow Direction", dirList, "LEFT_TO_RIGHT", elem, RefreshLive)
    sb:AddSlider("iconSize",  "Icon Size",            16, 64,   1,    32,   elem, RefreshLive)
    sb:AddSlider("spacing",   "Icon Spacing",          0, 30,   1,     4,   elem, RefreshLive)
    sb:AddSlider("iconZoom",  "Icon Zoom (Crop)",      0, 0.2, 0.01, 0.07,  elem, RefreshLive)
    sb:AddSwitch("showCount", "Show Count (Pot / HS / Flask)", true,  elem, RefreshLive)
    sb:AddSwitch("showLabel", "Show Label Under Icons", false, elem, RefreshLive)

    -- â”€â”€ KenarlÄ±k & Renkler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    sb:AddHeader("Border & Status Colors")
    sb:AddSwitch("showBorder",  "Show Status Border",        true,  elem, RefreshLive)
    sb:AddSlider("borderSize",  "Border Thickness", 1, 5, 1, 1,    elem, RefreshLive)
    sb:AddColor("colorOk",      "OK Color (active/has item)",   {0.0, 1.0, 0.2, 1},  elem, RefreshLive)
    sb:AddColor("colorWarn",    "Warn Color (missing)",          {1.0, 0.15, 0.15, 1}, elem, RefreshLive)
    sb:AddColor("colorNeutral", "Neutral Color (trinkets)",      {0.4, 0.4, 0.8, 1},  elem, RefreshLive)

    -- â”€â”€ EÅŸikler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    sb:AddHeader("Thresholds")
    sb:AddSlider("potionWarnBelow", "Potion Warning Below (count)", 1, 10, 1, 1, elem, RefreshLive, true)

    sb:Finish()

    -- ======================================================================
    --  Custom ID YÃ¶neticisi  (settings builder bittikten sonra ekleniyor)
    -- ======================================================================
    if not f.content then return end

    -- Match SettingsBuilder grid exactly: col1=10, fullWidth=590
    local SECT_X   = 10
    local PANEL_W  = 590
    -- Start immediately after the settings builder content.
    local curY     = (sb.y or -10) - 10

    -- Fixed-width layout anchor to preserve standard left/right boundaries
    local stdArea = CreateFrame("Frame", nil, f.content)
    stdArea:SetPoint("TOPLEFT", f.content, "TOPLEFT", SECT_X, curY)
    stdArea:SetSize(PANEL_W, 1)
    local sectionY = 0
    local skin = _G.ForgeSkin

    -- â”€â”€ BÃ¶lÃ¼m BaÅŸlÄ±ÄŸÄ± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local sectHdr = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectHdr:SetPoint("TOPLEFT", stdArea, "TOPLEFT", 0, sectionY)
    sectHdr:SetFontObject(GameFontNormalLarge)
    sectHdr:SetText("Custom ID Manager")
    if skin and skin.Colors and skin.Colors.accent then
        sectHdr:SetTextColor(unpack(skin.Colors.accent))
    end
    sectionY = sectionY - 20

    local divLine = f.content:CreateTexture(nil, "ARTWORK")
    divLine:SetHeight(1)
    divLine:SetPoint("TOPLEFT",  stdArea, "TOPLEFT",  0, sectionY)
    divLine:SetPoint("TOPRIGHT", stdArea, "TOPRIGHT", 0, sectionY)
    divLine:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sectionY = sectionY - 10

    -- â”€â”€ Dropdown  (slot tÃ¼rÃ¼ seÃ§ici) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local fontPath = (skin and skin.Constants and skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"

    local panel = CreateFrame("Frame", nil, f.content)
    panel:SetPoint("TOPLEFT", stdArea, "TOPLEFT", 0, sectionY)
    panel:SetPoint("TOPRIGHT", stdArea, "TOPLEFT", PANEL_W, sectionY)
    panel:SetHeight(34)
    local ShowFeedback
    local poolWidgets = {}
    local selectedSlotIdx = 1

    local ddItems = {}
    for i, slotDef in ipairs(CUSTOM_ID_SLOTS) do
        ddItems[#ddItems + 1] = { text = slotDef.tag .. " - " .. slotDef.label, value = i }
    end

    local ddControl
    local GRID_COL_WIDTH = (sb and sb.colWidth) or 285
    local GRID_COL2_X = ((sb and sb.col2) or 305) - ((sb and sb.col1) or 10)
    if skin and skin.CreateDropdown then
        ddControl = skin:CreateDropdown(panel, GRID_COL_WIDTH, ddItems, selectedSlotIdx, function(val)
            selectedSlotIdx = tonumber(val) or 1
            if ddControl and ddControl.text then
                ddControl.text:SetFont(fontPath, 10, "")
            end
        end)
    else
        ddControl = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        ddControl:SetSize(GRID_COL_WIDTH, 24)
        ApplyForgeSkinBackdrop(ddControl, {0.08, 0.08, 0.08, 0.9})
    end
    if ddControl.SetWidth then ddControl:SetWidth(GRID_COL_WIDTH) end
    ddControl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    if ddControl.text then
        ddControl.text:SetFont(fontPath, 10, "")
    end

    local addBtn
    if skin and skin.CreateButton then
        addBtn = skin:CreateButton(panel, "Add ID", 90, 24)
    else
        addBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        addBtn:SetSize(90, 24)
        ApplyForgeSkinBackdrop(addBtn)
        local txt = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("CENTER")
        txt:SetText("Add ID")
    end
    addBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    local ebFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    ebFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", GRID_COL2_X, 0)
    ebFrame:SetPoint("TOPRIGHT", addBtn, "TOPLEFT", -10, 0)
    ebFrame:SetHeight(24)
    ApplyForgeSkinBackdrop(ebFrame, {0.08, 0.08, 0.08, 0.9})

    local eb = CreateFrame("EditBox", nil, ebFrame)
    eb:SetPoint("TOPLEFT",     ebFrame, "TOPLEFT",     5, -3)
    eb:SetPoint("BOTTOMRIGHT", ebFrame, "BOTTOMRIGHT", -5,  3)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(12)
    eb:SetTextInsets(2, 2, 0, 0)

    local placeholder = ebFrame:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(fontPath, 10, "")
    placeholder:SetTextColor(0.45, 0.45, 0.45, 1)
    placeholder:SetPoint("LEFT", ebFrame, "LEFT", 6, 0)
    placeholder:SetText("Enter numeric ID")

    eb:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    sectionY = sectionY - 38

    local feedbackTxt = f.content:CreateFontString(nil, "OVERLAY")
    feedbackTxt:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    feedbackTxt:SetPoint("TOPLEFT", stdArea, "TOPLEFT", 0, sectionY)
    feedbackTxt:SetText("")

    local feedbackTimer = 0
    ShowFeedback = function(msg, r, g, b)
        feedbackTxt:SetText(msg)
        feedbackTxt:SetTextColor(r or 1, g or 1, b or 1, 1)
        feedbackTimer = 2.5
    end

    local feedbackTicker = CreateFrame("Frame", nil, f.content)
    feedbackTicker:SetScript("OnUpdate", function(self, elapsed)
        if feedbackTimer > 0 then
            feedbackTimer = feedbackTimer - elapsed
            if feedbackTimer <= 0 then feedbackTxt:SetText("") end
        end
    end)

    local function RebuildAllPools()
        for _, pw in ipairs(poolWidgets) do
            if pw and pw.Rebuild then pw:Rebuild() end
        end
    end

    local function DoAdd()
        local idStr = eb:GetText()
        if not idStr or idStr == "" then
            ShowFeedback("Please enter an ID first.", 1, 0.6, 0)
            return
        end
        if not tonumber(idStr) then
            ShowFeedback("Invalid numeric ID.", 1, 0.3, 0.3)
            return
        end
        local slotDef = CUSTOM_ID_SLOTS[selectedSlotIdx]
        if not slotDef then return end
        local added = AddIDToSlot(elem, slotDef.key, idStr)
        if added then
            ShowFeedback("Added " .. idStr .. " to " .. slotDef.tag .. ".", 0.3, 1, 0.3)
            eb:SetText("")
            RebuildAllPools()
            RefreshLive()
        else
            ShowFeedback("That ID is already in the list.", 1, 0.8, 0.2)
        end
    end

    addBtn:SetScript("OnClick", DoAdd)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        DoAdd()
    end)

    sectionY = sectionY - 16

    local columns = {
        { title = "Flask IDs",  key = "customFlaskIDs" },
        { title = "Food IDs",   key = "customFoodIDs" },
        { title = "Potion IDs", key = "customPotionIDs" },
    }

    local gap = 10
    local listAvailW = PANEL_W
    local colW = math.floor((listAvailW - gap * 2) / 3)
    local poolRows = 4

    local sectionTopY = sectionY
    for i, col in ipairs(columns) do
        local x = (i - 1) * (colW + gap)
        local hdr = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hdr:SetPoint("TOPLEFT", stdArea, "TOPLEFT", x, sectionTopY)
        hdr:SetText(col.title)
    end

    local poolsTopY = sectionTopY - 18
    for i, col in ipairs(columns) do
        local x = (i - 1) * (colW + gap)
        local pool = BuildPoolWidget(f.content, elem, RefreshLive, col.key, poolRows, colW - 8)
        pool:SetPoint("TOPLEFT", stdArea, "TOPLEFT", x, poolsTopY)
        pool:SetWidth(colW)
        pool:Rebuild()
        poolWidgets[#poolWidgets + 1] = pool
    end

    local poolH = (poolRows * POOL_ROW_H) + 8
    sectionY = poolsTopY - poolH - 10

    local helpTxt = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpTxt:SetPoint("TOPLEFT", stdArea, "TOPLEFT", 0, sectionY)
    helpTxt:SetTextColor(0.5, 0.5, 0.5, 1)
    helpTxt:SetJustifyH("LEFT")
    helpTxt:SetWidth(listAvailW)
    helpTxt:SetText(
        "To find Spell IDs:\n" ..
        "/run for i=1,40 do local d=C_UnitAuras.GetBuffDataByIndex(\"player\",i) if d then print(d.spellId, d.name) end end\n" ..
        "Run the macro after you gain the buff."
    )
    sectionY = sectionY - 42

    -- Merge builder depth + custom section depth for final canvas height.
    curY = (sb.y or -10) + sectionY

    -- Ä°Ã§erik yÃ¼ksekliÄŸini ayarla
    if f.content.SetHeight then
        f.content:SetHeight(math.abs(curY) + 40)
    end
end
