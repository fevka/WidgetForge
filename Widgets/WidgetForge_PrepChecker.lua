
local addonName, addonTable = ...
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.PrepChecker = {}
local PrepChecker = _G.WidgetForge.PrepChecker
addonTable.PrepChecker = PrepChecker
local L = WFL
PrepChecker.Instances = {}
PrepChecker.FlaskBuffIDs = {
    1235057, 
    1235108, 
    1235110, 
    1235111, 
    1239355, 
    1236763, 
    1239755, 
}
PrepChecker.FoodBuffIDs = {
}
PrepChecker.RuneBuffIDs = {
    1264426, 
    1234969, 
}
PrepChecker.PotionItemIDs = {
    241289, 
    241290, 
    241292, 
    241293, 
    241296, 
    241297, 
    241309, 
    241310, 
    241300, 
    241301, 
    241304, 
    241305, 
}
PrepChecker.HealthstoneItemID = 5512
PrepChecker.FlaskItemIDs = PrepChecker.FlaskItemIDs or {}
PrepChecker.FoodItemIDs = PrepChecker.FoodItemIDs or {}
local function GetAugmentRuneIcon()
    local runeItemIDs = { 259085, 243191 } 
    if C_Item and C_Item.GetItemIconByID then
        for _, itemID in ipairs(runeItemIDs) do
            local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
            if ok and icon then return icon end
        end
    end
    return "Interface\\Icons\\INV_Misc_Rune_01"
end
PrepChecker.AugmentRuneIcon = GetAugmentRuneIcon()
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
local function GetTrinketInfo(slot)
    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not itemLink then return nil, nil, nil end
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
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
local function FindBuffByIDs(spellIDs)
    if not C_UnitAuras then return false end
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
local function SafeGetItemIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
    return nil
end
local function SafeGetItemName(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and name then return name end
    end
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok and name then return name end
    end
    return L("PREPCHECKER_ITEM_ID", tostring(itemID))
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
local function GetPotionCount(itemIDs)
    local total = 0
    for _, id in ipairs(itemIDs) do
        total = total + SafeGetItemCount(id)
    end
    return total
end
local function BuildItemBreakdown(itemIDs)
    local rows = {}
    if not itemIDs then return rows end
    for _, id in ipairs(itemIDs) do
        local count = SafeGetItemCount(id)
        rows[#rows + 1] = {
            id = id,
            count = count,
            icon = SafeGetItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark",
            name = SafeGetItemName(id),
        }
    end
    return rows
end
local function GetPrimaryOwnedItem(itemIDs)
    local rows = BuildItemBreakdown(itemIDs)
    local primary
    local total = 0
    for _, row in ipairs(rows) do
        local c = row.count or 0
        if c > 0 then
            total = total + c
            if not primary then
                primary = row
            end
        end
    end
    return primary, total, rows
end
local function CancelIconHoverHide(iconFrame)
    if iconFrame.hoverHideTimer and iconFrame.hoverHideTimer.Cancel then
        iconFrame.hoverHideTimer:Cancel()
    end
    iconFrame.hoverHideTimer = nil
    if UIFrameFadeRemoveFrame and iconFrame.hoverPanel then
        UIFrameFadeRemoveFrame(iconFrame.hoverPanel)
        iconFrame.hoverPanel:SetAlpha(1)
    end
end
local function ScheduleIconHoverHide(iconFrame, delay)
    if iconFrame.hoverHideTimer then return end
    CancelIconHoverHide(iconFrame)
    local hideDelay = delay or 0.5
    local function doHide()
        if iconFrame.hoveringIcon or iconFrame.hoveringPanel then return end
        if not iconFrame.hoverPanel then return end
        if UIFrameFadeOut then
            UIFrameFadeOut(iconFrame.hoverPanel, 0.2, iconFrame.hoverPanel:GetAlpha() or 1, 0)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.14, function()
                    if not iconFrame.hoveringIcon and not iconFrame.hoveringPanel and iconFrame.hoverPanel then
                        iconFrame.hoverPanel:Hide()
                        iconFrame.hoverPanel:SetAlpha(1)
                    end
                end)
            else
                iconFrame.hoverPanel:Hide()
                iconFrame.hoverPanel:SetAlpha(1)
            end
        else
            iconFrame.hoverPanel:Hide()
        end
    end
    if C_Timer and C_Timer.NewTimer then
        iconFrame.hoverHideTimer = C_Timer.NewTimer(hideDelay, doHide)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(hideDelay, doHide)
    else
        doHide()
    end
end
local function EnsureHoverCell(iconFrame, index)
    local cell = iconFrame.hoverIcons[index]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, iconFrame.hoverPanel, "BackdropTemplate")
    cell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    cell:SetBackdropColor(0, 0, 0, 0)
    cell:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    cell.tex = cell:CreateTexture(nil, "ARTWORK")
    cell.tex:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
    cell.tex:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
    cell.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.count = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cell.count:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
    cell.count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(c)
        iconFrame.hoveringPanel = true
        CancelIconHoverHide(iconFrame)
        GameTooltip:SetOwner(c, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(c.itemName or L("PREPCHECKER_ITEM_ID", tostring(c.itemID or "")), 1, 1, 1)
        GameTooltip:AddLine(L("PREPCHECKER_COUNT", tonumber(c.itemCount or 0) or 0), 0.75, 0.9, 1)
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function(c)
        if GameTooltip:IsOwned(c) then GameTooltip:Hide() end
        iconFrame.hoveringPanel = false
        ScheduleIconHoverHide(iconFrame, 0.5)
    end)
    iconFrame.hoverIcons[index] = cell
    return cell
end
local function UpdateIconHoverPanel(iconFrame, slotDef)
    if not slotDef or not slotDef.itemIDs or #slotDef.itemIDs == 0 then
        iconFrame.hoverPanel:Hide()
        iconFrame.hoverSignature = nil
        return false
    end
    local allItems = BuildItemBreakdown(slotDef.itemIDs)
    local items = {}
    local skipPrimaryID = iconFrame.primaryItemID
    for _, row in ipairs(allItems) do
        if (row.count or 0) > 0 and row.id ~= skipPrimaryID then
            items[#items + 1] = row
        end
    end
    if #items == 0 then
        iconFrame.hoverPanel:Hide()
        iconFrame.hoverSignature = nil
        return false
    end
    local elem = iconFrame:GetParent() and iconFrame:GetParent().elem or {}
    local direction = elem.direction or "LEFT_TO_RIGHT"
    local isVerticalFlow = (direction == "TOP_TO_BOTTOM" or direction == "BOTTOM_TO_TOP")
    local bSize = (elem.showBorder ~= false) and (elem.borderSize or 1) or 0
    local okColor = elem.colorOk or {0.0, 1.0, 0.2, 1}
    local countFontSize = elem.countFontSize or 9
    local iconSize = math.max(14, math.floor((iconFrame:GetWidth() or 32) - 2))
    local overlap = math.floor(iconSize * 0.32)
    local step = math.max(6, iconSize - overlap)
    local pad = 4
    local panelW, panelH
    if isVerticalFlow then
        panelW = iconSize + (pad * 2)
        panelH = iconSize + ((#items - 1) * step) + (pad * 2)
        iconFrame.hoverPanel:ClearAllPoints()
        iconFrame.hoverPanel:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    else
        panelW = iconSize + ((#items - 1) * step) + (pad * 2)
        panelH = iconSize + (pad * 2)
        iconFrame.hoverPanel:ClearAllPoints()
        iconFrame.hoverPanel:SetPoint("BOTTOMLEFT", iconFrame, "TOPLEFT", 0, 6)
    end
    local sigParts = { tostring(direction), tostring(iconSize), tostring(#items) }
    for _, row in ipairs(items) do
        sigParts[#sigParts + 1] = tostring(row.id) .. ":" .. tostring(row.count or 0)
    end
    local signature = table.concat(sigParts, "|")
    if iconFrame.hoverPanel:IsShown() and iconFrame.hoverSignature == signature then return true end
    iconFrame.hoverSignature = signature
    iconFrame.hoverPanel:SetSize(panelW, panelH)
    for i, row in ipairs(items) do
        local cell = EnsureHoverCell(iconFrame, i)
        cell:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = (bSize > 0) and bSize or 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        cell:SetBackdropBorderColor(okColor[1], okColor[2], okColor[3], okColor[4] or 1)
        cell:SetSize(iconSize, iconSize)
        cell:ClearAllPoints()
        if isVerticalFlow then
            cell:SetPoint("TOP", iconFrame.hoverPanel, "TOP", 0, -(pad + ((i - 1) * step)))
        else
            cell:SetPoint("LEFT", iconFrame.hoverPanel, "LEFT", pad + ((i - 1) * step), 0)
        end
        cell.tex:SetTexture(row.icon)
        if cell.tex.SetDesaturated then cell.tex:SetDesaturated(false) end
        cell.count:SetText(tostring(row.count or 0))
        cell.count:SetTextColor(1, 1, 1, 1)
        cell.count:SetFont("Fonts\\FRIZQT__.TTF", countFontSize, "OUTLINE")
        cell.itemID = row.id
        cell.itemName = row.name
        cell.itemCount = row.count or 0
        cell:Show()
        cell:SetAlpha(0)
        if UIFrameFadeIn then
            local d = (i - 1) * 0.03
            C_Timer.After(d, function()
                if cell and cell:IsShown() then
                    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(cell) end
                    UIFrameFadeIn(cell, 0.14, cell:GetAlpha() or 0, 1)
                end
            end)
        else
            cell:SetAlpha(1)
        end
    end
    for i = #items + 1, #iconFrame.hoverIcons do
        iconFrame.hoverIcons[i]:Hide()
    end
    iconFrame.hoverPanel:SetAlpha(1)
    iconFrame.hoverPanel:Show()
    return true
end
local function BuildSlotList(elem)
    local slots = {}
    local customFlaskIDs  = ParseIDString(elem.customFlaskIDs)
    local customFoodIDs   = ParseIDString(elem.customFoodIDs)
    local customRuneIDs   = ParseIDString(elem.customRuneIDs)
    local customPotionIDs = ParseIDString(elem.customPotionIDs)
    local customItemIDs   = ParseIDString(elem.customItemIDs)
    local allFlaskIDs  = MergeIDs(PrepChecker.FlaskBuffIDs, customFlaskIDs)
    local allFlaskItemIDs = MergeIDs(PrepChecker.FlaskItemIDs, customFlaskIDs)
    local allFoodIDs   = MergeIDs(PrepChecker.FoodBuffIDs, customFoodIDs)
    local allFoodItemIDs = MergeIDs(PrepChecker.FoodItemIDs, customFoodIDs)
    local allRuneIDs   = MergeIDs(PrepChecker.RuneBuffIDs, customRuneIDs)
    local allPotionIDs = MergeIDs(PrepChecker.PotionItemIDs, customPotionIDs)
    if elem.showFlask ~= false then
        table.insert(slots, {
            id = "flask", label = "Flask",
            icon = "Interface\\Icons\\INV_Potion_93",
            type = "BUFF",
            checkFn = function() return IsFlaskActive(allFlaskIDs) end,
            countFn = function() return GetPotionCount(allFlaskItemIDs) end,
            itemIDs = allFlaskItemIDs,
            tooltip = "Flask / Phial buff status",
        })
    end
    if elem.showFood ~= false then
        table.insert(slots, {
            id = "food", label = "Food",
            icon = "Interface\\Icons\\INV_Misc_Food_16",
            type = "BUFF",
            checkFn = function() return IsFoodActive(allFoodIDs) end,
            countFn = function() return GetPotionCount(allFoodItemIDs) end,
            itemIDs = allFoodItemIDs,
            tooltip = "Well Fed buff status",
        })
    end
    if elem.showRune ~= false then
        table.insert(slots, {
            id = "rune", label = "Rune",
            icon = PrepChecker.AugmentRuneIcon or "Interface\\Icons\\INV_Misc_Rune_01",
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
            itemIDs = allPotionIDs,
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
            itemIDs = MergeIDs({PrepChecker.HealthstoneItemID}, customItemIDs),
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
    f.hoverPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.hoverPanel:SetFrameStrata("TOOLTIP")
    f.hoverPanel:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 6)
    f.hoverPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f.hoverPanel:SetBackdropColor(0, 0, 0, 0)
    f.hoverPanel:SetBackdropBorderColor(0, 0, 0, 0)
    f.hoverPanel:EnableMouse(true)
    f.hoverPanel:Hide()
    f.hoverIcons = {}
    f.hoveringIcon = false
    f.hoveringPanel = false
    f.hoverHideTimer = nil
    f.hoverSignature = nil
    local function CancelHoverHide(self) CancelIconHoverHide(self) end
    local function ScheduleHoverHide(self) ScheduleIconHoverHide(self, 0.5) end
    local function UpdateHoverPanel(self, def) UpdateIconHoverPanel(self, def) end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if self.isPreview then
            if self.hoverPanel then self.hoverPanel:Hide() end
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            return
        end
        self.hoveringIcon = true
        CancelHoverHide(self)
        if not self.slotDef then return end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        local opened = UpdateHoverPanel(self, self.slotDef)
        if opened then
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            return
        end
        if self.primaryItemID then
            local elem = self:GetParent() and self:GetParent().elem or {}
            local direction = elem.direction or "LEFT_TO_RIGHT"
            local isVerticalFlow = (direction == "TOP_TO_BOTTOM" or direction == "BOTTOM_TO_TOP")
            GameTooltip:SetOwner(self, isVerticalFlow and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.primaryItemName or L("PREPCHECKER_ITEM_ID", tostring(self.primaryItemID)), 1, 1, 1)
            GameTooltip:AddLine(L("PREPCHECKER_COUNT", tonumber(self.primaryItemCount or 0) or 0), 0.75, 0.9, 1)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        self.hoveringIcon = false
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        ScheduleHoverHide(self)
    end)
    f.hoverPanel:SetScript("OnEnter", function()
        f.hoveringPanel = true
        CancelHoverHide(f)
    end)
    f.hoverPanel:SetScript("OnLeave", function()
        if GameTooltip:IsOwned(f.hoverPanel) then GameTooltip:Hide() end
        f.hoveringPanel = false
        ScheduleHoverHide(f)
    end)
    return f
end
local function ManagePool(container, count)
    container.iconSlots = container.iconSlots or {}
    while #container.iconSlots < count do
        local f = CreateIconSlotFrame(container)
        f:Hide()
        table.insert(container.iconSlots, f)
    end
end
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
    f.tex:ClearAllPoints()
    f.overlay:ClearAllPoints()
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", bSize, -bSize)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bSize, bSize)
    f.overlay:SetPoint("TOPLEFT", f, "TOPLEFT", bSize, -bSize)
    f.overlay:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bSize, bSize)
    f.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    local badgeSize = math.max(11, math.floor(size * 0.34))
    local badgeInset = math.max(1, bSize)
    f.countBadge:ClearAllPoints()
    f.countBadge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -badgeInset, badgeInset)
    f.countBadge:SetSize(badgeSize, badgeSize)
    local countFontSize = elem.countFontSize or math.max(7, math.floor(size * 0.22))
    f.countText:SetFont("Fonts\\FRIZQT__.TTF", countFontSize, "OUTLINE")
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
local function UpdateSlotFrame(iconFrame, slotDef, elem)
    if not slotDef then iconFrame:Hide(); return end
    iconFrame.slotDef = slotDef
    iconFrame.isPreview = false
    iconFrame.primaryItemID = nil
    iconFrame.primaryItemName = nil
    iconFrame.primaryItemCount = nil
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
        if elem.showBorder ~= false then
            iconFrame:SetBackdropBorderColor(unpack(colorWarn))
        end
    end
    if slotDef.type == "BUFF" then
        local primary, totalOwned = nil, 0
        if slotDef.itemIDs and #slotDef.itemIDs > 0 then
            primary, totalOwned = GetPrimaryOwnedItem(slotDef.itemIDs)
        end
        if primary and primary.icon then
            iconFrame.tex:SetTexture(primary.icon)
            iconFrame.primaryItemID = primary.id
            iconFrame.primaryItemName = primary.name
            iconFrame.primaryItemCount = primary.count
        else
            iconFrame.tex:SetTexture(slotDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        local active, _, _, stacks = slotDef.checkFn()
        local isConsumableBuff = (slotDef.id == "flask" or slotDef.id == "food")
        local cnt = (primary and primary.count) or 0
        if showCount and isConsumableBuff then
            local col = cnt > 0 and "|cff66ff66" or "|cffff8080"
            SetCountBadge(iconFrame, col .. cnt .. "|r")
        else
            SetCountBadge(iconFrame, "")
        end
        if isConsumableBuff and totalOwned > 0 then
            if iconFrame.tex and iconFrame.tex.SetDesaturated then
                iconFrame.tex:SetDesaturated(false)
            end
            iconFrame.tex:SetVertexColor(1, 1, 1, 1)
            iconFrame.overlay:Hide()
            if elem.showBorder ~= false then
                iconFrame:SetBackdropBorderColor(unpack(colorOk))
            end
            iconFrame.label:SetText(slotDef.label or "")
            iconFrame:SetAlpha(1)
            return
        else
            if showCount and slotDef.id == "flask" then
                local stackCnt = 0
                if active then
                    stackCnt = tonumber(stacks) or 1
                    if stackCnt < 1 then stackCnt = 1 end
                end
                local col = active and "|cff66ff66" or "|cffff8080"
                SetCountBadge(iconFrame, col .. stackCnt .. "|r")
            end
        end
        if active then SetOK() else SetWarn() end
        iconFrame.label:SetText(slotDef.label or "")
    elseif slotDef.type == "COUNT" then
        local primary, totalOwned = nil, nil
        if slotDef.itemIDs and #slotDef.itemIDs > 0 then
            primary, totalOwned = GetPrimaryOwnedItem(slotDef.itemIDs)
        end
        if primary and primary.icon then
            iconFrame.tex:SetTexture(primary.icon)
            iconFrame.primaryItemID = primary.id
            iconFrame.primaryItemName = primary.name
            iconFrame.primaryItemCount = primary.count
        else
            iconFrame.tex:SetTexture(slotDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        local count = (primary and primary.count) or (slotDef.countFn and slotDef.countFn() or 0)
        local statusCount = (totalOwned ~= nil) and totalOwned or count
        local minWarn = slotDef.minWarn or 1
        if showCount then
            local col = count >= minWarn and "|cff66ff66" or "|cffff8080"
            SetCountBadge(iconFrame, col .. count .. "|r")
        else
            SetCountBadge(iconFrame, "")
        end
        if statusCount >= minWarn then SetOK() else SetWarn() end
        iconFrame.label:SetText(slotDef.label or "")
    elseif slotDef.type == "TRINKET" then
        local tex = GetTrinketInfo(slotDef.trinketSlot)
        if not tex then
            iconFrame:Hide()
            return
        end
        SetCountBadge(iconFrame, "")
        iconFrame.overlay:Hide()
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
local PREVIEW_BY_ID = {
    flask       = { icon = "Interface\\Icons\\INV_Potion_93",                   ok = true,  count = 1 },
    food        = { icon = "Interface\\Icons\\INV_Misc_Food_16",               ok = true,  count = 3 },
    rune        = { icon = PrepChecker.AugmentRuneIcon or "Interface\\Icons\\INV_Misc_Rune_01", ok = false },
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
            iconFrame.isPreview = true
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
                if elem.showBorder ~= false then
                    iconFrame:SetBackdropBorderColor(unpack(colorWarn))
                end
            end
            if elem.showCount ~= false and (slotDef.type == "COUNT" or slotDef.id == "flask" or slotDef.id == "food") then
                local cnt = p.count
                if cnt == nil then cnt = ok and 1 or 0 end
                local minWarn = ((slotDef.id == "flask" or slotDef.id == "food") and 1) or (slotDef.minWarn or 1)
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
local CUSTOM_ID_SLOTS = {
    { label = "Flask / Phial  (Spell ID)",  key = "customFlaskIDs",  tag = "FLASK",  color = "|cff88ddff" },
    { label = "Food  (Spell ID)",            key = "customFoodIDs",   tag = "FOOD",   color = "|cffaaffaa" },
    { label = "Potion  (Item ID)",           key = "customPotionIDs", tag = "POT",    color = "|cffff9966" },
}
local function SplitIDs(str)
    local t = {}
    if not str or str == "" then return t end
    for s in string.gmatch(str, "([^,%s]+)") do
        if tonumber(s) then t[#t + 1] = s end
    end
    return t
end
local function JoinIDs(t)
    return table.concat(t, ",")
end
local function AddIDToSlot(elem, key, idStr)
    local id = tonumber(idStr)
    if not id then return false end
    local list = SplitIDs(elem[key])
    for _, v in ipairs(list) do
        if tonumber(v) == id then return false end 
    end
    list[#list + 1] = tostring(id)
    elem[key] = JoinIDs(list)
    return true
end
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
local POOL_ROW_H   = 22
local POOL_MAX_VIS = 8   
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
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ApplyForgeSkinBackdrop(container, {0.05, 0.05, 0.05, 0.85})
    local sf, scrollChild
    local maxVis = viewRows or POOL_MAX_VIS
    local contentW = innerWidth or 330
    local leftInset = 4
    local rightInsetForge = 0   
    local rightInsetFallback = -19 
    if _G.ForgeSkin and _G.ForgeSkin.CreateScrollFrame then
        sf, scrollChild = _G.ForgeSkin:CreateScrollFrame(container, contentW, maxVis * POOL_ROW_H)
        sf:SetPoint("TOPLEFT",     container, "TOPLEFT",  leftInset,  -4)
        sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", rightInsetForge, 4)
    else
        sf = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT",     container, "TOPLEFT",  leftInset,  -4)
        sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", rightInsetFallback, 4)
        scrollChild = CreateFrame("Frame", nil, sf)
        scrollChild:SetWidth(sf:GetWidth() or 330)
        scrollChild:SetHeight(1)
        sf:SetScrollChild(scrollChild)
    end
    container.rows = {}
    function container:Rebuild()
        for _, row in ipairs(self.rows) do row:Hide() end
        self.rows = {}
        local y = 0
        for _, slotDef in ipairs(CUSTOM_ID_SLOTS) do
            if (not onlyKey) or slotDef.key == onlyKey then
            local ids = SplitIDs(elem[slotDef.key])
            for _, idStr in ipairs(ids) do
                local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(POOL_ROW_H)
                row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, -y)
                row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
                if (#self.rows % 2 == 0) then
                    ApplyForgeSkinBackdrop(row, {0.10, 0.10, 0.10, 0.7})
                else
                    ApplyForgeSkinBackdrop(row, {0.08, 0.08, 0.08, 0.65})
                end
                local lbl = row:CreateFontString(nil, "OVERLAY")
                local skin = _G.ForgeSkin
                local fontPath = (skin and skin.Constants and skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
                lbl:SetFont(fontPath, 10, "OUTLINE")
                lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
                lbl:SetText(slotDef.color .. "[" .. slotDef.tag .. "]|r  " .. idStr)
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
        if #self.rows == 0 then
            local empty = scrollChild:CreateFontString(nil, "OVERLAY")
            local skin = _G.ForgeSkin
            local fontPath = (skin and skin.Constants and skin.Constants.FONT_NORMAL) or "Fonts\\FRIZQT__.TTF"
            empty:SetFont(fontPath, 10, "")
            empty:SetTextColor(0.5, 0.5, 0.5, 1)
            empty:SetPoint("CENTER", scrollChild, "CENTER", 0, 0)
            empty:SetText(L("MSG_NO_IDS_REGISTERED_YET"))
            self.rows[1] = empty
            empty:Show()
            y = POOL_ROW_H
        end
        local visH = math.min(#self.rows, maxVis) * POOL_ROW_H
        scrollChild:SetHeight(math.max(y, 1))
        container:SetHeight(visH + 8)
    end
    return container
end
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
    sb:AddHeader(L("HEADER_VISIBLE_SLOTS"))
    sb:AddSwitch("showFlask",       L("LABEL_FLASK_PHIAL_BUFF"),        true,  elem, RefreshLive)
    sb:AddSwitch("showFood",        L("LABEL_WELL_FED_FOOD_BUFF"),      true,  elem, RefreshLive)
    sb:AddSwitch("showRune",        L("LABEL_AUGMENT_RUNE_BUFF"),       true,  elem, RefreshLive)
    sb:AddSwitch("showPotion",      L("LABEL_COMBAT_POTION_INVENTORY"), true,  elem, RefreshLive)
    sb:AddSwitch("showHealthstone", L("LABEL_HEALTHSTONE_INVENTORY"),   true,  elem, RefreshLive)
    sb:AddSwitch("showTrinket1",    L("LABEL_TRINKET_SLOT_1"),          true,  elem, RefreshLive)
    sb:AddSwitch("showTrinket2",    L("LABEL_TRINKET_SLOT_2"),          true,  elem, RefreshLive)
    sb:AddHeader(L("HEADER_ICON_APPEARANCE"))
    local dirList = {
        {text = L("OPTION_LEFT_TO_RIGHT"), value = "LEFT_TO_RIGHT"},
        {text = L("OPTION_RIGHT_TO_LEFT"), value = "RIGHT_TO_LEFT"},
        {text = L("OPTION_TOP_TO_BOTTOM"), value = "TOP_TO_BOTTOM"},
        {text = L("OPTION_BOTTOM_TO_TOP"), value = "BOTTOM_TO_TOP"},
    }
    sb:AddDropdown("direction", L("LABEL_FLOW_DIRECTION"), dirList, "LEFT_TO_RIGHT", elem, RefreshLive)
    sb:AddSlider("iconSize",  L("LABEL_ICON_SIZE"),          16, 64,   1,    32,   elem, RefreshLive)
    sb:AddSlider("spacing",   L("LABEL_ICON_SPACING"),        0, 30,   1,     4,   elem, RefreshLive)
    sb:AddSlider("iconZoom",  L("LABEL_ICON_ZOOM_CROP"),      0, 0.2, 0.01, 0.07,  elem, RefreshLive)
    sb:AddSwitch("showCount", L("LABEL_SHOW_COUNT"), true,  elem, RefreshLive)
    sb:AddSwitch("showLabel", L("LABEL_SHOW_LABEL_UNDER_ICONS"), false, elem, RefreshLive)
    sb:AddHeader(L("HEADER_BORDER_STATUS_COLORS"))
    sb:AddSwitch("showBorder",  L("LABEL_SHOW_STATUS_BORDER"),      true,  elem, RefreshLive)
    sb:AddSlider("borderSize",  L("LABEL_BORDER_THICKNESS"), 1, 5, 1, 1,   elem, RefreshLive)
    sb:AddColor("colorOk",      L("LABEL_OK_COLOR_ACTIVE_HAS_ITEM"), {0.0, 1.0, 0.2, 1},  elem, RefreshLive)
    sb:AddColor("colorWarn",    L("LABEL_WARN_COLOR_MISSING"),       {1.0, 0.15, 0.15, 1}, elem, RefreshLive)
    sb:AddColor("colorNeutral", L("LABEL_NEUTRAL_COLOR_TRINKETS"),   {0.4, 0.4, 0.8, 1},  elem, RefreshLive)
    sb:AddHeader(L("HEADER_THRESHOLDS"))
    sb:AddSlider("potionWarnBelow", L("LABEL_POTION_WARNING_BELOW"), 1, 10, 1, 1, elem, RefreshLive)
    sb:AddSlider("countFontSize", L("LABEL_COUNT_FONT_SIZE"), 7, 20, 1, 9, elem, RefreshLive)
    sb:Finish()
    if not f.content then return end
    local SECT_X   = 10
    local PANEL_W  = 590
    local curY     = (sb.y or -10) - 10
    local stdArea = CreateFrame("Frame", nil, f.content)
    stdArea:SetPoint("TOPLEFT", f.content, "TOPLEFT", SECT_X, curY)
    stdArea:SetSize(PANEL_W, 1)
    local sectionY = 0
    local skin = _G.ForgeSkin
    local sectHdr = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectHdr:SetPoint("TOPLEFT", stdArea, "TOPLEFT", 0, sectionY)
    sectHdr:SetFontObject(GameFontNormalLarge)
    sectHdr:SetText(L("HEADER_CUSTOM_ID_MANAGER"))
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
        addBtn = skin:CreateButton(panel, L("BUTTON_ADD_ID"), 90, 24)
    else
        addBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        addBtn:SetSize(90, 24)
        ApplyForgeSkinBackdrop(addBtn)
        local txt = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("CENTER")
        txt:SetText(L("BUTTON_ADD_ID"))
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
    placeholder:SetText(L("PLACEHOLDER_ENTER_NUMERIC_ID"))
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
            ShowFeedback(L("MSG_ENTER_ID_FIRST"), 1, 0.6, 0)
            return
        end
        if not tonumber(idStr) then
            ShowFeedback(L("MSG_INVALID_NUMERIC_ID"), 1, 0.3, 0.3)
            return
        end
        local slotDef = CUSTOM_ID_SLOTS[selectedSlotIdx]
        if not slotDef then return end
        local added = AddIDToSlot(elem, slotDef.key, idStr)
        if added then
            ShowFeedback(string.format(L("MSG_ADDED_ID_TO_SLOT"), idStr, slotDef.tag), 0.3, 1, 0.3)
            eb:SetText("")
            RebuildAllPools()
            RefreshLive()
        else
            ShowFeedback(L("MSG_ID_ALREADY_IN_LIST"), 1, 0.8, 0.2)
        end
    end
    addBtn:SetScript("OnClick", DoAdd)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        DoAdd()
    end)
    sectionY = sectionY - 16
    local columns = {
        { title = L("COLUMN_FLASK_IDS"),  key = "customFlaskIDs" },
        { title = L("COLUMN_FOOD_IDS"),   key = "customFoodIDs" },
        { title = L("COLUMN_POTION_IDS"), key = "customPotionIDs" },
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
    sectionY = poolsTopY - poolH
    curY = (sb.y or -10) + sectionY
    local function ApplyFinalContentHeight()
        if not f or not f.content or not f.content.SetHeight or not stdArea then return end
        local contentTop = f.content:GetTop()
        local areaBottom = stdArea:GetBottom()
        if contentTop and areaBottom then
            local h = math.max(1, math.floor((contentTop - areaBottom) + 8))
            f.content:SetHeight(h)
        else
            f.content:SetHeight(math.abs(curY) + 4)
        end
    end
    ApplyFinalContentHeight()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyFinalContentHeight)
    end
end
