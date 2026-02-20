-- =========================================================================
--  WidgetForge - Skill Stream Module
--  FIFO based, animated skill stream interface
-- =========================================================================

local addonName, addonTable = ...

-- Global tabloya modülü dahil et
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.SkillStream = {}

local SkillStream = _G.WidgetForge.SkillStream
addonTable.SkillStream = SkillStream

SkillStream.Instances = {}

-- Pürüzsüz animasyon için Lerp matematiği
local function Lerp(startValue, endValue, amount)
    return startValue + (endValue - startValue) * amount
end

-- İkonların çerçeve ve yakınlaştırma (Crop) ayarlarını uygulayan yardımcı fonksiyon
function SkillStream:ApplyStyles(container)
    local elem = container.elem
    local zoom = elem.iconZoom or 0.08 -- 0.08 varsayılan blizz çerçevesini gizler
    local bSize = (elem.showBorder ~= false) and (elem.borderSize or 1) or 0
    local bc = elem.borderColor or {0, 0, 0, 1}
    
    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = bSize > 0 and "Interface\\Buttons\\WHITE8x8" or nil,
        edgeSize = bSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    for _, f in ipairs(container.icons) do
        f:SetBackdrop(backdrop)
        f:SetBackdropColor(0, 0, 0, 0.8) -- İkon yüklenene kadar veya arkasında kalacak koyu zemin
        
        if bSize > 0 then
            f:SetBackdropBorderColor(unpack(bc))
        end
        
        -- TexCoord ile ikonu yakınlaştır (Kenar kırpma işlemi)
        f.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        
        -- İkonu çerçevenin içine oturt
        f.tex:ClearAllPoints()
        f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", bSize, -bSize)
        f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -bSize, bSize)
    end
end

function SkillStream:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints(parent)
    container.elem = elem
    
    local limit = elem.iconLimit or 5
    local size = elem.iconSize or 32
    local isInteractive = elem.interactive or false
    
    -- Havuz (Pool) Oluşturma
    container.icons = {}
    for i = 1, limit + 1 do 
        -- Çerçeve çizebilmek için BackdropTemplate eklendi
        local f = CreateFrame("Frame", nil, container, "BackdropTemplate")
        f:SetSize(size, size)
        f:SetAlpha(0)
        
        f:EnableMouse(isInteractive)
        
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        
        f.currentOffset = 0
        f.targetOffset = 0
        f.currentAlpha = 0
        f.targetAlpha = 0
        f.active = false
        f.spellID = nil
        f.hasSpell = false 
        f.timestamp = 0 -- Zaman aşımı (Timeout) takibi için eklendi
        
        f:SetScript("OnEnter", function(self)
            if not self:GetParent().elem.interactive then return end
            if self.spellID and self.active and self.currentAlpha > 0.1 then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end
        end)
        
        f:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end)
        
        table.insert(container.icons, f)
    end
    
    -- İlk stili uygula
    SkillStream:ApplyStyles(container)
    
    -- Animasyon Döngüsü
    container:SetScript("OnUpdate", function(self, elapsed)
        local speed = self.elem.speed or 8 
        local direction = self.elem.direction or "RIGHT_TO_LEFT"
        local spacing = self.elem.spacing or 5
        local iconSize = self.elem.iconSize or 32
        local iconLimit = self.elem.iconLimit or 5
        local timeout = self.elem.timeout or 10 -- Saniye (0 ise kapalı)
        
        local currentTime = GetTime()
        local baseCenterOffset = ((iconLimit - 1) * (iconSize + spacing)) / 2
        
        for i, f in ipairs(self.icons) do
            -- Zaman Aşımı (Timeout) Kontrolü
            if timeout > 0 and f.active and f.hasSpell then
                if (currentTime - f.timestamp) > timeout then
                    f.active = false
                    f.hasSpell = false
                    f.targetAlpha = 0
                end
            end
            
            if f.active or f.currentAlpha > 0.01 then
                f.currentOffset = Lerp(f.currentOffset, f.targetOffset, elapsed * speed)
                f.currentAlpha = Lerp(f.currentAlpha, f.targetAlpha, elapsed * speed)
                f:SetAlpha(f.currentAlpha)
                
                local realOffset = f.currentOffset - baseCenterOffset
                local x, y = 0, 0
                
                if direction == "RIGHT_TO_LEFT" then
                    x = -realOffset
                elseif direction == "LEFT_TO_RIGHT" then
                    x = realOffset
                elseif direction == "TOP_TO_BOTTOM" then
                    y = -realOffset
                elseif direction == "BOTTOM_TO_TOP" then
                    y = realOffset
                end
                
                f:ClearAllPoints()
                f:SetPoint("CENTER", self, "CENTER", x, y)
                
                if not f.active and f.currentAlpha <= 0.01 then
                    f:SetAlpha(0)
                    if GameTooltip:IsOwned(f) then GameTooltip:Hide() end
                end
            end
        end
    end)

    table.insert(SkillStream.Instances, container)
    
    if not SkillStream.isListening then
        SkillStream:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        SkillStream:SetScript("OnEvent", SkillStream.OnEvent)
        SkillStream.isListening = true
    end
    
    container.Unload = function(self)
        for i, inst in ipairs(SkillStream.Instances) do
            if inst == self then table.remove(SkillStream.Instances, i); break end
        end
        if #SkillStream.Instances == 0 then
            SkillStream:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
            SkillStream.isListening = false
        end
    end
    
    return container
end

function SkillStream.OnEvent(self, event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    
    local defaultBlacklist = {
        [6603] = true,   
        [75] = true,     
        [5019] = true,   
        [136243] = true  
    }
    if defaultBlacklist[spellID] then return end

    local iconID = nil
    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then iconID = spellInfo.iconID end
    end
    if not iconID then return end 

    for _, container in ipairs(SkillStream.Instances) do
        local isBlacklisted = false
        local customStr = container.elem.blacklist or ""
        if customStr ~= "" then
            for idStr in string.gmatch(customStr, "([^,%s]+)") do
                if tonumber(idStr) == spellID then
                    isBlacklisted = true
                    break
                end
            end
        end
        
        if not isBlacklisted then
            SkillStream:AddSpell(container, spellID, iconID)
        end
    end
end

function SkillStream:AddSpell(container, spellID, iconID)
    local limit = container.elem.iconLimit or 5
    local spacing = container.elem.spacing or 5
    local size = container.elem.iconSize or 32
    
    local frame = table.remove(container.icons, #container.icons)
    table.insert(container.icons, 1, frame)
    
    frame.tex:SetTexture(iconID)
    frame.spellID = spellID
    frame.hasSpell = true 
    frame.active = true
    frame.timestamp = GetTime() -- Yeteneğin kullanım anını kaydet
    
    frame.currentOffset = - (size + spacing) 
    frame.currentAlpha = 0
    
    for i, f in ipairs(container.icons) do
        if i <= limit and f.hasSpell then
            f.targetOffset = (i - 1) * (size + spacing)
            f.targetAlpha = 1
            f.active = true
        else
            f.targetOffset = (i - 1) * (size + spacing)
            f.targetAlpha = 0
            f.active = false
            f.hasSpell = false 
        end
    end
end

-- =========================================================================
--  SETTINGS BUILDER
-- =========================================================================
function SkillStream:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    
    local function Refresh()
        if barIndex and _G.WidgetForge then
            -- Canlı olarak border ve zoom değişikliklerini uygulamak için
            for _, inst in ipairs(SkillStream.Instances) do
                if inst.elem == elem then
                    SkillStream:ApplyStyles(inst)
                end
            end
            
            _G.WidgetForge:RebuildBarComponents(barIndex)
            _G.WidgetForge:UpdateBarValues(barIndex)
        end
    end

    sb:AddHeader("Animation & Direction")

    local dirList = {
        {text = "Right to Left", value = "RIGHT_TO_LEFT"},
        {text = "Left to Right", value = "LEFT_TO_RIGHT"},
        {text = "Top to Bottom", value = "TOP_TO_BOTTOM"},
        {text = "Bottom to Top", value = "BOTTOM_TO_TOP"}
    }
    sb:AddDropdown("direction", "Flow Direction", dirList, "RIGHT_TO_LEFT", elem, Refresh)

    sb:AddHeader("Icon Settings")
    sb:AddSlider("iconLimit", "Visible Icon Limit", 3, 20, 1, 5, elem, Refresh)
    sb:AddSlider("iconSize", "Icon Size", 16, 64, 1, 32, elem, Refresh)
    sb:AddSlider("spacing", "Icon Spacing", 0, 50, 1, 5, elem, Refresh)
    sb:AddSlider("speed", "Animation Speed (Smoothness)", 1, 20, 1, 8, elem, Refresh)

    sb:AddHeader("Border & Styling")
    sb:AddCheckbox("showBorder", "Show Custom Border", true, elem, Refresh)
    sb:AddSlider("borderSize", "Border Size (Thickness)", 1, 5, 1, 1, elem, Refresh)
    sb:AddColor("borderColor", "Border Color", {0, 0, 0, 1}, elem, Refresh)
    sb:AddSlider("iconZoom", "Icon Zoom (Crop Default Blizzard Border)", 0, 0.20, 0.01, 0.08, elem, Refresh)

    sb:AddHeader("Timeout Settings")
    sb:AddSlider("timeout", "Fade Out Inactive Icons (Seconds, 0 = Off)", 0, 60, 1, 10, elem, Refresh)

    sb:AddHeader("Interactivity & Filters")
    sb:AddCheckbox("interactive", "Interactive Icons (Show Tooltips)", false, elem, function(v) 
        elem.interactive = v
        for _, inst in ipairs(SkillStream.Instances) do
            if inst.elem == elem then
                for _, iconFrame in ipairs(inst.icons) do iconFrame:EnableMouse(v) end
            end
        end
    end)

    sb:Finish()
    
    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then
                        bottomY = childBottom
                    end
                end
            end
        end
        
        bottomY = bottomY - 20
        
        local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", 20, bottomY)
        lbl:SetText("Blacklisted Spell IDs (Comma separated):")
        
        local ebFrame = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
        ebFrame:SetSize(350, 30)
        ebFrame:SetPoint("TOPLEFT", 20, bottomY - 20)
        if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(ebFrame) end
        ebFrame:SetBackdropColor(0, 0, 0, 0.5)
        
        local eb = CreateFrame("EditBox", nil, ebFrame)
        eb:SetAllPoints(ebFrame)
        eb:SetTextInsets(5,5,0,0)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:SetText(elem.blacklist or "")
        
        eb:SetScript("OnTextChanged", function(self, isUserInput)
            if isUserInput then elem.blacklist = self:GetText() end
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Refresh() end)
        
        local inst = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        inst:SetPoint("TOPLEFT", 20, bottomY - 55)
        inst:SetText("Example: 75, 6603. Auto-attacks are ignored by default.\nItems (Trinkets/Potions) are tracked automatically\nbecause they trigger spell casts!")
        inst:SetJustifyH("LEFT")

        if f.content.SetHeight then 
            f.content:SetHeight(math.abs(bottomY - 100)) 
        end
    end
end