local addonName, addonTable = ...
local Skin = ForgeSkin
local Config = ForgeConfig

WidgetForge = {}
local Bars = {} 

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
    ["Main Stat"] = "Interface\\Icons\\Spell_Holy_DivineSpirit" -- Generic Stat Icon
}


-- --- HELPER FUNCTIONS ---
function WithSpace(str)
    if str and str ~= "" then return " " .. str else return "" end
end

-- --- STAT LOGIC ---
-- Returns: ValueString, LabelString (optional), IconPath (optional, unused internal lookup mostly)


-- --- BAR MANAGEMENT ---
function WidgetForge:SetBarsLocked(locked)
    for index, f in pairs(Bars) do
        f:EnableMouse(not locked)
        if locked then
            Skin:SetSmartBorder(f, 0) -- Hide border highlight when locked
        end
        -- Rebuild to update Drag Handle visibility (depends on IsMouseEnabled)
        WidgetForge:RebuildBarComponents(index)
    end
end

function WidgetForge:UpdateAvailableBars()
    for _, barFrame in pairs(Bars) do barFrame:Hide() end
    
    if not WidgetForgeDB or not WidgetForgeDB.bars then return end

    for index, conf in ipairs(WidgetForgeDB.bars) do
        -- VISIBILITY CHECK (Scope)
        local visible = conf.enabled
        
        if visible and conf.scope then
            if conf.scope.type == "CHARACTER" then
                local myName = UnitName("player") .. "-" .. GetRealmName()
                if conf.scope.value ~= myName then visible = false end
            elseif conf.scope.type == "SPEC" then
                -- Check character if defined
                if conf.scope.character then
                    local myName = UnitName("player") .. "-" .. GetRealmName()
                    if conf.scope.character ~= myName then visible = false end
                end

                if visible then
                    local currentSpec = GetSpecialization()
                    local currentSpecId = currentSpec and GetSpecializationInfo(currentSpec)
                    -- conf.scope.value should store SpecID
                    if tonumber(conf.scope.value) ~= tonumber(currentSpecId) then visible = false end
                end
            end
        end

        if visible then
            if not Bars[index] then
                -- Create Frame with ForgeSkin Style
                local f = CreateFrame("Frame", "WidgetForgeBar"..index, UIParent, "BackdropTemplate")
                f:SetFrameStrata("DIALOG") -- Fix Z-Index issue
                Skin:ApplyBackdrop(f) 
                
                f:SetMovable(true)
                f:EnableMouse(false) -- Default Locked
                f:RegisterForDrag("LeftButton")
                f:SetScript("OnDragStart", f.StartMoving)
                
                -- [CRITICAL] FIX: Do NOT access 'conf' from closure here!
                -- 'conf' is captured from the *first time* the frame is created.
                -- If bars are reordered/removed, 'conf' might point to stale data.
                -- Always fetch current config via self.index
                f:SetScript("OnDragStop", function(self)
                    self:StopMovingOrSizing()
                    local point, _, relativePoint, x, y = self:GetPoint()
                    
                    local currentConf = WidgetForgeDB.bars[self.index]
                    if currentConf then
                        currentConf.point = point
                        currentConf.relativePoint = relativePoint
                        currentConf.x = x
                        currentConf.y = y
                    end
                end)
                
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
            f.index = index -- [IMPORTANT] Keep index updated for callbacks
            f:Show()
            f:SetSize(conf.width, conf.height)
            f:ClearAllPoints()
            -- Default X=100 ensures bar doesn't start off-screen on the left
            f:SetPoint(conf.point or "CENTER", UIParent, conf.relativePoint or conf.point or "CENTER", conf.x or 100, conf.y or 0)
            
            -- Set Colors from Config
            local c = conf.bgColor
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
            
            WidgetForge:RebuildBarComponents(index)
        else
            -- If hidden/disabled but frame exists, hide it
            if Bars[index] then Bars[index]:Hide() end
        end
    end
end

-- 1. HEAVY LIFTING: Create/Style Frames (Called only on Config Change)
function WidgetForge:RebuildBarComponents(index)
    local f = Bars[index]
    local conf = WidgetForgeDB.bars[index]
    if not f or not conf then return end

    if not f.textsVal then f.textsVal = {} end
    if not f.textsLbl then f.textsLbl = {} end
    if not f.icons then f.icons = {} end
    
    -- Cleanup Old
    for _, t in pairs(f.textsVal) do t:Hide() end
    for _, t in pairs(f.textsLbl) do t:Hide() end
    for _, t in pairs(f.icons) do t:Hide() end
    for _, h in pairs(f.hitboxes or {}) do h:Hide() end -- Cleanup Hitboxes

    local justify = conf.justify or "CENTER"
    local isSplit = (conf.layout == "VERTICAL" and justify ~= "CENTER")
    
    for i, elem in ipairs(conf.elements) do
        -- Value Text
        if not f.textsVal[i] then f.textsVal[i] = f:CreateFontString(nil, "OVERLAY") end
        local tVal = f.textsVal[i]
        tVal:Show()
        tVal:SetFont(Skin.Media.Fonts[elem.font] or "Fonts\\FRIZQT__.TTF", elem.size, elem.outline)
        tVal:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
        
        -- Label Text (Only if Split)
        if isSplit then
             if not f.textsLbl[i] then f.textsLbl[i] = f:CreateFontString(nil, "OVERLAY") end
             local tLbl = f.textsLbl[i]
             tLbl:Show()
             tLbl:SetFont(Skin.Media.Fonts[elem.font] or "Fonts\\FRIZQT__.TTF", elem.size, elem.outline)
             tLbl:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
        end

        -- Icon
        if elem.showIcon then
            if not f.icons[i] then f.icons[i] = f:CreateTexture(nil, "OVERLAY") end
            local icon = f.icons[i]
            
            local typeToIcon = elem.type
            if typeToIcon == "Main Stat" then
                 typeToIcon = ForgeStats.ActiveMainStat or "Strength"
            end
            
            local iconPath = WidgetForge.StatIcons[typeToIcon] or "Interface\\Icons\\INV_Misc_QuestionMark"
            icon:Show()
            icon:SetTexture(iconPath)
            icon:SetSize(elem.size, elem.size) -- Square icon based on font size
        end

        -- [NEW] HitBox for Interaction
        if not f.hitboxes then f.hitboxes = {} end
        if not f.hitboxes[i] then 
            local hb = CreateFrame("Frame", nil, f)
            hb:EnableMouse(true)
            hb:SetScript("OnEnter", function(self)
                if not elem.showTooltip then return end -- Check Config
                ForgeStats:AddTooltip(self, elem.type, elem)
            end)
            hb:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            f.hitboxes[i] = hb
        end
        f.hitboxes[i]:Show() -- Setup resizing happens in UpdateBarValues
    end

    -- [NEW] Title Bar & Drag Handle
    if conf.showTitle or f:IsMouseEnabled() then
        -- Title
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

        -- Drag Handle (Only in Config Mode/Unlocked)
        if f:IsMouseEnabled() then
            -- Always recreate to ensure colors are current
            if f.dragButton then
                f.dragButton:Hide()
                f.dragButton = nil
            end
            
            -- [REWRITE] Clean Drag Handle Implementation (GRIP STYLE)
            local d = Skin:CreateGripHandle(f, 32, 32)
            d:SetPoint("LEFT", f, "RIGHT", 2, 0)
            d:SetFrameLevel(f:GetFrameLevel() + 50) 
            
            -- Drag Logic
            d:RegisterForDrag("LeftButton")
            d:SetScript("OnDragStart", function() f:StartMoving() end)
            d:SetScript("OnDragStop", function()
                f:StopMovingOrSizing()
                -- Save Position
                local point, _, relativePoint, x, y = f:GetPoint()
                local currentConf = WidgetForgeDB.bars[f.index]
                if currentConf then
                    currentConf.point = point
                    currentConf.relativePoint = relativePoint
                    currentConf.x = x
                    currentConf.y = y
                end
            end)

            f.dragButton = d
            
            -- [NEW] Apply Scale if Selected
            if WidgetForge.SelectedBarIndex == index then
                d:SetScale(1.3)
                if d.lines then
                     -- Force Blue for Selected too (User requested "Not White")
                     for _, l in ipairs(d.lines) do l:SetVertexColor(0, 0.7, 1, 1) end 
                end
            else
                d:SetScale(1.0)
                if d.lines then
                     for _, l in ipairs(d.lines) do l:SetVertexColor(0, 0.7, 1, 1) end -- Standard Blue
                end
            end
            
            if f:IsMouseEnabled() then d:Show() else d:Hide() end
        elseif f.dragButton then
            f.dragButton:Hide()
        end

    else
        if f.titleHeader then f.titleHeader:Hide() end
        if f.dragButton then f.dragButton:Hide() end
    end
    
    -- Force a layout update immediately
    WidgetForge:UpdateBarValues(index)
end

function WidgetForge:SetSelectedBar(index)
    WidgetForge.SelectedBarIndex = index
    for i, f in pairs(Bars) do
        if f.dragButton then
            if i == index then
                f.dragButton:SetScale(1.3)
                -- Keep Blue (User preference)
                 if f.dragButton.lines then
                    for _, l in ipairs(f.dragButton.lines) do l:SetVertexColor(0, 0.7, 1, 1) end 
                end
            else
                f.dragButton:SetScale(1.0)
                if f.dragButton.lines then
                    for _, l in ipairs(f.dragButton.lines) do l:SetVertexColor(0, 0.7, 1, 1) end
                end
            end
        end
    end
end

-- 2. LIGHTWEIGHT: Update Text & Positions (Called on OnUpdate)
function WidgetForge:UpdateBarValues(index)
    local f = Bars[index]
    local conf = WidgetForgeDB.bars[index]
    if not f or not conf then return end
    
    local justify = conf.justify or "CENTER"
    local isSplit = (conf.layout == "VERTICAL" and justify ~= "CENTER")
    
    -- Dynamic Column Width Calculation (mostly for Vertical Split)
    local maxFontSize = 12
    for _, elem in ipairs(conf.elements) do
        if elem.size and elem.size > maxFontSize then maxFontSize = elem.size end
    end
    local valueColWidth = math.max(40, maxFontSize * 3) 

    local totalH = 0
    local totalW = 0
    
    -- Calculate Title Offset
    local titleHeight = (conf.showTitle) and 20 or 0
    
    -- Update Content First
    for i, elem in ipairs(conf.elements) do
        local valStr, lblStr = ForgeStats:GetStat(elem.type) -- Need to pass format options later?
        -- Special handling for Clock Format
        if elem.type == "Clock" then
             local fmt = elem.timeFormat or "24h"
             if fmt == "12h" then valStr = date("%I:%M %p")
             else valStr = date("%H:%M") end 
        end
        
        if not lblStr then lblStr = "" end
        
        local tVal = f.textsVal[i]
        if not tVal then break end -- Stop if UI elements are missing (rebuild pending)

        local icon = f.icons[i] -- might be nil
        local iconWidth = (elem.showIcon and icon) and (elem.size + 4) or 0 -- +4 for padding
        
        if isSplit then
             local tLbl = f.textsLbl[i]
             tVal:SetText(valStr)
             tLbl:SetText(lblStr)
        else
             -- Combined
             local fullText = valStr .. WithSpace(lblStr)
             tVal:SetText(fullText)
        end
        
        if conf.layout == "VERTICAL" then
            totalH = totalH + (elem.size or 12)
            if i > 1 then totalH = totalH + conf.padding end
        else
            -- Horizontal: Width = Icon + Text + Padding
            local w = tVal:GetStringWidth() + iconWidth
            totalW = totalW + w
            if i > 1 then totalW = totalW + conf.padding end
        end
    end

    -- Positioning
    local justify = conf.justify or "CENTER"
    local barWidth, barHeight = f:GetSize()
    
    -- Shift Content Down due to Title
    local contentCenterY = (-titleHeight / 2) 
    
    if conf.layout == "VERTICAL" then
        local startY = contentCenterY + (totalH / 2)
        local currentY = startY
        
        for i, elem in ipairs(conf.elements) do
            local tVal = f.textsVal[i]
            if not tVal then break end -- Stop if visual components are missing
            local tLbl = isSplit and f.textsLbl[i] or nil
            local icon = f.icons[i] -- can be nil
            local hb = f.hitboxes and f.hitboxes[i] -- [NEW] Hitbox
            
            tVal:ClearAllPoints()
            if tLbl then tLbl:ClearAllPoints() end
            if icon then icon:ClearAllPoints() end
            if hb then hb:ClearAllPoints() end

            local iconOffset = (elem.showIcon and icon) and (elem.size + 4) or 0

            if isSplit then
                 -- SPLIT LAYOUT
                if justify == "LEFT" then
                    -- LEFT: Icon -> Val -> [Gap] -> Label
                    -- Icon at Padding
                    local margin = 15
                    if icon then
                        icon:SetPoint("LEFT", f, "LEFT", margin, 0)
                        icon:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end
                    
                    tVal:SetPoint("LEFT", f, "LEFT", margin + iconOffset, 0)
                    tVal:SetPoint("TOP", f, "CENTER", 0, currentY)
                    
                    tLbl:SetPoint("LEFT", f, "LEFT", margin + iconOffset + valueColWidth, 0)
                    tLbl:SetPoint("TOP", f, "CENTER", 0, currentY)
                    
                    -- Hitbox covers entire row width? Or just value?
                    -- Let's cover the full split row for ease
                    if hb then
                        hb:SetPoint("LEFT", f, "LEFT", margin, 0)
                        hb:SetPoint("RIGHT", f, "RIGHT", -margin, 0)
                        hb:SetHeight(elem.size)
                        hb:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end
                    
                elseif justify == "RIGHT" then
                    local margin = 5
                    -- RIGHT: Val -> Label -> Icon? Or Icon -> Val -> Label?
                    -- Usually Icon is left of text.
                    -- Label at Right - Padding.
                    -- Val at Label - Gap.
                    -- Icon at Val - Gap.
                    
                    -- Label Anchored RIGHT
                    tLbl:SetPoint("RIGHT", f, "RIGHT", -margin, 0)
                    tLbl:SetPoint("TOP", f, "CENTER", 0, currentY)
                    
                    -- Value Anchored RIGHT of Label logic? No, Split means fixed columns usually.
                    -- Label Column = Right Edge.
                    -- Value Column = Right Edge - LabelWidth?
                    -- Let's stick to the previous implementation logic:
                    -- Value at Fixed Offset from Right
                    
                    local valRight = -margin - valueColWidth 
                    tVal:SetPoint("RIGHT", f, "RIGHT", valRight, 0)
                    tVal:SetPoint("TOP", f, "CENTER", 0, currentY)
                    
                    if icon then
                        -- Icon to Left of Value
                        icon:SetPoint("RIGHT", tVal, "LEFT", -4, 0)
                        -- Or fixed column? Let's anchor to Value string for tightness
                        icon:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end

                     if hb then
                        hb:SetPoint("LEFT", f, "LEFT", margin, 0)
                        hb:SetPoint("RIGHT", f, "RIGHT", -margin, 0)
                        hb:SetHeight(elem.size)
                        hb:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end
                end
            else
                -- COMBINED (Vertical)
                if justify == "LEFT" then
                    -- Standard Margin for edge
                    local margin = 15
                    
                    if icon then
                        icon:SetPoint("LEFT", f, "LEFT", margin, 0)
                        icon:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end
                    tVal:SetPoint("LEFT", f, "LEFT", margin + iconOffset, 0)
                    tVal:SetPoint("TOP", f, "CENTER", 0, currentY)
                    
                    if hb then
                        -- Safe sizing
                        local w = tVal:GetStringWidth() + iconOffset
                        hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                        hb:SetPoint("LEFT", f, "LEFT", margin, 0)
                        hb:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end
                    
                elseif justify == "RIGHT" then
                     local margin = 5
                     -- Icon -> Text |
                     tVal:SetPoint("RIGHT", f, "RIGHT", -margin, 0)
                     tVal:SetPoint("TOP", f, "CENTER", 0, currentY)
                      
                     if icon then
                        icon:SetPoint("RIGHT", tVal, "LEFT", -4, 0)
                        icon:SetPoint("TOP", f, "CENTER", 0, currentY)
                     end

                      if hb then
                        local w = tVal:GetStringWidth() + iconOffset
                        hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                        hb:SetPoint("RIGHT", f, "RIGHT", -margin, 0)
                        hb:SetPoint("TOP", f, "CENTER", 0, currentY)
                    end

                else
                    -- CENTER
                    local w = tVal:GetStringWidth() + iconOffset
                    local startX = -(w/2)
                    
                    if icon then
                        icon:SetPoint("LEFT", f, "CENTER", startX, currentY)
                    end
                    
                    tVal:SetPoint("LEFT", f, "CENTER", startX + iconOffset, currentY)

                    if hb then
                         hb:SetSize(math.max(w, 20), math.max(elem.size, 12)) 
                         hb:SetPoint("CENTER", f, "CENTER", 0, currentY)
                    end
                end
            end
            
            currentY = currentY - (elem.size) - conf.padding
        end
    else
        -- HORIZONTAL LAYOUT (Always Combined)
        local startX = 0
        if justify == "LEFT" then
             startX = -(barWidth / 2) + conf.padding
        elseif justify == "RIGHT" then
             startX = (barWidth / 2) - totalW - conf.padding
        else -- CENTER
             startX = -(totalW / 2)
        end
        
        local currentX = startX
        local currentY = contentCenterY -- Center Vertically in remaining space
        
        for i, elem in ipairs(conf.elements) do
            local tVal = f.textsVal[i]
            local icon = f.icons[i]
            local hb = f.hitboxes and f.hitboxes[i] -- [NEW]
            local iconOffset = (elem.showIcon and icon) and (elem.size + 4) or 0
            
            tVal:ClearAllPoints()
            if icon then icon:ClearAllPoints() end
            if hb then hb:ClearAllPoints() end
            
            if icon then
                -- Icon Left of Text
                -- We align the Group (Icon+Text) at CurrentX
                -- CurrentX is the Left Edge of this element group.
                icon:SetPoint("LEFT", f, "CENTER", currentX, currentY)
            end
            
            -- Text after Icon
            tVal:SetPoint("LEFT", f, "CENTER", currentX + iconOffset, currentY)
            
            local w = tVal:GetStringWidth() + iconOffset
            
            if hb then
                hb:SetSize(w, math.max(16, elem.size)) -- Min height for mouse catch
                hb:SetPoint("LEFT", f, "CENTER", currentX, currentY)
            end

            currentX = currentX + w + conf.padding
        end
    end
end




-- --- UPDATE LOOP ---
local timer = 0
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    timer = timer + elapsed
    if timer >= WIDGETFORGE_CONSTANTS.UPDATE_INTERVAL then
        -- [PERFORMANCE] Update Polled Stats (FPS, MS, etc) once per interval
        ForgeStats:UpdatePolledStats(timer)
        
        if WidgetForgeDB and WidgetForgeDB.bars then
            for index, conf in ipairs(WidgetForgeDB.bars) do
                local f = Bars[index]
                if f and f:IsShown() then
                    WidgetForge:UpdateBarValues(index)
                end
            end
        end
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
        if not WidgetForgeDB.bars then WidgetForgeDB.bars = CopyTable(Config.DefaultSettings.bars) end
        if not WidgetForgeDB.presets then WidgetForgeDB.presets = {} end
        
        -- Use Utils for database migration
        WidgetForgeUtils:MigrateDatabase(WidgetForgeDB)
        
        WidgetForge:UpdateAvailableBars()
        WidgetForge:SetBarsLocked(true)
        
        -- [PERFORMANCE] Initialize Stats Module
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
        -- [FIX] Force Lock on Enter World to prevent unlocked bars after reload
        WidgetForge:SetBarsLocked(true) 
    end
end)

