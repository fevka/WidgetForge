local addonName, addonTable = ...
local L = WFL
if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.Castbar = {}
local Castbar = _G.WidgetForge.Castbar
addonTable.Castbar = Castbar
Castbar.Instances = {}

local GCD_SPELL_ID = 61304
local PREVIEW_DURATION_MS = 2800
local PREVIEW_GCD_DURATION_MS = 1200
local PREVIEW_SPELL_NAME = "Player Cast Preview"
local PREVIEW_GCD_NAME = "Global Cooldown"
local PREVIEW_ICON = 136116
local PREVIEW_SAFE_ZONE_RATIO = 0.09
local PREVIEW_CHANNEL_FRACTIONS = { 0.25, 0.50, 0.75 }
local PREVIEW_EMPOWER_SECTIONS = { 0.28, 0.26, 0.24, 0.22 }

local CHANNEL_TICK_COUNTS = {
    [740] = 4,       -- Tranquility
    [755] = 5,       -- Health Funnel
    [5143] = 4,      -- Arcane Missiles
    [12051] = 6,     -- Evocation
    [15407] = 6,     -- Mind Flay
    [129197] = 6,    -- Mind Flay: Insanity
    [47540] = 3,     -- Penance (legacy)
    [47757] = 3,     -- Penance (heal)
    [47758] = 3,     -- Penance (damage)
    [48045] = 6,     -- Mind Sear
    [64843] = 4,     -- Divine Hymn
    [64902] = 5,     -- Symbol of Hope
    [113656] = 4,    -- Fists of Fury
    [120360] = 15,   -- Barrage
    [198013] = 10,   -- Eye Beam
    [198590] = 4,    -- Drain Soul
    [205021] = 5,    -- Ray of Frost
    [206931] = 3,    -- Blooddrinker
    [212084] = 10,   -- Fel Devastation
    [234153] = 5,    -- Drain Life
    [257044] = 7,    -- Rapid Fire
    [291944] = 6,    -- Regeneratin'
    [356995] = 3,    -- Disintegrate
    [373129] = 3,    -- Penance (Dark Reprimand damage)
    [400171] = 3,    -- Penance (Dark Reprimand heal)
}

local EMPOWER_STAGE_COLORS = {
    [1] = { r = 0.18, g = 0.72, b = 1.00, a = 1.00 },
    [2] = { r = 0.20, g = 0.88, b = 0.50, a = 1.00 },
    [3] = { r = 1.00, g = 0.75, b = 0.20, a = 1.00 },
    [4] = { r = 1.00, g = 0.30, b = 0.30, a = 1.00 },
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetNowMS()
    return GetTime() * 1000
end

local function BuildCumulativeFractions(sections)
    if type(sections) ~= "table" then return nil end
    local fractions = {}
    local cumulative = 0
    for index, section in ipairs(sections) do
        if type(section) == "number" and section > 0 then
            cumulative = cumulative + section
            if cumulative < 0.995 and index < #sections then
                fractions[#fractions + 1] = cumulative
            end
        end
    end
    if #fractions == 0 then return nil end
    return fractions
end

local function GetCastInfo()
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo("player")
    if name then
        return {
            name = text or name,
            texture = texture,
            startTimeMS = startTimeMS,
            endTimeMS = endTimeMS,
            notInterruptible = notInterruptible,
            spellID = spellID,
            castID = castID,
            isChannel = false,
            isEmpower = false,
        }
    end

    local isEmpower
    name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID, isEmpower, _, castID = UnitChannelInfo("player")
    if name then
        local holdAtMaxMS = 0
        local stageSections
        if isEmpower and GetUnitEmpowerHoldAtMaxTime then
            holdAtMaxMS = GetUnitEmpowerHoldAtMaxTime("player") or 0
        end
        if isEmpower and UnitEmpoweredStagePercentages then
            stageSections = UnitEmpoweredStagePercentages("player")
        end
        return {
            name = text or name,
            texture = texture,
            startTimeMS = startTimeMS,
            endTimeMS = (endTimeMS or 0) + holdAtMaxMS,
            notInterruptible = notInterruptible,
            spellID = spellID,
            castID = castID,
            isChannel = not isEmpower,
            isEmpower = isEmpower and true or false,
            stageSections = stageSections,
        }
    end
    return nil
end

local function GetGCDInfo()
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if info and type(info.startTime) == "number" and type(info.duration) == "number" and info.duration > 0 then
            return {
                startTimeMS = info.startTime * 1000,
                endTimeMS = (info.startTime + info.duration) * 1000,
                durationMS = info.duration * 1000,
            }
        end
    end

    if type(GetSpellCooldown) == "function" then
        local startTime, duration = GetSpellCooldown(GCD_SPELL_ID)
        if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
            return {
                startTimeMS = startTime * 1000,
                endTimeMS = (startTime + duration) * 1000,
                durationMS = duration * 1000,
            }
        end
    end
    return nil
end

function Castbar:HasActiveInstances()
    return self.Instances and #self.Instances > 0
end

function Castbar:UpdateBlizzardCastbar()
    local hasActive = self:HasActiveInstances()
    if PlayerCastingBarFrame then
        if not self.blizzHooked then
            self.blizzHooked = true
            PlayerCastingBarFrame:HookScript("OnShow", function(s)
                if Castbar:HasActiveInstances() then
                    s:Hide()
                end
            end)
        end
        if hasActive then
            PlayerCastingBarFrame:UnregisterAllEvents()
            PlayerCastingBarFrame:Hide()
        else
            if PlayerCastingBarFrame.OnEvent then
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
                PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
                PlayerCastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            end
        end
    end
    if CastingBarFrame and CastingBarFrame ~= PlayerCastingBarFrame then
        if hasActive then
            CastingBarFrame:UnregisterAllEvents()
            CastingBarFrame:Hide()
        end
    end
end

local blizzTrackerFrame = CreateFrame("Frame")
Castbar.blizzTrackerFrame = blizzTrackerFrame
blizzTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
blizzTrackerFrame:SetScript("OnEvent", function()
    Castbar:UpdateBlizzardCastbar()
end)

function Castbar:Load(parent, elem)
    local Skin = _G.ForgeSkin
    local container = CreateFrame("Frame", nil, parent)
    container.elem = elem
    container.isTesting = false

    local barWidth = elem.barWidth or elem.widgetWidth or 220
    local barHeight = elem.barHeight or elem.widgetHeight or 22
    local iconSize = elem.iconSize or barHeight
    local iconSpacing = elem.iconSpacing or 5
    local showIcon = (elem.showIcon == nil) and true or elem.showIcon
    local totalWidth = showIcon and (iconSize + iconSpacing + barWidth) or barWidth
    local totalHeight = showIcon and math.max(iconSize, barHeight) or barHeight

    container:SetSize(totalWidth, totalHeight)

    local bgAlpha = (elem.barBgAlpha or 80) / 100
    local bgColor = elem.colorCastBg or {0.1, 0.1, 0.1, 1}

    local function GetBorderInset(bSize, pos)
        if not bSize or bSize <= 0 then return 0 end
        pos = pos or "OUTSIDE"
        if pos == "INSIDE" then
            return bSize
        elseif pos == "CENTER" then
            return math.max(1, math.floor(bSize / 2))
        else
            return 0
        end
    end

    -- Icon Frame
    container.iconBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.iconBg:SetSize(iconSize, iconSize)
    container.iconBg:SetPoint("LEFT", container, "LEFT", 0, 0)
    local iconBSize = elem.iconBorderSize or 1
    if iconBSize < 0 then iconBSize = 0 end
    local showIconBorder = (iconBSize > 0)
    Skin:ApplyBackdrop(container.iconBg)
    container.iconBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = showIconBorder and iconBSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.iconBg:SetBackdropColor(0.1, 0.1, 0.1, bgAlpha)
    if showIconBorder then
        container.iconBg:SetBackdropBorderColor(unpack(elem.iconBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        container.iconBg:SetBackdropBorderColor(0, 0, 0, 0)
    end
    local iconMargin = showIconBorder and (GetBorderInset(iconBSize, elem.iconBorderPosition) + 1) or 0
    container.icon = container.iconBg:CreateTexture(nil, "OVERLAY")
    container.icon:SetPoint("TOPLEFT", container.iconBg, "TOPLEFT", iconMargin, -iconMargin)
    container.icon:SetPoint("BOTTOMRIGHT", container.iconBg, "BOTTOMRIGHT", -iconMargin, iconMargin)
    local z = elem.iconZoom or 0.08
    container.icon:SetTexCoord(z, 1 - z, z, 1 - z)
    if not showIcon then container.iconBg:Hide() end

    -- Bar Frame
    container.barBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.barBg:SetSize(barWidth, barHeight)
    if showIcon then
        container.barBg:SetPoint("LEFT", container.iconBg, "RIGHT", iconSpacing, 0)
    else
        container.barBg:SetPoint("LEFT", container, "LEFT", 0, 0)
    end
    local barBSize = elem.barBorderSize or 1
    if barBSize < 0 then barBSize = 0 end
    local showBarBorder = (barBSize > 0)
    Skin:ApplyBackdrop(container.barBg)
    container.barBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = showBarBorder and barBSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.barBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgAlpha)
    if showBarBorder then
        container.barBg:SetBackdropBorderColor(unpack(elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        container.barBg:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local texPath = "Interface\\Buttons\\WHITE8x8"
    if Skin and Skin.Media and Skin.Media.Textures and elem.texture then
        texPath = Skin.Media.Textures[elem.texture] or texPath
    end

    local barMargin = showBarBorder and (GetBorderInset(barBSize, elem.barBorderPosition) + 1) or 0
    container.bar = CreateFrame("StatusBar", nil, container.barBg)
    container.bar:SetStatusBarTexture(texPath)
    container.bar:SetPoint("TOPLEFT", container.barBg, "TOPLEFT", barMargin, -barMargin)
    container.bar:SetPoint("BOTTOMRIGHT", container.barBg, "BOTTOMRIGHT", -barMargin, barMargin)
    container.bar:SetMinMaxValues(0, 1)
    container.bar:SetValue(0)

    -- Overlays & Textures inside bar
    container.gcdOverlay = container.bar:CreateTexture(nil, "ARTWORK")
    container.gcdOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
    container.gcdOverlay:Hide()

    container.safeZone = container.bar:CreateTexture(nil, "OVERLAY")
    container.safeZone:SetTexture("Interface\\Buttons\\WHITE8x8")
    container.safeZone:Hide()

    container.spark = container.bar:CreateTexture(nil, "OVERLAY")
    container.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    container.spark:SetBlendMode("ADD")
    local sparkW = elem.sparkWidth or 20
    container.spark:SetWidth(sparkW)
    local spkColor = elem.colorSpark or {1, 1, 1, 1}
    container.spark:SetVertexColor(spkColor[1], spkColor[2], spkColor[3], spkColor[4] or 1)
    container.spark:Hide()

    container.flash = container.bar:CreateTexture(nil, "OVERLAY")
    container.flash:SetAllPoints()
    container.flash:SetTexture("Interface\\Buttons\\WHITE8x8")
    container.flash:SetBlendMode("ADD")
    container.flash:Hide()

    container.flashAnim = container.flash:CreateAnimationGroup()
    container.flashFade = container.flashAnim:CreateAnimation("Alpha")
    container.flashFade:SetOrder(1)
    container.flashAnim:SetScript("OnPlay", function()
        container.flash:Show()
    end)
    container.flashAnim:SetScript("OnFinished", function()
        container.flash:Hide()
        if container.pendingDisplayAfterFlash then
            container.pendingDisplayAfterFlash = nil
            local currentInfo = GetCastInfo()
            if not currentInfo then
                container:ResetCastState()
                container:RefreshGCDInfo()
            else
                container:RefreshCastInfo()
                container:RefreshGCDInfo()
            end
        end
    end)

    container.markers = {}

    -- Text Frame & Texts
    container.textFrame = CreateFrame("Frame", nil, container.barBg)
    container.textFrame:SetAllPoints(container.bar)
    container.textFrame:SetFrameLevel(container.bar:GetFrameLevel() + 5)

    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then
        fontPath = Skin.Media.Fonts[elem.font] or fontPath
    end
    local textColor = elem.textColor or {1, 1, 1, 1}

    container.spellName = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.spellName:SetPoint("LEFT", container.textFrame, "LEFT", 5, 0)
    container.spellName:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.spellName:SetTextColor(unpack(textColor))
    container.spellName:SetText("")

    container.timer = container.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.timer:SetPoint("RIGHT", container.textFrame, "RIGHT", -5, 0)
    container.timer:SetFont(fontPath, elem.fontSize or 12, elem.fontOutline or "OUTLINE")
    container.timer:SetTextColor(unpack(textColor))
    container.timer:SetText("")

    -- Separate GCD Bar Frame
    local gcdBgAlpha = (elem.gcdBgAlpha or elem.barBgAlpha or 80) / 100
    local gcdBSize = elem.gcdBorderSize or elem.barBorderSize or 1
    if gcdBSize < 0 then gcdBSize = 0 end
    local showGcdBorder = (gcdBSize > 0)
    local gcdMargin = showGcdBorder and (GetBorderInset(gcdBSize, elem.gcdBorderPosition) + 1) or 0

    container.gcdFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    container.gcdFrame:SetSize(barWidth, elem.gcdHeight or 6)
    container.gcdFrame:SetPoint("TOPLEFT", container.barBg, "BOTTOMLEFT", 0, -2)
    Skin:ApplyBackdrop(container.gcdFrame)
    container.gcdFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = showGcdBorder and gcdBSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    container.gcdFrame:SetBackdropColor(0.1, 0.1, 0.1, gcdBgAlpha)
    if showGcdBorder then
        container.gcdFrame:SetBackdropBorderColor(unpack(elem.gcdBorderColor or elem.barBorderColor or {0.3, 0.3, 0.3, 1}))
    else
        container.gcdFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    container.gcdBar = CreateFrame("StatusBar", nil, container.gcdFrame)
    container.gcdBar:SetStatusBarTexture(texPath)
    container.gcdBar:SetPoint("TOPLEFT", container.gcdFrame, "TOPLEFT", gcdMargin, -gcdMargin)
    container.gcdBar:SetPoint("BOTTOMRIGHT", container.gcdFrame, "BOTTOMRIGHT", -gcdMargin, gcdMargin)
    container.gcdBar:SetMinMaxValues(0, 1)
    container.gcdBar:SetValue(0)
    container.gcdFrame:Hide()

    -- State variables
    container.castActive = false
    container.isPreview = false
    container.isChannel = false
    container.isEmpower = false
    container.notInterruptible = false
    container.startTimeMS = 0
    container.endTimeMS = 0
    container.durationMS = 0
    container.spellID = nil
    container.texture = nil

    container.gcdActive = false
    container.gcdPreview = false
    container.gcdStartTimeMS = 0
    container.gcdEndTimeMS = 0
    container.gcdDurationMS = 0

    function container:ResetCastState()
        self.castActive = false
        self.isPreview = false
        self.isChannel = false
        self.isEmpower = false
        self.notInterruptible = false
        self.startTimeMS = 0
        self.endTimeMS = 0
        self.durationMS = 0
        self.spellID = nil
        self.texture = nil
        self.stageSections = nil
        self.empowerStageIndex = nil
        self:HideMarkers()
        if self.safeZone then self.safeZone:Hide() end
        if self.spark then self.spark:Hide() end
        if self.bar then self.bar:SetValue(0) end
        if self.spellName then self.spellName:SetText("") end
        if self.timer then self.timer:SetText("") end
    end

    function container:ResetGCDState()
        self.gcdActive = false
        self.gcdPreview = false
        self.gcdStartTimeMS = 0
        self.gcdEndTimeMS = 0
        self.gcdDurationMS = 0
    end

    function container:AcquireMarker(index)
        if not self.markers[index] then
            local marker = self.bar:CreateTexture(nil, "OVERLAY")
            marker:SetTexture("Interface\\Buttons\\WHITE8x8")
            self.markers[index] = marker
        end
        return self.markers[index]
    end

    function container:HideMarkers()
        for _, marker in ipairs(self.markers) do
            marker:Hide()
        end
    end

    function container:GetEmpowerStageColor(stageIndex)
        stageIndex = Clamp(stageIndex or 1, 1, 4)
        local customColors = {
            self.elem.colorEmpowerStage1 or {0.18, 0.72, 1.00, 1.00},
            self.elem.colorEmpowerStage2 or {0.20, 0.88, 0.50, 1.00},
            self.elem.colorEmpowerStage3 or {1.00, 0.75, 0.20, 1.00},
            self.elem.colorEmpowerStage4 or {1.00, 0.30, 0.30, 1.00},
        }
        return customColors[stageIndex] or customColors[4] or {1, 1, 1, 1}
    end

    function container:GetEmpowerStageIndex(progressRatio)
        local sections = self.stageSections or PREVIEW_EMPOWER_SECTIONS
        if type(sections) ~= "table" then return nil end
        progressRatio = Clamp(progressRatio or 0, 0, 1)

        local cumulative = 0
        local stageIndex = 1
        for index, section in ipairs(sections) do
            if type(section) == "number" and section > 0 then
                cumulative = cumulative + section
                if progressRatio >= cumulative and index < #sections then
                    stageIndex = math.min(index + 1, #sections)
                else
                    break
                end
            end
        end
        return stageIndex
    end

    function container:UpdateEmpowerVisualState(progressRatio)
        local enableEmpower = (self.elem.enableEmpowerStages == nil) and true or self.elem.enableEmpowerStages
        local useFill = (self.elem.empowerUseFillColors == nil) and true or self.elem.empowerUseFillColors
        if not (self.isEmpower or (self.isPreview and self.stageSections)) or not (enableEmpower and useFill) then
            self.empowerStageIndex = nil
            return
        end

        local stageIndex = self:GetEmpowerStageIndex(progressRatio)
        if stageIndex and stageIndex ~= self.empowerStageIndex then
            self.empowerStageIndex = stageIndex
            local c = self:GetEmpowerStageColor(stageIndex)
            self.bar:SetStatusBarColor(c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1)
        end
    end

    function container:GetActiveMarkerFractions()
        local enableEmpower = (self.elem.enableEmpowerStages == nil) and true or self.elem.enableEmpowerStages
        local useMarkerColors = (self.elem.empowerUseMarkerColors == nil) and true or self.elem.empowerUseMarkerColors
        local defaultEmpowerColor = self.elem.colorEmpowerBase or {1.00, 0.82, 0.28, 0.95}
        local enableTicks = (self.elem.enableChannelTicks == nil) and true or self.elem.enableChannelTicks
        local colorTicks = self.elem.colorChannelTicks or {0.18, 0.72, 1.00, 1.00}
        local sections = self.stageSections or PREVIEW_EMPOWER_SECTIONS
        local empowerFractions = BuildCumulativeFractions(sections)

        if self.isPreview then
            if enableEmpower and empowerFractions then
                local colors = {}
                if useMarkerColors then
                    for index = 1, #empowerFractions do
                        local c = self:GetEmpowerStageColor(index)
                        colors[index] = { r = c[1] or c.r or 1, g = c[2] or c.g or 1, b = c[3] or c.b or 1, a = c[4] or c.a or 1 }
                    end
                end
                local baseC = { r = defaultEmpowerColor[1] or 1, g = defaultEmpowerColor[2] or 0.82, b = defaultEmpowerColor[3] or 0.28, a = defaultEmpowerColor[4] or 0.95 }
                return empowerFractions, colors, baseC
            end
            if enableTicks then
                return PREVIEW_CHANNEL_FRACTIONS, nil, { r = colorTicks[1], g = colorTicks[2], b = colorTicks[3], a = colorTicks[4] or 1 }
            end
            return nil
        end

        if self.isEmpower and enableEmpower and empowerFractions then
            local colors = {}
            if useMarkerColors then
                for index = 1, #empowerFractions do
                    local c = self:GetEmpowerStageColor(index)
                    colors[index] = { r = c[1] or c.r or 1, g = c[2] or c.g or 1, b = c[3] or c.b or 1, a = c[4] or c.a or 1 }
                end
            end
            local baseC = { r = defaultEmpowerColor[1] or 1, g = defaultEmpowerColor[2] or 0.82, b = defaultEmpowerColor[3] or 0.28, a = defaultEmpowerColor[4] or 0.95 }
            return empowerFractions, colors, baseC
        end

        if self.isChannel and enableTicks then
            local tickCount = self.spellID and CHANNEL_TICK_COUNTS[self.spellID]
            if tickCount and tickCount > 1 then
                local fractions = {}
                for index = 1, tickCount - 1 do
                    fractions[#fractions + 1] = index / tickCount
                end
                return fractions, nil, { r = colorTicks[1], g = colorTicks[2], b = colorTicks[3], a = colorTicks[4] or 1 }
            end
        end

        return nil
    end

    function container:UpdateMarkers()
        self:HideMarkers()
        local fractions, colors, color = self:GetActiveMarkerFractions()
        if not fractions or not color then return end

        local width = self.bar:GetWidth()
        local height = math.max(4, self.bar:GetHeight())

        for index, fraction in ipairs(fractions) do
            local marker = self:AcquireMarker(index)
            local markerColor = (colors and colors[index]) or color
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", self.bar, "LEFT", width * Clamp(fraction, 0, 1), 0)
            marker:SetSize(2, height)
            marker:SetColorTexture(markerColor.r or 1, markerColor.g or 1, markerColor.b or 1, markerColor.a or 1)
            marker:Show()
        end
    end

    function container:UpdateSafeZone()
        self.safeZone:Hide()
        local enableSZ = (self.elem.enableSafeZone == nil) and true or self.elem.enableSafeZone
        if not enableSZ or not self.castActive then return end

        local ratio = 0
        if self.isPreview then
            ratio = PREVIEW_SAFE_ZONE_RATIO
        elseif self.durationMS > 0 then
            local _, _, _, worldPing = GetNetStats()
            ratio = Clamp((worldPing or 0) / self.durationMS, 0, 1)
        end

        if ratio <= 0 then return end

        local width = self.bar:GetWidth()
        local safeZoneWidth = math.max(2, width * ratio)
        local szColor = self.elem.colorSafeZone or {1.00, 0.28, 0.28, 0.35}

        self.safeZone:ClearAllPoints()
        self.safeZone:SetPoint("TOP", self.bar, "TOP")
        self.safeZone:SetPoint("BOTTOM", self.bar, "BOTTOM")

        if self.isChannel then
            self.safeZone:SetPoint("LEFT", self.bar, "LEFT")
        else
            self.safeZone:SetPoint("RIGHT", self.bar, "RIGHT")
        end
        self.safeZone:SetWidth(safeZoneWidth)
        self.safeZone:SetColorTexture(szColor[1], szColor[2], szColor[3], szColor[4] or 0.35)
        self.safeZone:Show()
    end

    function container:ConfigureFlash()
        local enableF = (self.elem.enableFlash == nil) and true or self.elem.enableFlash
        local flColor = self.elem.colorFlash or {1, 1, 1, 0.75}
        local dur = self.elem.flashDuration or 0.25
        self.flash:SetColorTexture(flColor[1], flColor[2], flColor[3], flColor[4] or 0.75)
        if self.flashFade then
            self.flashFade:SetFromAlpha(flColor[4] or 0.75)
            self.flashFade:SetToAlpha(0)
            self.flashFade:SetDuration(math.max(0.05, dur))
        end
    end

    function container:StartCompleteFlash()
        local enableF = (self.elem.enableFlash == nil) and true or self.elem.enableFlash
        if not enableF or not self.flashAnim then return end

        self:ConfigureFlash()
        self.flashAnim:Stop()
        self.flash:Show()
        self.flashAnim:Play()
    end

    function container:GetBarColor()
        local cCast = self.elem.colorCast or {0.18, 0.72, 1.00, 1.00}
        local cChan = self.elem.colorChannel or {0.16, 0.88, 0.58, 1.00}
        local cUnint = self.elem.colorUninterruptible or {0.90, 0.30, 0.30, 1.00}

        if self.notInterruptible then
            return cUnint
        end
        if self.isChannel then
            return cChan
        end
        return cCast
    end

    function container:GetGCDColor()
        return self.elem.colorGCD or {1.00, 0.82, 0.28, 1.00}
    end

    function container:ShowPreview()
        local now = GetNowMS()
        self.castActive = true
        self.isPreview = true
        self.isChannel = false
        self.isEmpower = false
        self.notInterruptible = false
        self.startTimeMS = now
        self.endTimeMS = now + PREVIEW_DURATION_MS
        self.durationMS = PREVIEW_DURATION_MS
        self.spellID = nil
        self.spellNameText = PREVIEW_SPELL_NAME
        self.texture = PREVIEW_ICON
        self.stageSections = PREVIEW_EMPOWER_SECTIONS

        local durationSec = math.max(self.durationMS / 1000, 0.05)
        self.bar:SetMinMaxValues(0, durationSec)
        self.spellName:SetText(self.spellNameText)
        self.icon:SetTexture(self.texture)
        local color = self:GetBarColor()
        self.bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
        self:UpdateSafeZone()
        self:UpdateMarkers()

        local gcdMode = self.elem.gcdMode or "OFF"
        if gcdMode ~= "OFF" then
            local startTimeMS = now - math.floor(PREVIEW_GCD_DURATION_MS * 0.35)
            self.gcdActive = true
            self.gcdPreview = true
            self.gcdStartTimeMS = startTimeMS
            self.gcdEndTimeMS = startTimeMS + PREVIEW_GCD_DURATION_MS
            self.gcdDurationMS = PREVIEW_GCD_DURATION_MS
            local gcdDurationSec = math.max(self.gcdDurationMS / 1000, 0.05)
            local gcdColor = self:GetGCDColor()
            if gcdMode == "SEPARATE" then
                self.gcdBar:SetMinMaxValues(0, gcdDurationSec)
                self.gcdBar:SetStatusBarColor(gcdColor[1], gcdColor[2], gcdColor[3], gcdColor[4] or 1)
            end
        else
            self:ResetGCDState()
        end

        self:SetAlpha(1)
        self:UpdateDisplay()
    end

    function container:RefreshCastInfo()
        if self.isTesting then
            self:ShowPreview()
            return
        end

        local info = GetCastInfo()
        if not info then
            self:ResetCastState()
            self:UpdateDisplay()
            return
        end

        if self.flashAnim then self.flashAnim:Stop() end
        if self.flash then self.flash:Hide() end
        self.pendingDisplayAfterFlash = nil

        self.castActive = true
        self.isPreview = false
        self.isChannel = info.isChannel and true or false
        self.isEmpower = info.isEmpower and true or false
        self.notInterruptible = info.notInterruptible and true or false
        self.startTimeMS = info.startTimeMS or 0
        self.endTimeMS = info.endTimeMS or 0
        self.durationMS = math.max(self.endTimeMS - self.startTimeMS, 1)
        self.spellID = info.spellID
        self.spellNameText = info.name or ""
        self.texture = info.texture or PREVIEW_ICON
        self.stageSections = info.stageSections

        local durationSec = math.max(self.durationMS / 1000, 0.05)
        self.bar:SetMinMaxValues(0, durationSec)
        self.spellName:SetText(self.spellNameText)
        self.icon:SetTexture(self.texture)
        local color = self:GetBarColor()
        self.bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
        self:UpdateSafeZone()
        self:UpdateMarkers()

        self:SetAlpha(1)
        self:UpdateDisplay()
    end

    function container:RefreshGCDInfo(suppressDisplay)
        if self.isTesting then
            self:ShowPreview()
            return
        end

        local gcdMode = self.elem.gcdMode or "OFF"
        if gcdMode == "OFF" then
            self:ResetGCDState()
            if not suppressDisplay then self:UpdateDisplay() end
            return
        end

        local info = GetGCDInfo()
        if not info then
            self:ResetGCDState()
            if not suppressDisplay then self:UpdateDisplay() end
            return
        end

        self.gcdActive = true
        self.gcdPreview = false
        self.gcdStartTimeMS = info.startTimeMS
        self.gcdEndTimeMS = info.endTimeMS
        self.gcdDurationMS = info.durationMS

        local gcdDurationSec = math.max(self.gcdDurationMS / 1000, 0.05)
        local gcdColor = self:GetGCDColor()
        if gcdMode == "SEPARATE" then
            self.gcdBar:SetMinMaxValues(0, gcdDurationSec)
            self.gcdBar:SetStatusBarColor(gcdColor[1], gcdColor[2], gcdColor[3], gcdColor[4] or 1)
        end

        if not suppressDisplay then self:UpdateDisplay() end
    end

    function container:UpdateMainProgress()
        local now = GetNowMS()
        local durationMS = math.max(self.durationMS, 1)
        local remainingSec = math.max((self.endTimeMS - now) / 1000, 0)
        local durationSec = math.max(durationMS / 1000, 0.05)
        local value = self.isChannel and remainingSec or (durationSec - remainingSec)

        value = Clamp(value, 0, durationSec)
        self.bar:SetValue(value)
        self:UpdateEmpowerVisualState(Clamp(value / durationSec, 0, 1))
        self.timer:SetFormattedText("%.1f", remainingSec)

        -- Update spark
        local enableSpark = (self.elem.enableSpark == nil) and true or self.elem.enableSpark
        if enableSpark and value > 0 and value < durationSec then
            local fillTex = self.bar:GetStatusBarTexture()
            if fillTex then
                local sparkH = self.elem.sparkHeight or math.floor(self.bar:GetHeight() * 1.9)
                self.spark:ClearAllPoints()
                self.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
                self.spark:SetHeight(sparkH)
                self.spark:Show()
            else
                self.spark:Hide()
            end
        else
            self.spark:Hide()
        end
    end

    function container:UpdateGCDProgress()
        local gcdMode = self.elem.gcdMode or "OFF"
        if not self.gcdActive or gcdMode == "OFF" then
            self.gcdOverlay:Hide()
            self.gcdFrame:Hide()
            return
        end

        local now = GetNowMS()
        local durationSec = math.max(self.gcdDurationMS / 1000, 0.05)
        local remainingSec = math.max((self.gcdEndTimeMS - now) / 1000, 0)
        local progressRatio = Clamp((durationSec - remainingSec) / durationSec, 0, 1)

        if gcdMode == "OVERLAY" and self.castActive then
            local width = math.max(1, self.bar:GetWidth() * progressRatio)
            local gcdColor = self:GetGCDColor()
            self.gcdOverlay:ClearAllPoints()
            self.gcdOverlay:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
            self.gcdOverlay:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", 0, 0)
            self.gcdOverlay:SetWidth(width)
            self.gcdOverlay:SetColorTexture(gcdColor[1], gcdColor[2], gcdColor[3], (gcdColor[4] or 1) * 0.4)
            self.gcdOverlay:Show()
            self.gcdFrame:Hide()
        elseif gcdMode == "SEPARATE" then
            self.gcdOverlay:Hide()
            self.gcdFrame:Show()
            self.gcdBar:SetValue(durationSec - remainingSec)
        else
            self.gcdOverlay:Hide()
            self.gcdFrame:Hide()
        end
    end

    function container:UpdateDisplay()
        if self.castActive then
            self:SetAlpha(1)
            self:UpdateMainProgress()
        else
            if not self.gcdActive or self.elem.gcdMode ~= "SEPARATE" then
                self:SetAlpha(0)
            else
                self:SetAlpha(1)
            end
            self.bar:SetValue(0)
            self.spellName:SetText("")
            self.timer:SetText("")
            self.spark:Hide()
            self.safeZone:Hide()
            self:HideMarkers()
        end
        self:UpdateGCDProgress()
    end

    function container:HandleCastStop()
        if self.isTesting then
            self:ShowPreview()
            return
        end

        local currentInfo = GetCastInfo()
        if currentInfo then
            self:RefreshCastInfo()
            self:RefreshGCDInfo()
            return
        end

        local enableFlash = (self.elem.enableFlash == nil) and true or self.elem.enableFlash
        local shouldFlash = enableFlash and self.castActive and not self.isPreview and GetNowMS() >= (self.endTimeMS - 300)
        if shouldFlash then
            self.castActive = false
            self.pendingDisplayAfterFlash = true
            self:RefreshGCDInfo(true)
            self:StartCompleteFlash()
            return
        end

        self:ResetCastState()
        self:RefreshGCDInfo()
        self:UpdateDisplay()
    end

    -- Register Event Handlers
    container:RegisterEvent("PLAYER_ENTERING_WORLD")
    container:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    container:RegisterEvent("UNIT_SPELLCAST_START")
    container:RegisterEvent("UNIT_SPELLCAST_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_FAILED")
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    container:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    container:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    container:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    container:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    container:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    container:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    container:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    container:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            self:RefreshCastInfo()
            self:RefreshGCDInfo()
            return
        end

        if event == "SPELL_UPDATE_COOLDOWN" then
            if self.pendingDisplayAfterFlash then
                self:RefreshGCDInfo(true)
                return
            end
            if self.isTesting then
                self:ShowPreview()
            else
                self:RefreshGCDInfo()
            end
            return
        end

        if unit ~= "player" then return end

        if self.isTesting then
            self:ShowPreview()
            return
        end

        if self.pendingDisplayAfterFlash then
            self.pendingDisplayAfterFlash = nil
            if self.flashAnim then self.flashAnim:Stop() end
            self.flash:Hide()
        end

        if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            local currentInfo = GetCastInfo()
            if currentInfo then
                self:RefreshCastInfo()
                self:RefreshGCDInfo()
                return
            end
            self:HandleCastStop()
            return
        end

        if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            local currentInfo = GetCastInfo()
            if currentInfo then
                self:RefreshCastInfo()
                self:RefreshGCDInfo()
                return
            end
            self:ResetCastState()
            self:RefreshGCDInfo()
            self:UpdateDisplay()
            return
        end

        self:RefreshCastInfo()
        self:RefreshGCDInfo()
    end)

    container:SetScript("OnUpdate", function(self)
        if self:GetAlpha() == 0 and not self.gcdActive and not self.isTesting then return end

        local now = GetNowMS()
        if self.isTesting then
            if now >= self.endTimeMS then
                self:ShowPreview()
                return
            end
            if self.gcdActive and self.gcdPreview and self.elem.gcdMode == "SEPARATE" and now >= self.gcdEndTimeMS then
                local startTimeMS = now - math.floor(PREVIEW_GCD_DURATION_MS * 0.35)
                self.gcdStartTimeMS = startTimeMS
                self.gcdEndTimeMS = startTimeMS + PREVIEW_GCD_DURATION_MS
            end
        else
            local currentCast = GetCastInfo()

            if currentCast then
                if not self.castActive or self.startTimeMS ~= currentCast.startTimeMS or self.endTimeMS ~= currentCast.endTimeMS or self.spellID ~= currentCast.spellID then
                    self:RefreshCastInfo()
                end
            else
                if self.castActive then
                    if now >= (self.endTimeMS - 250) then
                        self:HandleCastStop()
                    else
                        self:ResetCastState()
                        self:RefreshGCDInfo()
                        self:UpdateDisplay()
                    end
                    return
                end
            end

            if self.gcdActive and now >= self.gcdEndTimeMS then
                self:RefreshGCDInfo()
                return
            end
        end

        if self.castActive or self.isTesting then
            self:UpdateMainProgress()
        end
        if self.gcdActive then
            self:UpdateGCDProgress()
        end
    end)

    container:SetAlpha(0)
    table.insert(Castbar.Instances, container)
    Castbar:UpdateBlizzardCastbar()

    container.Unload = function(self)
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
        self:SetScript("OnUpdate", nil)
        for i, inst in ipairs(Castbar.Instances) do
            if inst == self then table.remove(Castbar.Instances, i); break end
        end
        Castbar:UpdateBlizzardCastbar()
    end

    return container
end

function Castbar:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    local Skin = _G.ForgeSkin
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb
    parentFrame.isTestingGlobal_Castbar = parentFrame.isTestingGlobal_Castbar or false

    local function RefreshLive()
        if barIndex and _G.WidgetForge then
            _G.WidgetForge:RebuildBarComponents(barIndex)
            if parentFrame.isTestingGlobal_Castbar then
                for _, inst in ipairs(Castbar.Instances) do
                    if inst.elem == elem then
                        inst.isTesting = true
                        inst:ShowPreview()
                    end
                end
            end
        end
    end

    if not parentFrame.testBtnCastbar then
        local btnTest = Skin:CreateButton(f.content, L("LABEL_TEST_MODE_OFF"), 130, 22)
        btnTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -15, -10)
        parentFrame.testBtnCastbar = btnTest

        local function UpdateTestButtonVisuals()
            if parentFrame.isTestingGlobal_Castbar then
                btnTest:SetBackdropColor(0, 0.8, 0, 1)
                btnTest.text:SetText(L("LABEL_TEST_MODE_ON"))
            else
                btnTest:SetBackdropColor(unpack(Skin.Colors.button))
                btnTest.text:SetText(L("LABEL_TEST_MODE_OFF"))
            end
        end
        UpdateTestButtonVisuals()

        btnTest:SetScript("OnEnter", function()
            if parentFrame.isTestingGlobal_Castbar then btnTest:SetBackdropColor(0, 1, 0, 1)
            else btnTest:SetBackdropColor(unpack(Skin.Colors.buttonHover)) end
        end)
        btnTest:SetScript("OnLeave", function() UpdateTestButtonVisuals() end)
        btnTest:SetScript("OnClick", function()
            parentFrame.isTestingGlobal_Castbar = not parentFrame.isTestingGlobal_Castbar
            UpdateTestButtonVisuals()
            for _, inst in ipairs(Castbar.Instances) do
                if inst.elem == elem then
                    inst.isTesting = parentFrame.isTestingGlobal_Castbar
                    if parentFrame.isTestingGlobal_Castbar then inst:ShowPreview()
                    else inst:ResetCastState(); inst:ResetGCDState(); inst:SetAlpha(0) end
                end
            end
        end)

        if not parentFrame.onCloseWidgetSpecific then
             parentFrame.onCloseWidgetSpecific = function()
                 parentFrame.isTestingGlobal_Castbar = false
                 for _, inst in ipairs(Castbar.Instances) do inst.isTesting = false; inst:SetAlpha(0) end
             end
        end
    else
        if parentFrame.testBtnCastbar then
            parentFrame.testBtnCastbar:Show()
        end
    end

    local texItems = {}
    if Skin and Skin.Media and Skin.Media.Textures then
        for k, _ in pairs(Skin.Media.Textures) do table.insert(texItems, {text=tostring(k), value=k}) end
    end
    if #texItems == 0 then texItems = {{text=L("DEFAULT_OPTION"), value="Smooth"}}
    else table.sort(texItems, function(a,b) return a.text < b.text end) end

    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then
        for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=tostring(k), value=k}) end
    end
    if #fontItems == 0 then fontItems = {{text=L("DEFAULT_OPTION"), value="Fonts\\FRIZQT__.TTF"}}
    else table.sort(fontItems, function(a,b) return a.text < b.text end) end

    local borderPosOptions = {
        {text = L("OPTION_INSIDE"), value = "INSIDE"},
        {text = L("OPTION_CENTER"), value = "CENTER"},
        {text = L("OPTION_OUTSIDE"), value = "OUTSIDE"},
    }

    local gcdModeOptions = {
        {text = L("MODE_OFF"), value = "OFF"},
        {text = L("OPTION_CAST_BAR_OVERLAY"), value = "OVERLAY"},
        {text = L("OPTION_SEPARATE_MINI_BAR"), value = "SEPARATE"},
    }

    -- 1. Layout & Mode Section
    sb:AddHeader(L("HEADER_LAYOUT_MODE"))
    sb:AddDropdown("gcdMode", L("LABEL_GCD_BAR_MODE"), gcdModeOptions, "OFF", elem, RefreshLive)
    sb:AddSlider("barHeight", L("LABEL_CAST_BAR_HEIGHT"), 6, 60, 1, 22, elem, RefreshLive)
    sb:AddSlider("barWidth", L("LABEL_CAST_BAR_WIDTH"), 50, 600, 5, 220, elem, RefreshLive)
    sb:AddSlider("gcdHeight", L("LABEL_GCD_BAR_HEIGHT"), 4, 20, 1, 6, elem, RefreshLive)
    sb:AddSwitch("showIcon", L("LABEL_SHOW_SPELL_ICON"), true, elem, RefreshLive)
    sb:AddSlider("iconSize", L("LABEL_ICON_SIZE"), 10, 100, 1, 22, elem, RefreshLive)
    sb:AddSlider("iconSpacing", L("LABEL_ICON_SPACING_FROM_BAR"), 0, 50, 1, 5, elem, RefreshLive)
    sb:AddSlider("iconZoom", L("LABEL_ICON_ZOOM_CROP"), 0, 0.20, 0.01, 0.08, elem, RefreshLive)

    -- 2. Appearance Section
    sb:AddHeader(L("HEADER_APPEARANCE"))
    sb:AddColor("colorCast", L("LABEL_CAST_COLOR"), {0.18, 0.72, 1.00, 1.00}, elem, RefreshLive)
    sb:AddColor("colorCastBg", L("LABEL_BAR_BG_COLOR"), {0.1, 0.1, 0.1, 1}, elem, RefreshLive)
    sb:AddSlider("barBgAlpha", L("LABEL_BACKGROUND_ALPHA"), 0, 100, 5, 80, elem, RefreshLive)
    sb:AddDropdown("texture", L("LABEL_BAR_TEXTURE"), texItems, "Smooth", elem, RefreshLive)
    sb:AddColor("colorGCD", L("LABEL_GCD_COLOR"), {1.00, 0.82, 0.28, 1.00}, elem, RefreshLive)
    sb:AddColor("colorChannel", L("LABEL_CHANNEL_COLOR"), {0.16, 0.88, 0.58, 1.00}, elem, RefreshLive)
    sb:AddColor("colorUninterruptible", L("LABEL_UNINTERRUPTIBLE_CAST"), {0.90, 0.30, 0.30, 1.00}, elem, RefreshLive)
    sb:AddDropdown("font", L("LABEL_FONT_STYLE"), fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddDropdown("fontOutline", L("LABEL_FONT_OUTLINE"), { {text=L("OUTLINE_NONE"), value=""}, {text=L("OUTLINE_OUTLINE"), value="OUTLINE"}, {text=L("OUTLINE_THICK_OUTLINE"), value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)
    sb:AddSlider("fontSize", L("LABEL_FONT_SIZE"), 8, 36, 1, 12, elem, RefreshLive)
    sb:AddColor("textColor", L("LABEL_TEXT_COLOR"), {1, 1, 1, 1}, elem, RefreshLive)

    -- 3. Timing & FX Section
    sb:AddHeader(L("HEADER_TIMING_FX"))
    sb:AddSwitch("enableSafeZone", L("LABEL_SAFE_ZONE"), true, elem, RefreshLive)
    sb:AddColor("colorSafeZone", L("LABEL_SAFE_ZONE_COLOR"), {1.00, 0.28, 0.28, 0.35}, elem, RefreshLive)
    sb:AddSwitch("enableChannelTicks", L("LABEL_CHANNEL_TICKS"), true, elem, RefreshLive)
    sb:AddColor("colorChannelTicks", L("LABEL_CHANNEL_TICK_COLOR"), {0.18, 0.72, 1.00, 1.00}, elem, RefreshLive)
    sb:AddSwitch("enableSpark", L("LABEL_ENABLE_SPARK"), true, elem, RefreshLive)
    sb:AddColor("colorSpark", L("LABEL_SPARK_COLOR"), {1, 1, 1, 1}, elem, RefreshLive)
    sb:AddSlider("sparkWidth", L("LABEL_SPARK_WIDTH"), 5, 60, 1, 20, elem, RefreshLive)
    sb:AddSlider("sparkHeight", L("LABEL_SPARK_HEIGHT"), 5, 100, 1, 40, elem, RefreshLive)
    sb:AddSwitch("enableFlash", L("LABEL_COMPLETE_FLASH"), true, elem, RefreshLive)
    sb:AddColor("colorFlash", L("LABEL_FLASH_COLOR"), {1, 1, 1, 0.75}, elem, RefreshLive)
    sb:AddSlider("flashDuration", L("LABEL_CAST_FLASH_DURATION"), 0.05, 0.80, 0.05, 0.25, elem, RefreshLive)

    -- 4. Empower Section
    sb:AddHeader(L("HEADER_EMPOWER"))
    sb:AddSwitch("enableEmpowerStages", L("LABEL_EMPOWER_STAGES"), true, elem, RefreshLive)
    sb:AddColor("colorEmpowerBase", L("LABEL_EMPOWER_BASE_COLOR"), {1.00, 0.82, 0.28, 0.95}, elem, RefreshLive)
    sb:AddSwitch("empowerUseMarkerColors", L("LABEL_EMPOWER_COLORED_MARKERS"), true, elem, RefreshLive)
    sb:AddSwitch("empowerUseFillColors", L("LABEL_EMPOWER_ACTIVE_FILL"), true, elem, RefreshLive)

    -- Interactive Empower Preview Card (matches ResourceForge 1-to-1)
    local previewCard = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
    previewCard:SetSize(sb.fullWidth, 70)
    Skin:ApplyBackdrop(previewCard, 0.84, 1)
    previewCard:SetBackdropColor(0.05, 0.07, 0.09, 0.94)
    previewCard:SetBackdropBorderColor(0.15, 0.20, 0.24, 1)

    local previewBar = CreateFrame("Frame", nil, previewCard, "BackdropTemplate")
    previewBar:SetPoint("TOPLEFT", 12, -18)
    previewBar:SetPoint("TOPRIGHT", -12, -18)
    previewBar:SetHeight(32)
    Skin:ApplyBackdrop(previewBar, 0.92, 1)
    previewBar:SetBackdropColor(0.03, 0.04, 0.05, 0.98)
    previewBar:SetBackdropBorderColor(0.12, 0.16, 0.18, 1)

    local selectedEmpowerStage = 1
    local previewSegments = {}
    local previewMarkers = {}
    local stageLabels = { L("LABEL_EMPOWER_STAGE_1") or "Stage 1", L("LABEL_EMPOWER_STAGE_2") or "Stage 2", L("LABEL_EMPOWER_STAGE_3") or "Stage 3", L("LABEL_EMPOWER_STAGE_4") or "Stage 4" }

    local function LayoutEmpowerPreview()
        local width = previewBar:GetWidth()
        if not width or width <= 0 then return end
        local inset = 3
        local gap = 7
        local usableWidth = math.max(4, width - (inset * 2) - (gap * 3))
        local segmentWidth = math.floor(usableWidth / 4)
        local offsetX = inset

        for stageIndex = 1, 4 do
            local segment = previewSegments[stageIndex]
            segment:ClearAllPoints()
            segment:SetPoint("TOPLEFT", previewBar, "TOPLEFT", offsetX, -inset)
            segment:SetPoint("BOTTOMLEFT", previewBar, "BOTTOMLEFT", offsetX, inset)
            if stageIndex == 4 then
                segment:SetPoint("RIGHT", previewBar, "RIGHT", -inset, 0)
            else
                segment:SetWidth(segmentWidth)
            end
            offsetX = offsetX + segmentWidth + gap
        end

        for markerIndex = 1, 3 do
            local segment = previewSegments[markerIndex]
            local marker = previewMarkers[markerIndex]
            marker:ClearAllPoints()
            marker:SetPoint("TOP", segment, "TOPRIGHT", math.floor(gap * 0.5), 2)
            marker:SetPoint("BOTTOM", segment, "BOTTOMRIGHT", math.floor(gap * 0.5), -2)
        end
    end

    local UpdateEmpowerPreview

    local function OpenEmpowerStagePicker(stageIndex)
        selectedEmpowerStage = stageIndex
        local currentC = elem["colorEmpowerStage" .. stageIndex] or EMPOWER_STAGE_COLORS[stageIndex]
        local orig = { currentC[1] or currentC.r or 1, currentC[2] or currentC.g or 1, currentC[3] or currentC.b or 1, currentC[4] or currentC.a or 1 }

        Skin:ShowColorPicker({
            r = orig[1], g = orig[2], b = orig[3], opacity = orig[4],
            swatchFunc = function(c)
                elem["colorEmpowerStage" .. stageIndex] = { c[1], c[2], c[3], c[4] or 1 }
                if UpdateEmpowerPreview then UpdateEmpowerPreview() end
                RefreshLive()
            end,
            cancelFunc = function()
                elem["colorEmpowerStage" .. stageIndex] = orig
                if UpdateEmpowerPreview then UpdateEmpowerPreview() end
                RefreshLive()
            end,
        })
        if UpdateEmpowerPreview then UpdateEmpowerPreview() end
    end

    for stageIndex = 1, 4 do
        local segment = CreateFrame("Button", nil, previewBar, "BackdropTemplate")
        Skin:ApplyBackdrop(segment, 0.95, 1)
        segment.fill = segment:CreateTexture(nil, "ARTWORK")
        segment.fill:SetAllPoints()

        segment.text = segment:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        segment.text:SetPoint("CENTER")
        segment.text:SetFont(Skin.Constants.FONT_NORMAL, Skin.Constants.FONT_SIZE_NORMAL or 12, "OUTLINE")
        segment.text:SetText(stageLabels[stageIndex])

        segment:SetScript("OnClick", function()
            OpenEmpowerStagePicker(stageIndex)
        end)

        previewSegments[stageIndex] = segment
    end

    for markerIndex = 1, 3 do
        local marker = previewBar:CreateTexture(nil, "OVERLAY")
        marker:SetTexture("Interface\\Buttons\\WHITE8x8")
        marker:SetWidth(3)
        previewMarkers[markerIndex] = marker
    end

    UpdateEmpowerPreview = function()
        local isEnabled = (elem.enableEmpowerStages == nil) and true or elem.enableEmpowerStages
        local useFill = (elem.empowerUseFillColors == nil) and true or elem.empowerUseFillColors
        local useMarker = (elem.empowerUseMarkerColors == nil) and true or elem.empowerUseMarkerColors
        local baseColor = elem.colorEmpowerBase or {1.00, 0.82, 0.28, 0.95}

        previewCard:SetAlpha(isEnabled and 1 or 0.55)

        for stageIndex = 1, 4 do
            local seg = previewSegments[stageIndex]
            local stageC = elem["colorEmpowerStage" .. stageIndex] or EMPOWER_STAGE_COLORS[stageIndex]
            local displayC = useFill and stageC or baseColor
            local fillAlpha = useFill and 0.92 or (stageIndex == selectedEmpowerStage and 0.72 or 0.38)
            seg.fill:SetColorTexture(displayC[1] or displayC.r or 1, displayC[2] or displayC.g or 1, displayC[3] or displayC.b or 1, fillAlpha)

            if stageIndex == selectedEmpowerStage then
                seg:SetBackdropColor(0.10, 0.16, 0.19, 0.98)
                seg:SetBackdropBorderColor(0.18, 0.72, 1.00, 1)
                seg.text:SetTextColor(1, 1, 1, 1)
            else
                seg:SetBackdropColor(0.06, 0.08, 0.10, 0.95)
                seg:SetBackdropBorderColor(0.13, 0.17, 0.20, 1)
                seg.text:SetTextColor(0.86, 0.89, 0.91, 1)
            end

            if not isEnabled then
                seg.fill:SetColorTexture(stageC[1] or stageC.r or 1, stageC[2] or stageC.g or 1, stageC[3] or stageC.b or 1, 0.24)
            end
        end

        for mIndex = 1, 3 do
            local mStageC = elem["colorEmpowerStage" .. mIndex] or EMPOWER_STAGE_COLORS[mIndex]
            local mColor = useMarker and mStageC or baseColor
            previewMarkers[mIndex]:SetColorTexture(mColor[1] or mColor.r or 1, mColor[2] or mColor.g or 1, mColor[3] or mColor.b or 1, 0.95)
        end
    end

    previewBar:SetScript("OnSizeChanged", LayoutEmpowerPreview)
    LayoutEmpowerPreview()
    UpdateEmpowerPreview()

    sb:PlaceControlInRow(previewCard, { forceFullRow = true, rowHeight = 78 })

    -- 5. Borders Section
    sb:AddHeader(L("HEADER_BORDERS"))
    sb:AddSlider("barBorderSize", L("LABEL_CAST_BORDER_THICKNESS"), 0, 5, 0.1, 1, elem, RefreshLive)
    sb:AddColor("barBorderColor", L("LABEL_BAR_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddDropdown("barBorderPosition", L("LABEL_CAST_BORDER_PLACEMENT"), borderPosOptions, "OUTSIDE", elem, RefreshLive)

    sb:AddSlider("gcdBorderSize", L("LABEL_GCD_BORDER_THICKNESS"), 0, 5, 0.1, 1, elem, RefreshLive)
    sb:AddColor("gcdBorderColor", L("LABEL_GCD_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddDropdown("gcdBorderPosition", L("LABEL_GCD_BORDER_PLACEMENT"), borderPosOptions, "OUTSIDE", elem, RefreshLive)

    sb:AddSlider("iconBorderSize", L("LABEL_ICON_BORDER_THICKNESS"), 0, 5, 0.1, 1, elem, RefreshLive)
    sb:AddColor("iconBorderColor", L("LABEL_ICON_BORDER_COLOR"), {0.3, 0.3, 0.3, 1}, elem, RefreshLive)
    sb:AddDropdown("iconBorderPosition", L("LABEL_ICON_BORDER_PLACEMENT"), borderPosOptions, "OUTSIDE", elem, RefreshLive)

    sb:Finish()

    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() and child ~= parentFrame.testBtnCreated then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then bottomY = childBottom end
                end
            end
        end
        if f.content.SetHeight then f.content:SetHeight(math.abs(bottomY - 40)) end
    end
end
