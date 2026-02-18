local addonName, addonTable = ...
local Skin = ForgeSkin
local Config = ForgeConfig

WidgetForge = {}
local Bars = {} 
function WidgetForge:GetBarFrames() return Bars end

-- Spec Data moved to WidgetConstants.lua

-- Icons for Stats
WidgetForge.StatIcons = {
    ["FPS"] = "Interface\\Icons\\Spell_Shadow_Teleport",
    ["MS"] = "Interface\\Icons\\Spell_Nature_TimeStop",
    ["Clock"] = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    ["RAM"] = "Interface\\Icons\\INV_Gizmo_02",
    ["Durability"] = "Interface\\Icons\\INV_Chest_Chain_04",
    ["Bag Space"] = "Interface\\Icons\\INV_Misc_Bag_08",
    ["Gold"] = "Interface\\Icons\\INV_Misc_Coin_02",
    ["Zone"] = "Interface\\Icons\\INV_Misc_Map02",
    ["Coords"] = "Interface\\Icons\\INV_Misc_Map02",
    ["Mythic+ Dashboard"] = "Interface\\Icons\\Achievement_GuildPerk_MobileBanking",
    ["Item Level"] = "Interface\\Icons\\INV_Helmet_04",
    ["XP"] = "Interface\\Icons\\Spell_Holy_DivineProvidence",
    ["Combat Timer"] = "Interface\\Icons\\INV_Misc_PocketWatch_02",
    ["Strength"] = "Interface\\Icons\\Spell_Nature_Strength",
    ["Agility"] = "Interface\\Icons\\Spell_Nature_Agility",
    ["Intellect"] = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    ["Stamina"] = "Interface\\Icons\\Spell_Nature_UnyeildingStamina",
    ["Crit"] = "Interface\\Icons\\Spell_Nature_WispSplode",
    ["Haste"] = "Interface\\Icons\\Spell_Nature_Lightning",
    ["Mastery"] = "Interface\\Icons\\Spell_Holy_Mastery",
    ["Versatility"] = "Interface\\Icons\\Spell_Holy_FistOfJustice",
    ["Avoidance"] = "Interface\\Icons\\Spell_Magic_LesserInvisibilty",
    ["Leech"] = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
    ["Speed"] = "Interface\\Icons\\Ability_Rogue_Sprint",
    ["Dodge"] = "Interface\\Icons\\Spell_Nature_Invisibilty",
    ["Parry"] = "Interface\\Icons\\Ability_Parry",
    ["Target Name"] = "Interface\\Icons\\Ability_Hunter_SniperShot",
    ["Target HP"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Main Stat"] = "Interface\\Icons\\Spell_Holy_DivineSpirit", -- Generic Stat Icon
    ["Run Speed"] = "Interface\\Icons\\Ability_Rogue_Sprint",
    ["Armor"] = "Interface\\Icons\\INV_Chest_Plate03",
    ["Max HP"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Dragonriding"] = "Interface\\Icons\\Ability_DragonRiding_Vigor01",
    ["Retirement Home"] = "Interface\\Icons\\Ability_Hunter_EagleEye"
}


-- --- HELPER FUNCTIONS ---
function WithSpace(str)
    if str and str ~= "" then return " " .. str else return "" end
end

-- --- BAR MANAGEMENT ---

-- [SAFETY] Barın bu karakterle alakasını kontrol eden MERKEZİ fonksiyon.
function WidgetForge:IsBarRelevant(conf)
    if not conf then return false end
    
    -- Scope yoksa Globaldir, herkese görünür.
    if not conf.scope then return true end

    -- Helper: İsim normalizasyonu (Boşlukları sil, küçük harf yap)
    local function normalize(str)
        if not str then return "" end
        return string.lower(string.gsub(str, "%s+", ""))
    end

    local myName = normalize(UnitName("player") .. "-" .. GetRealmName())
    
    if conf.scope.type == "CHARACTER" then
        local scopeVal = normalize(conf.scope.value)
        if scopeVal ~= myName then return false end
        
    elseif conf.scope.type == "SPEC" then
        -- 1. ADIM: Karakter Kontrolü (ZORUNLU)
        if conf.scope.character then
             local scopeChar = normalize(conf.scope.character)
             if scopeChar ~= myName then return false end
        else
             -- [SAFETY] Sahipsiz spec barlarını gizle (Ghost önlemi)
             return false 
        end
        
        -- 2. ADIM: Spec ID Kontrolü
        local currentSpec = GetSpecialization()
        if not currentSpec then return false end 
        
        local currentSpecId = GetSpecializationInfo(currentSpec)
        if not currentSpecId then return false end

        if tonumber(conf.scope.value) ~= tonumber(currentSpecId) then return false end
    end

    return true
end

function WidgetForge:SetBarsLocked(locked)
    WidgetForge.BarsLocked = locked
    for index, f in pairs(Bars) do
        f:EnableMouse(not locked)
        if locked then
            Skin:SetSmartBorder(f, 0) -- Hide border highlight when locked
        end
        
        -- [CLICK THROUGH LOGIC]
        local conf = WidgetForgeDB.bars[index]
        if f.hitboxes then
            for _, hb in pairs(f.hitboxes) do
                if locked then
                    -- If Locked (Play Mode):
                    -- If clickThrough is TRUE, Disable Mouse (allow clicking world)
                    -- If clickThrough is FALSE, Enable Mouse (allow tooltips)
                    if conf and conf.clickThrough then
                        hb:EnableMouse(false)
                    else
                        hb:EnableMouse(true)
                    end
                else
                    -- If Unlocked (Config Mode):
                    -- Disable hitboxes to allow dragging the bar via Grip or background without interference?
                    -- Or keep them enabled to preview tooltips?
                    -- Usually better to keep enabled or follow clickThrough? 
                    -- Let's keep them enabled so user can see tooltips while configuring if they want, 
                    -- UNLESS clickThrough is on? No, in config mode we might want to edit.
                    -- Actually, GripHandle is separate. Let's force Enable for tooltips in config mode.
                    hb:EnableMouse(true)
                end
            end
        end

        WidgetForge:RebuildBarComponents(index)
    end
end

function WidgetForge:UpdateAvailableBars()
    for _, barFrame in pairs(Bars) do barFrame:Hide() end
    
    if not WidgetForgeDB or not WidgetForgeDB.bars then return end

    for index, conf in ipairs(WidgetForgeDB.bars) do
        local isRelevant = WidgetForge:IsBarRelevant(conf)
        local isEnabled = conf.enabled
        
        if isRelevant and isEnabled then
            if not Bars[index] then
                -- Create Frame with ForgeSkin Style
                local f = CreateFrame("Frame", "WidgetForgeBar"..index, UIParent, "BackdropTemplate")
                f:SetFrameStrata("DIALOG") -- Fix Z-Index issue
                Skin:ApplyBackdrop(f) 
                
                f:SetMovable(true)
                f:EnableMouse(false) -- Default Locked
                
                -- [MOVED] Drag Logic is in Rebuild/Init, handled by GripHandle now.
                
                -- SmartBorder Interaction
                f:SetScript("OnEnter", function(self) 
                    if not self:IsMouseEnabled() then return end
                    Skin:SetSmartBorder(self, 1, {r=0, g=0.8, b=1, a=1}, "OUTSIDE") 
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    local currentConf = WidgetForgeDB.bars[self.index]
                    GameTooltip:SetText(currentConf and currentConf.name or ("Bar " .. self.index))
                    GameTooltip:Show()
                end)
                f:SetScript("OnLeave", function(self) 
                    Skin:SetSmartBorder(self, 0) 
                    GameTooltip:Hide()
                end)

                f.textsVal = {}
                f.textsLbl = {}
                f.icons = {}
                Bars[index] = f
            end
            
            local f = Bars[index]
            f.index = index 
            f:Show()
            f:SetSize(conf.width, conf.height)
            f:ClearAllPoints()
            f:SetPoint(conf.point or "CENTER", UIParent, conf.relativePoint or conf.point or "CENTER", conf.x or 100, conf.y or 0)
            
            -- Check Exclusive Mode (Dragonriding / Cursor Ring)
            local isExclusive = false
            if conf.elements then
                for _, e in ipairs(conf.elements) do
                    if e.type == "Dragonriding" or e.type == "Cursor Ring" or e.type == "Retirement Home" or e.type == "Mythic+ Dashboard" then isExclusive = true; break end
                end
            end

            -- Set Colors from Config
            if isExclusive then
                 f:SetBackdropColor(0, 0, 0, 0) -- Force Transparent
                 f:SetBackdropBorderColor(0, 0, 0, 0) -- Force No Border
            else
                 local c = conf.bgColor or {0, 0, 0, 0.5}
                 f:SetBackdropColor(c[1], c[2], c[3], c[4])
            
                 if conf.showBorder == false then
                     f:SetBackdropBorderColor(0,0,0,0)
                 else
                     local b = conf.borderColor or Skin.Colors.border
                     local size = conf.borderSize or 1
                     
                     local backdrop = {
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        tile = false, tileSize = 0, edgeSize = size,
                        insets = { left = 0, right = 0, top = 0, bottom = 0 }
                     }
                     f:SetBackdrop(backdrop)
                     f:SetBackdropColor(c[1], c[2], c[3], c[4]) 
                     f:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
                 end
            end
            
            WidgetForge:RebuildBarComponents(index)
        else
            if Bars[index] then Bars[index]:Hide() end
        end
    end
end

function WidgetForge:RebuildBarComponents(index)
    local f = Bars[index]
    local conf = WidgetForgeDB.bars[index]
    if not f or not conf then return end

    if not f.textsVal then f.textsVal = {} end
    if not f.textsLbl then f.textsLbl = {} end
    if not f.icons then f.icons = {} end
    if not f.dragonFrames then f.dragonFrames = {} end
    
    -- Cleanup Custom Widgets (Cursor Ring, etc.)
    if f.customWidgets then
        for _, cw in ipairs(f.customWidgets) do
            cw:Hide()
            if cw.Unload then cw:Unload() end
            cw:SetParent(nil)
        end
    end
    f.customWidgets = {}
    
    -- Cleanup Old
    for _, t in pairs(f.textsVal) do t:Hide() end
    for _, t in pairs(f.textsLbl) do t:Hide() end
    for _, t in pairs(f.icons) do t:Hide() end
    for _, h in pairs(f.hitboxes or {}) do h:Hide() end
    if f.dividers then for _, d in pairs(f.dividers) do d:Hide() end end
    for _, df in pairs(f.dragonFrames) do df:Hide() end
    
    -- [CLICK THROUGH CHECK]
    -- We need to ensure hitboxes respect clickThrough even during rebuild
    -- But SetBarsLocked handles the main toggle. Here we just create them.
    -- We can set default state here, but SetBarsLocked will override when called.
    -- However, Rebuild is called strictly during Config (Unlocked) usually, or Init (Locked).
    -- So we should check IsMouseEnabled of parent? No, logic is complex.
    -- Let's stick to creating them, and letting SetBarsLocked/Update loop handle state if needed.
    -- Actually, simple check:
    local isLocked = not f:IsMouseEnabled()
    local clickThrough = conf.clickThrough
    local hbEnabled = true
    if isLocked and clickThrough then hbEnabled = false end

    local justify = conf.justify or "CENTER"
    local isSplit = (conf.layout == "VERTICAL" and justify ~= "CENTER")

    -- [EXCLUSIVE CHECK]
    local exclusiveType = nil
    for _, e in ipairs(conf.elements) do
        if e.type == "Mythic+ Dashboard" or e.type == "Dragonriding" or e.type == "Cursor Ring" or e.type == "Retirement Home" then
            exclusiveType = e.type
            break
        end
    end
    
    for i, elem in ipairs(conf.elements) do
        if exclusiveType and elem.type ~= exclusiveType then
            -- Hide Peers in Exclusive Mode
            if f.textsVal[i] then f.textsVal[i]:Hide() end
            if f.textsLbl[i] then f.textsLbl[i]:Hide() end
            if f.icons[i] then f.icons[i]:Hide() end
            if f.hitboxes and f.hitboxes[i] then f.hitboxes[i]:Hide() end
            if f.dividers and f.dividers[i] then f.dividers[i]:Hide() end
            if f.dragonFrames and f.dragonFrames[i] then f.dragonFrames[i]:Hide() end
        elseif elem.type == "Divider" then
            if elem.dividerMode == "TEXT" then
                -- Divider as Text
                if not f.textsVal[i] then f.textsVal[i] = f:CreateFontString(nil, "OVERLAY") end
                local tVal = f.textsVal[i]
                tVal:Show()
                tVal:SetFont("Fonts\\FRIZQT__.TTF", elem.size or 14, "OUTLINE") 
                tVal:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
                tVal:SetText(elem.dividerText or "|")
            else
                -- Divider as Line (Graphic)
                if not f.dividers then f.dividers = {} end
                if not f.dividers[i] then f.dividers[i] = f:CreateTexture(nil, "OVERLAY") end
                local div = f.dividers[i]
                div:Show()
                div:SetColorTexture(unpack(elem.color or {1, 1, 1, 1}))
            end
        elseif elem.type == "Cursor Ring" then
            -- Create/Load once
            local ring = WidgetForge:CreateCursorRing(f, elem)
            table.insert(f.customWidgets, ring)
        elseif elem.type == "Retirement Home" then
            if WidgetForge.RetirementHome then
                 local cw = WidgetForge.RetirementHome:Load(f, elem)
                 if cw then table.insert(f.customWidgets, cw) end
            end
        elseif elem.type == "Mythic+ Dashboard" then
            if addonTable.MythicPlus then
                 local cw = addonTable.MythicPlus:Load(f, elem)
                 if cw then table.insert(f.customWidgets, cw) end
            end
        elseif elem.type == "Dragonriding" then
            if addonTable.Dragonriding then
                 local cw = addonTable.Dragonriding:Load(f, elem)
                 if cw then 
                    table.insert(f.customWidgets, cw)
                    -- [FIX] Layout loop requires indexed access
                    if not f.dragonFrames then f.dragonFrames = {} end
                    f.dragonFrames[i] = cw
                 end
            end

        else
            -- Standard Element
            -- Value Text
            if not f.textsVal[i] then f.textsVal[i] = f:CreateFontString(nil, "OVERLAY") end
            local tVal = f.textsVal[i]
            tVal:Show()
            local fontPath = Skin.Media.Fonts[elem.font] or "Fonts\\FRIZQT__.TTF"
            tVal:SetFont(fontPath, elem.size, elem.outline)
            
            -- [SAFETY] Logic: If font is invalid, GetStringWidth usually returns 0 or errors later.
            -- We test it here.
            tVal:SetText("test")
            if tVal:GetStringWidth() == 0 then
                 -- Fallback
                 tVal:SetFont("Fonts\\FRIZQT__.TTF", elem.size, elem.outline)
            end
            tVal:SetText("") -- Reset

            tVal:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
            
            -- Label Text
            if isSplit then
                 if not f.textsLbl[i] then f.textsLbl[i] = f:CreateFontString(nil, "OVERLAY") end
                 local tLbl = f.textsLbl[i]
                 tLbl:Show()
                 tLbl:SetFont(fontPath, elem.size, elem.outline) -- Use same font
                 -- Safety check for label too
                 tLbl:SetText("test")
                 if tLbl:GetStringWidth() == 0 then tLbl:SetFont("Fonts\\FRIZQT__.TTF", elem.size, elem.outline) end
                 tLbl:SetText("")
                 
                 tLbl:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
            end
    
            -- Icon
            if elem.showIcon then
                if not f.icons[i] then f.icons[i] = f:CreateTexture(nil, "OVERLAY") end
                local icon = f.icons[i]
                local typeToIcon = elem.type
                if typeToIcon == "Main Stat" then typeToIcon = ForgeStats.ActiveMainStat or "Strength" end
                local iconPath = WidgetForge.StatIcons[typeToIcon] or "Interface\\Icons\\INV_Misc_QuestionMark"
                icon:Show()
                icon:SetTexture(iconPath)
                icon:SetSize(elem.size, elem.size) 
            end
    
            -- HitBox
            if not f.hitboxes then f.hitboxes = {} end
            if not f.hitboxes[i] then 
                local hb = CreateFrame("Frame", nil, f)
                -- hb:EnableMouse(true) -- Handled by SetBarsLocked logic mostly, but set initial:
                hb:EnableMouse(hbEnabled)
                hb:SetScript("OnEnter", function(self)
                    if not elem.showTooltip then return end 
                    ForgeStats:AddTooltip(self, elem.type, elem)
                end)
                hb:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
                f.hitboxes[i] = hb
            else
                f.hitboxes[i]:EnableMouse(hbEnabled)
            end
            f.hitboxes[i]:Show() 
        end
    end

    -- Title Bar & Drag Handle
    if conf.showTitle or f:IsMouseEnabled() then
        if conf.showTitle then
            if not f.titleHeader then
                local t = CreateFrame("Frame", nil, f, "BackdropTemplate")
                t:SetHeight(20)
                t:SetPoint("TOPLEFT", 0, 0)
                t:SetPoint("TOPRIGHT", 0, 0)
                Skin:ApplyBackdrop(t)
                t:SetBackdropColor(0.1, 0.1, 0.1, 1)
                t:SetBackdropBorderColor(0,0,0,0)
                t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                t.text:SetPoint("CENTER", 0, 0)
                t.text:SetTextColor(1, 1, 1, 1)
                f.titleHeader = t
            end
            f.titleHeader:Show()
            f.titleHeader.text:SetText(conf.name)
            local bc = conf.borderColor or Skin.Colors.border
            f.titleHeader:SetBackdropBorderColor(bc[1], bc[2], bc[3], (conf.showBorder~=false) and 1 or 0)
        elseif f.titleHeader then
            f.titleHeader:Hide()
        end

        if f:IsMouseEnabled() then
            if f.dragButton then f.dragButton:Hide(); f.dragButton = nil end
            local d = Skin:CreateGripHandle(f, 32, 32)
            d:SetPoint("LEFT", f, "RIGHT", 2, 0)
            d:SetFrameLevel(f:GetFrameLevel() + 50) 
            d:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    self.isDragging = true
                    local mX, mY = GetCursorPosition()
                    local s = f:GetEffectiveScale()
                    self.startX, self.startY = mX / s, mY / s
                    
                    -- Mevcut frame pozisyonunu al
                    local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint()
                    self.startPoint = {point or "CENTER", relativeTo or UIParent, relativePoint or "CENTER", xOfs or 0, yOfs or 0}
                end
            end)
            
            d:SetScript("OnMouseUp", function(self)
                self.isDragging = false
                
                -- Pozisyonu DB'ye kaydet
                local point, _, relativePoint, x, y = f:GetPoint()
                local currentConf = WidgetForgeDB.bars[f.index]
                if currentConf then
                    currentConf.point = point
                    currentConf.relativePoint = relativePoint
                    currentConf.x = x
                    currentConf.y = y
                end
                
                -- Sync Config UI
                if ForgeConfig and ForgeConfig.UpdateCoordinates then
                    ForgeConfig:UpdateCoordinates(f.index)
                end
            end)
            
            d:SetScript("OnUpdate", function(self)
                if self.isDragging then
                    local mX, mY = GetCursorPosition()
                    local s = f:GetEffectiveScale()
                    local curX, curY = mX / s, mY / s
                    
                    local diffX = curX - self.startX
                    local diffY = curY - self.startY
                    
                    local p = self.startPoint
                    f:ClearAllPoints()
                    f:SetPoint(p[1], p[2], p[3], p[4] + diffX, p[5] + diffY)
                end
            end)
            f.dragButton = d
            
            if WidgetForge.SelectedBarIndex == index then
                d:SetScale(1.3)
                if d.lines then for _, l in ipairs(d.lines) do l:SetVertexColor(0, 0.7, 1, 1) end end
            else
                d:SetScale(1.0)
                if d.lines then for _, l in ipairs(d.lines) do l:SetVertexColor(0, 0.7, 1, 1) end end
            end
            
            if f:IsMouseEnabled() then d:Show() else d:Hide() end
        elseif f.dragButton then
            f.dragButton:Hide()
        end
    else
        if f.titleHeader then f.titleHeader:Hide() end
        if f.dragButton then f.dragButton:Hide() end
    end
    
    WidgetForge:UpdateBarValues(index)
end

function WidgetForge:SetSelectedBar(index)
    WidgetForge.SelectedBarIndex = index
    for i, f in pairs(Bars) do
        if f.dragButton then
            if i == index then
                f.dragButton:SetScale(1.3)
                 if f.dragButton.lines then for _, l in ipairs(f.dragButton.lines) do l:SetVertexColor(0, 0.7, 1, 1) end end
            else
                f.dragButton:SetScale(1.0)
                if f.dragButton.lines then for _, l in ipairs(f.dragButton.lines) do l:SetVertexColor(0, 0.7, 1, 1) end end
            end
        end
    end
end

-- [OPTIMIZATION] Update Loop with Cache Check
function WidgetForge:UpdateBarValues(index)
    local f = Bars[index]
    local conf = WidgetForgeDB.bars[index]
    if not f or not conf then return end
    
    local justify = conf.justify or "CENTER"
    local isSplit = (conf.layout == "VERTICAL" and justify ~= "CENTER")
    
    local maxFontSize = 12
    for _, elem in ipairs(conf.elements) do
        if elem.size and elem.size > maxFontSize then maxFontSize = elem.size end
    end
    local valueColWidth = math.max(40, maxFontSize * 3) 

    local totalH = 0
    local totalW = 0
    local titleHeight = (conf.showTitle) and 20 or 0
    
    for i, elem in ipairs(conf.elements) do
        local elemWidth = 0
        local elemHeight = 0
        
        if elem.type == "Divider" then
             local size = elem.size or 20
             local thk = elem.thickness or 2
             local style = elem.dividerStyle or "VERTICAL"
             
             if elem.dividerMode == "TEXT" then
                  local tVal = f.textsVal[i]; 
                  if tVal then 
                      tVal:SetText(elem.dividerText or "|"); 
                      elemWidth = tVal:GetStringWidth(); 
                      elemHeight = elem.size or 14 
                  end
             else
                  -- [FIX] In Vertical layout, dividers are forced HORIZONTAL (same logic as positioning pass)
                  local effectiveStyle = style
                  if conf.layout == "VERTICAL" then effectiveStyle = "HORIZONTAL" end
                  if effectiveStyle == "VERTICAL" then elemWidth = thk; elemHeight = size
                  else elemWidth = size; elemHeight = thk end 
             end
             
             if conf.layout == "VERTICAL" then
                totalH = totalH + elemHeight
                if i > 1 then totalH = totalH + conf.padding end
             else
                totalW = totalW + elemWidth
                if i > 1 then totalW = totalW + conf.padding end
             end
        elseif elem.type == "Dragonriding" then
            -- === DRAGONRIDING UPDATE ===
            -- Handled via UpdateVisuals in Module
            local df = f.dragonFrames and f.dragonFrames[i]
            if df and addonTable.Dragonriding then
                if df.UpdateVisuals or addonTable.Dragonriding.UpdateVisuals then
                     -- Module method (preferred) or instance method?
                     -- We defined method on Module: Dragonriding:UpdateVisuals(f, elem)
                     addonTable.Dragonriding:UpdateVisuals(df, elem)
                end
            end
            
            -- Size contribution
            local wW = elem.widgetWidth or 300
            local wH = elem.widgetHeight or 45
            if conf.layout == "VERTICAL" then
                totalH = totalH + wH
                if i > 1 then totalH = totalH + conf.padding end
            else
                totalW = totalW + wW
                if i > 1 then totalW = totalW + conf.padding end
                if i > 1 then totalW = totalW + conf.padding end
            end
        elseif elem.type == "Cursor Ring" then
            -- Handled in RebuildBarComponents (Fixed Leak)
            -- Just update position if needed, but CursorRing follows mouse.
            -- Maybe call UpdateVisuals if we can find the instance?
            -- Since customWidgets are list, finding the specific one for 'i' is hard without mapping.
            -- But we don't need to update it every 0.1s. It handles itself.
        elseif elem.type == "Retirement Home" then
            -- Handled in Rebuild
        elseif elem.type == "Mythic+ Dashboard" then
            -- Handled in Rebuild
        else
            -- Standard Element Size Calculation
            local valStr, lblStr = ForgeStats:GetStat(elem.type) 
            if elem.type == "Clock" then
                 local fmt = elem.timeFormat or "24h"
                 if fmt == "12h" then valStr = date("%I:%M %p") else valStr = date("%H:%M") end 
            end
            if not lblStr then lblStr = "" end
            
            local tVal = f.textsVal[i]
            if tVal then
                local iconWidth = (elem.showIcon and f.icons[i]) and (elem.size + 4) or 0
                
                -- [OPTIMIZATION] Prevent Redraw if Text Hasn't Changed
                local fullTextVal = valStr
                if isSplit then
                     local currentVal = tVal:GetText()
                     if currentVal ~= fullTextVal then tVal:SetText(fullTextVal) end
                     
                     local tLbl = f.textsLbl[i]
                     if tLbl then
                         local currentLbl = tLbl:GetText()
                         if currentLbl ~= lblStr then tLbl:SetText(lblStr) end
                     end
                else
                     local fullText = valStr .. WithSpace(lblStr)
                     local currentFull = tVal:GetText()
                     if currentFull ~= fullText then tVal:SetText(fullText) end
                end
                
                -- Width Logic (Stable Digit Width + Padding)
                -- We substitute all digits with '0' to ensure width doesn't change due to digit variance (e.g. "11" vs "88")
                -- We also add the '1 digit extra' padding (elem.size) requested.
                
                local currentText = tVal:GetText() or ""
                local stableText = string.gsub(currentText, "%d", "0")
                
                if elem.type == "FPS" then
                    if isSplit then
                        stableText = "000"
                    else
                        -- Use "000" + Label to reserve space for 3 digits
                        stableText = "000" .. WithSpace(lblStr)
                    end
                end
                
                -- Temporarily set text to stable version to measure it
                tVal:SetText(stableText)
                local stableContentW = tVal:GetStringWidth()
                tVal:SetText(currentText) -- Restore real text
                
                local extraPadding = (elem.size or 12)
                local activeW = stableContentW + extraPadding
                
                tVal:SetWidth(activeW)
                tVal:SetJustifyH("CENTER") -- Measurement pass: always CENTER, positioning pass overrides per layout

                if conf.layout == "VERTICAL" then
                    totalH = totalH + (elem.size or 12)
                    if i > 1 then totalH = totalH + conf.padding end
                else
                    local w = activeW + iconWidth
                    totalW = totalW + w
                    if i > 1 then totalW = totalW + conf.padding end
                end
            end
        end
    end

    -- Positioning (Standart Layout Logic)
    -- [Auto-Resize] Update Frame Size based on Content
    local edgePad = (conf.padding or 5) * 2
    local totalMinH = totalH + edgePad + titleHeight -- Minimum height needed by content
    
    if conf.layout == "VERTICAL" then
        -- Use the LARGER of: user-configured height OR minimum content height
        -- This lets the user make the bar bigger (more padding), but prevents clipping
        local userH = conf.height or 30
        local newH = math.max(userH, totalMinH)
        f:SetHeight(newH)
        f:SetWidth(conf.width or 100)
    else
        local newW = math.max(conf.width or 100, totalW + edgePad)
        f:SetWidth(newW)
        f:SetHeight(conf.height or 30)
    end

    -- justify already declared above (line 436)
    local barWidth, barHeight = f:GetSize()
    
    if conf.layout == "VERTICAL" then
        -- [FIX] Simple vertical centering using frame's own CENTER anchor.
        -- The title takes up space at the top, so we shift the content center down by titleHeight/2.
        local contentCenterY = -(titleHeight / 2)
        
        -- currentY tracks the TOP edge of each element's slot, relative to the content center.
        local startY = contentCenterY + (totalH / 2)
        local currentY = startY
        
        for i, elem in ipairs(conf.elements) do
            local offset = elem.offset or 0
            local elemHeight = 0
            
            -- Determine height FIRST to calculate center position
            if elem.type == "Divider" then
                 local size = elem.size or 20
                 local thk = elem.thickness or 2
                 local style = elem.dividerStyle or "VERTICAL"
                 
                 if elem.dividerMode == "TEXT" then
                      elemHeight = elem.size or 14
                 else
                      local isVertLayout = (conf.layout == "VERTICAL")
                      local effectiveStyle = style
                      if isVertLayout then effectiveStyle = "HORIZONTAL" end
                      -- In Vertical Layout, Horizontal Divider has Height = thk
                      elemHeight = (effectiveStyle=="VERTICAL") and size or thk
                 end
            elseif elem.type == "Dragonriding" then
                 elemHeight = elem.widgetHeight or 45
            else
                 elemHeight = elem.size or 12
            end

            -- FIX: Offset logic
            -- placementY is the CENTER of the element
            -- Center = Top - (Height / 2)
            local placementY = (currentY - (elemHeight / 2)) - offset

            if elem.type == "Divider" then
                local size = elem.size or 20
                local thk = elem.thickness or 2
                local style = elem.dividerStyle or "VERTICAL"
                
                if elem.dividerMode == "TEXT" then
                     local tVal = f.textsVal[i]
                     if tVal then
                         tVal:ClearAllPoints()
                         tVal:SetPoint("CENTER", f, "CENTER", 0, placementY)
                     end
                else
                     local div = f.dividers and f.dividers[i]
                     if div then
                         div:ClearAllPoints()
                         
                         local isVertLayout = (conf.layout == "VERTICAL")
                         local effectiveStyle = style
                         if isVertLayout then effectiveStyle = "HORIZONTAL" end
                         
                         local w = (effectiveStyle=="VERTICAL") and thk or size
                         local h = (effectiveStyle=="VERTICAL") and size or thk
                         div:SetSize(w, h)
                         div:SetPoint("CENTER", f, "CENTER", 0, placementY)
                     end
                end
                -- Advance currentY by full height + padding
                currentY = currentY - elemHeight
                if i < #conf.elements then currentY = currentY - conf.padding end
            elseif elem.type == "Dragonriding" then
                -- Dragonriding positioning (VERTICAL)
                local df = f.dragonFrames and f.dragonFrames[i]
                if df then
                    df:ClearAllPoints()
                    df:SetPoint("CENTER", f, "CENTER", 0, placementY)
                end
                currentY = currentY - elemHeight
                if i < #conf.elements then currentY = currentY - conf.padding end
            else
                local tVal = f.textsVal[i]
                if tVal then
                    local tLbl = isSplit and f.textsLbl[i] or nil
                    local icon = f.icons[i] 
                    local hb = f.hitboxes and f.hitboxes[i] 
                    local iconOffset = (elem.showIcon and icon) and (elem.size + 4) or 0
                    
                    tVal:ClearAllPoints()
                    if tLbl then tLbl:ClearAllPoints() end
                    if icon then icon:ClearAllPoints() end
                    if hb then hb:ClearAllPoints() end
    
                     tVal:SetWordWrap(false)
                     local currentText = tVal:GetText() or ""
                     local stableText = string.gsub(currentText, "%d", "0")
                     
                     if elem.type == "FPS" then
                        local _, lbl = ForgeStats:GetStat(elem.type)
                        if isSplit then
                            stableText = "000"
                        else
                            stableText = "000" .. WithSpace(lbl)
                        end
                     end
                     
                     tVal:SetText(stableText)
                     local stableContentW = tVal:GetStringWidth()
                     tVal:SetText(currentText)
                     
                     local extraPadding = (elem.size or 12)
                     local activeW = stableContentW + extraPadding
    
                    if isSplit then
                        -- [FIX] "Spine" Alignment: Value Right | Label Left
                        local centerGap = 2
                        
                        -- Value: Right Aligned to Center
                        tVal:ClearAllPoints()
                        tVal:SetWidth(stableContentW)
                        tVal:SetJustifyH("RIGHT")
                        tVal:SetPoint("RIGHT", f, "CENTER", -centerGap, placementY)
                        
                        -- Label: Left Aligned to Center
                        if tLbl then
                            tLbl:ClearAllPoints()
                            tLbl:SetJustifyH("LEFT")
                            tLbl:SetPoint("LEFT", f, "CENTER", centerGap, placementY)
                        end
                        
                        -- Icon: Left of Value
                        if icon then
                            icon:ClearAllPoints()
                            icon:SetPoint("RIGHT", tVal, "LEFT", -4, 0)
                        end
                        
                        if hb then
                            hb:SetPoint("LEFT", f, "LEFT", 0, 0)
                            hb:SetPoint("RIGHT", f, "RIGHT", 0, 0)
                            hb:SetHeight(elem.size)
                            hb:SetPoint("CENTER", f, "CENTER", 0, placementY)
                        end
                    else
                        if justify == "LEFT" then
                            local margin = 15
                            if icon then
                                icon:SetPoint("LEFT", f, "LEFT", margin, placementY)
                            end
                            tVal:SetPoint("LEFT", f, "LEFT", margin + iconOffset, placementY)
                            if hb then
                                local w = activeW + iconOffset
                                hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                                hb:SetPoint("LEFT", f, "LEFT", margin, placementY)
                            end
                        elseif justify == "RIGHT" then
                             local margin = 5
                             tVal:SetPoint("RIGHT", f, "RIGHT", -margin, placementY)
                             if icon then
                                icon:SetPoint("RIGHT", tVal, "LEFT", -4, 0)
                             end
                              if hb then
                                local w = activeW + iconOffset
                                hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                                hb:SetPoint("RIGHT", f, "RIGHT", -margin, placementY)
                            end
                        else
                            local w = activeW + iconOffset
                            local startX = -(w/2)
                            if icon then icon:SetPoint("LEFT", f, "CENTER", startX, placementY) end
                            tVal:SetPoint("LEFT", f, "CENTER", startX + iconOffset, placementY)
                            if hb then
                                 hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                                 hb:SetPoint("CENTER", f, "CENTER", 0, placementY)
                            end
                        end
                    end
                    -- Advance currentY by full height + padding (using pre-calculated height)
                    currentY = currentY - elemHeight
                    if i < #conf.elements then currentY = currentY - conf.padding end
                end
            end
        end
    else
        -- HORIZONTAL
        local contentCenterY = -(titleHeight / 2) -- Center offset for horizontal (accounts for title)
        local startX = 0
        if justify == "LEFT" then startX = -(barWidth / 2) + 5
        elseif justify == "RIGHT" then startX = (barWidth / 2) - totalW - 5
        else startX = -(totalW / 2) end
        
        local currentX = startX
        -- [FIX] Vertical Center Adjustment: Move down by 1px for better visual centering
        local currentY = contentCenterY - 1 
        
        for i, elem in ipairs(conf.elements) do
            local offset = elem.offset or 0
            -- FIX: Offset logic (Visual Only)
            local placementX = currentX + offset

            if elem.type == "Divider" then
                local tVal = f.textsVal[i]
                local div = f.dividers and f.dividers[i]
                
                local style = elem.dividerStyle or "VERTICAL"
                local size = elem.size or 20
                local thk = elem.thickness or 2
                local divWidth = 0
                
                if elem.dividerMode == "TEXT" then
                    if tVal then
                         tVal:ClearAllPoints()
                         -- Use LEFT alignment for standard flow
                         tVal:SetPoint("LEFT", f, "CENTER", placementX, currentY) 
                         divWidth = tVal:GetStringWidth()
                    end
                    if div then div:Hide() end
                else
                    if tVal then tVal:Hide() end
                    if div then
                         div:Show()
                         div:ClearAllPoints()
                         -- Width depends on Style
                         -- If VERTICAL Style: it's a TALL line, Width = thk
                         -- If HORIZONTAL Style: it's a WIDE line, Width = size
                         local w = (style=="VERTICAL") and thk or size
                         local h = (style=="VERTICAL") and size or thk
                         div:SetSize(w, h)
                         div:SetPoint("LEFT", f, "CENTER", placementX, currentY) 
                         divWidth = w
                    end
                end
                
                currentX = currentX + divWidth + conf.padding
            elseif elem.type == "Dragonriding" then
                -- Dragonriding positioning (HORIZONTAL)
                local df = f.dragonFrames and f.dragonFrames[i]
                if df then
                    df:ClearAllPoints()
                    df:SetPoint("LEFT", f, "CENTER", placementX, currentY)
                end
                currentX = currentX + (elem.widgetWidth or 300) + conf.padding
            else
                local tVal = f.textsVal[i]
                if tVal then -- Check existence
                    local icon = f.icons[i]
                    local hb = f.hitboxes and f.hitboxes[i] 
                    local iconOffset = (elem.showIcon and icon) and (elem.size + 4) or 0
                    
                    tVal:ClearAllPoints()
                    if icon then icon:ClearAllPoints() end
                    if hb then hb:ClearAllPoints() end
                    
                    if icon then icon:SetPoint("LEFT", f, "CENTER", placementX, currentY) end
                    tVal:SetWordWrap(false)
                    tVal:SetPoint("LEFT", f, "CENTER", placementX + iconOffset, currentY)
                    
                    local currentText = tVal:GetText() or ""
                    local stableText = string.gsub(currentText, "%d", "0")
                    
                    if elem.type == "FPS" then
                        local _, lbl = ForgeStats:GetStat(elem.type)
                        if isSplit then
                            stableText = "000"
                        else
                            stableText = "000" .. WithSpace(lbl)
                        end
                    end
                    
                    tVal:SetText(stableText)
                    local stableContentW = tVal:GetStringWidth()
                    tVal:SetText(currentText)
                    
                    local extraPadding = (elem.size or 12)
                    local w = stableContentW + extraPadding + iconOffset

                    if hb then
                        hb:SetSize(w, math.max(16, elem.size)) 
                        hb:SetPoint("LEFT", f, "CENTER", placementX, currentY)
                    end
                    currentX = currentX + w + conf.padding
                end
            end
        end
    end
end

-- --- UPDATE LOOP ---
local timer = 0
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    -- [FIX: RACE CONDITION] Stats modülü hazır olmadan update yapma
    if not ForgeStats or not ForgeStats.Initialized then return end

    timer = timer + elapsed
    if timer >= WIDGETFORGE_CONSTANTS.UPDATE_INTERVAL then
        ForgeStats:UpdatePolledStats(timer)
        if WidgetForgeDB and WidgetForgeDB.bars then
            for index, conf in ipairs(WidgetForgeDB.bars) do
                local f = Bars[index]
                if f and f:IsShown() then
                    WidgetForge:UpdateBarValues(index)
                end
            end
        end
        -- [FIX: TIMER DRIFT] Reset timer to 0 instead of subtracting
        timer = 0
    end
end)

-- --- INIT ---
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
loadFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
loadFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

loadFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not WidgetForgeDB then WidgetForgeDB = {} end
        
        -- [SAFETY] DB Integrity Check
        if type(WidgetForgeDB.bars) ~= "table" then WidgetForgeDB.bars = CopyTable(Config.DefaultSettings.bars) end
        if type(WidgetForgeDB.presets) ~= "table" then WidgetForgeDB.presets = {} end
        
        WidgetForgeUtils:MigrateDatabase(WidgetForgeDB)
        WidgetForge:UpdateAvailableBars()
        WidgetForge:SetBarsLocked(true)
        ForgeStats:Initialize()
        
        print("|cff00ccffWidgetForge|r v" .. WIDGETFORGE_CONSTANTS.VERSION .. " Loaded. Type |cff00ccff/wf|r to configure.")
    elseif event == "PLAYER_REGEN_DISABLED" then
        ForgeStats.CombatStart = GetTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ForgeStats.CombatStart = nil
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        WidgetForge:UpdateAvailableBars()
    elseif event == "PLAYER_ENTERING_WORLD" then
        WidgetForge:UpdateAvailableBars()
        WidgetForge:SetBarsLocked(true) 
    end
end)