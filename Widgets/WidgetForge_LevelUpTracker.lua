
local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.LevelUpTracker = _G.WidgetForge.LevelUpTracker or {}
local M = _G.WidgetForge.LevelUpTracker
addonTable.LevelUpTracker = M

M.Instances = M.Instances or {}
M.SessionStarts = M.SessionStarts or setmetatable({}, { __mode = "k" })

if not M.eventFrame then
    M.eventFrame = CreateFrame("Frame")
    M.eventFrame:SetScript("OnEvent", function(_, ev, ...) M:HandleEvent(ev, ...) end)
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function FNum(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local function FDur(s)
    s = math.max(0, math.floor(s or 0))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local ss = s % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, ss) end
    return string.format("%02d:%02d", m, ss)
end

local function NormRole(v)
    v = tostring(v or ""):upper()
    local ok = {
        AUTO_TOP = 1, AUTO_BOTTOM = 1,
        LEVEL = 1, PERCENT = 1, SUMMARY = 1,
        XP = 1, REMAIN = 1, RESTED = 1,
        ETA = 1, SESSION = 1, LAST = 1,
        EMPTY = 1,
    }
    return ok[v] and v or "EMPTY"
end

local function NormAlign(v)
    v = tostring(v or ""):upper()
    if v == "CENTER" then return "CENTER" end
    if v == "RIGHT" then return "RIGHT" end
    return "LEFT"
end

local function ParseMilestones(str)
    local out = {}
    if type(str) ~= "string" then return out end
    for token in string.gmatch(str, "([^,%s]+)") do
        local n = tonumber(token)
        if n and n > 0 then out[math.floor(n)] = true end
    end
    return out
end

local function TexturePath(key)
    local fallback = "Interface\\TargetingFrame\\UI-StatusBar"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures and key then
        return _G.ForgeSkin.Media.Textures[key] or fallback
    end
    return fallback
end

local function FontPath(key)
    local fallback = "Fonts\\FRIZQT__.TTF"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts and key then
        return _G.ForgeSkin.Media.Fonts[key] or fallback
    end
    return fallback
end

local function ApplyBackdrop(frame, edgeSize, bg, border)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = edgeSize or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if bg then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1) end
    if border then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

local SLOT_DEFS = {
    { id = "topLeft", label = "Top Left", offX = "topLeftOffsetX", offY = "topLeftOffsetY" },
    { id = "topCenter", label = "Top Center", offX = "topCenterOffsetX", offY = "topCenterOffsetY" },
    { id = "topRight", label = "Top Right", offX = "topRightOffsetX", offY = "topRightOffsetY" },
    { id = "bottomLeft", label = "Bottom Left", offX = "bottomLeftOffsetX", offY = "bottomLeftOffsetY" },
    { id = "bottomCenter", label = "Bottom Center", offX = "bottomCenterOffsetX", offY = "bottomCenterOffsetY" },
    { id = "bottomRight", label = "Bottom Right", offX = "bottomRightOffsetX", offY = "bottomRightOffsetY" },
}

local SIMPLE_ELEMS = {
    { text = "Level", value = "LEVEL", color = { 0.20, 0.55, 1.00, 0.85 } },
    { text = "Percent", value = "PERCENT", color = { 0.10, 0.70, 1.00, 0.85 } },
    { text = "XP", value = "XP", color = { 0.18, 0.72, 0.90, 0.85 } },
    { text = "Remaining", value = "REMAIN", color = { 0.85, 0.55, 0.15, 0.85 } },
    { text = "Rested", value = "RESTED", color = { 0.45, 0.80, 0.35, 0.85 } },
    { text = "ETA", value = "ETA", color = { 0.75, 0.50, 0.95, 0.85 } },
    { text = "Session", value = "SESSION", color = { 0.95, 0.75, 0.20, 0.85 } },
    { text = "Last Level", value = "LAST", color = { 0.92, 0.42, 0.42, 0.85 } },
    { text = "Summary", value = "SUMMARY", color = { 0.70, 0.70, 0.70, 0.85 } },
    { text = "Empty", value = "EMPTY", color = { 0.16, 0.16, 0.16, 0.85 } },
}

local function XPState()
    local cur = UnitXP("player") or 0
    local max = UnitXPMax("player") or 0
    local lvl = UnitLevel("player") or 0
    local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
    local isMax = max <= 0
    local pct = isMax and 100 or ((max > 0) and ((cur / max) * 100) or 0)
    local rem = isMax and 0 or math.max(0, max - cur)
    return { cur = cur, max = max, lvl = lvl, rested = rested, isMax = isMax, pct = pct, rem = rem }
end

local function AnnounceChannel(mode)
    if mode == "PARTY" then
        if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        if IsInGroup and IsInGroup() then return "PARTY" end
    elseif mode == "GUILD" then
        if IsInGuild and IsInGuild() then return "GUILD" end
    elseif mode == "SAY" then
        return "SAY"
    end
    return nil
end

local function Ensure(e)
    if not e then return end

    e.widgetWidth = e.widgetWidth or 340
    e.widgetHeight = e.widgetHeight or 74
    e.barHeight = e.barHeight or 16
    e.barOffsetY = e.barOffsetY or 0
    e.topRowNudgeX = e.topRowNudgeX or 0
    e.topRowNudgeY = e.topRowNudgeY or 0
    e.bottomRowNudgeX = e.bottomRowNudgeX or 0
    e.bottomRowNudgeY = e.bottomRowNudgeY or 0

    e.font = e.font or "Righteous"
    e.fontSize = e.fontSize or 12
    e.fontOutline = e.fontOutline or "OUTLINE"
    e.texture = e.texture or "2. Smooth"
    e.textColor = e.textColor or { 1, 1, 1, 1 }

    if e.compactMode == nil then e.compactMode = false end

    if e.topLeftRole == nil then e.topLeftRole = e.line1Role or "AUTO_TOP" end
    if e.topCenterRole == nil then e.topCenterRole = "EMPTY" end
    if e.topRightRole == nil then e.topRightRole = "EMPTY" end

    if e.bottomLeftRole == nil then e.bottomLeftRole = e.line2Role or "AUTO_BOTTOM" end
    if e.bottomCenterRole == nil then e.bottomCenterRole = "EMPTY" end
    if e.bottomRightRole == nil then e.bottomRightRole = "EMPTY" end

    e.topLeftAlign = e.topLeftAlign or "LEFT"
    e.topCenterAlign = e.topCenterAlign or "CENTER"
    e.topRightAlign = e.topRightAlign or "RIGHT"
    e.bottomLeftAlign = e.bottomLeftAlign or "LEFT"
    e.bottomCenterAlign = e.bottomCenterAlign or "CENTER"
    e.bottomRightAlign = e.bottomRightAlign or "RIGHT"

    e.topLeftOffsetX = 0
    e.topLeftOffsetY = 0
    e.topCenterOffsetX = 0
    e.topCenterOffsetY = 0
    e.topRightOffsetX = 0
    e.topRightOffsetY = 0

    e.bottomLeftOffsetX = 0
    e.bottomLeftOffsetY = 0
    e.bottomCenterOffsetX = 0
    e.bottomCenterOffsetY = 0
    e.bottomRightOffsetX = 0
    e.bottomRightOffsetY = 0
    e.unlockTextSlots = false
    if e.topAuto1 == nil then e.topAuto1 = "LEVEL" end
    if e.topAuto2 == nil then e.topAuto2 = "PERCENT" end
    if e.topAuto3 == nil then e.topAuto3 = "SESSION" end
    if e.bottomAuto1 == nil then e.bottomAuto1 = "XP" end
    if e.bottomAuto2 == nil then e.bottomAuto2 = "REMAIN" end
    if e.bottomAuto3 == nil then e.bottomAuto3 = "ETA" end

    if e.showDividers == nil then e.showDividers = false end
    e.dividerChar = (e.dividerChar and tostring(e.dividerChar) ~= "") and tostring(e.dividerChar) or "|"

    e.barStyle = e.barStyle or "SMOOTH"
    e.segmentCount = e.segmentCount or 20
    e.segmentGap = e.segmentGap or 1

    e.xpBarColor = e.xpBarColor or { 0.10, 0.70, 1.00, 1 }
    e.flashColor = e.flashColor or { 1.00, 0.85, 0.20, 1 }
    e.barBackgroundColor = e.barBackgroundColor or { 0, 0, 0, 0.22 }
    e.barBorderColor = e.barBorderColor or { 0.15, 0.15, 0.15, 1 }
    e.barBorderSize = e.barBorderSize or 1

    if e.enableNearLevelColor == nil then e.enableNearLevelColor = true end
    e.nearLevelThreshold = e.nearLevelThreshold or 85
    e.nearLevelColor = e.nearLevelColor or { 0.30, 1.00, 0.45, 1 }


    e.announceInChat = e.announceInChat or "OFF"
    e.milestoneLevels = e.milestoneLevels or "10,20,30,40,50,60,70,80"

    -- One-time reset for legacy layouts so row anchors start from exact bar edges.
    if e._layoutV2Applied ~= true then
        e.topRowNudgeX, e.topRowNudgeY = 0, 0
        e.bottomRowNudgeX, e.bottomRowNudgeY = 0, 0
        e._layoutV2Applied = true
    end

    e.topLeftRole = NormRole(e.topLeftRole)
    e.topCenterRole = NormRole(e.topCenterRole)
    e.topRightRole = NormRole(e.topRightRole)
    e.bottomLeftRole = NormRole(e.bottomLeftRole)
    e.bottomCenterRole = NormRole(e.bottomCenterRole)
    e.bottomRightRole = NormRole(e.bottomRightRole)
end

function M:EnsureSegmentPool(frame, count)
    frame.segmentPool = frame.segmentPool or {}
    for i = 1, count do
        if not frame.segmentPool[i] then
            local seg = CreateFrame("Frame", nil, frame.segmentContainer)
            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.fill = seg:CreateTexture(nil, "ARTWORK")
            seg.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            seg.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
            seg.bg:SetAllPoints(seg)
            seg.fill:SetAllPoints(seg)
            frame.segmentPool[i] = seg
        end
        frame.segmentPool[i]:Show()
    end
    for i = count + 1, #frame.segmentPool do
        frame.segmentPool[i]:Hide()
    end
    frame.segmentCountActive = count
end

function M:ApplyTextLayout(frame, e, now)
    if not frame.layout then return end
    local L = frame.layout
    local function place(fs, point, x, y, w, align)
        fs:ClearAllPoints()
        fs:SetPoint(point, frame.panel, "TOPLEFT", x, -y)
        fs:SetWidth(w)
        fs:SetHeight(L.lineH)
        fs:SetJustifyH(NormAlign(align))
        fs:SetJustifyV("MIDDLE")
    end

    local topShiftX = Clamp(tonumber(e.topRowNudgeX) or 0, -80, 80)
    local topShiftY = Clamp(tonumber(e.topRowNudgeY) or 0, -60, 60)
    local bottomShiftX = Clamp(tonumber(e.bottomRowNudgeX) or 0, -80, 80)
    local bottomShiftY = Clamp(tonumber(e.bottomRowNudgeY) or 0, -60, 60)

    place(frame.topLeft, "TOPLEFT", L.leftX + topShiftX, L.topY + topShiftY, L.slotW, "LEFT")
    place(frame.topCenter, "TOP", L.centerX + topShiftX, L.topY + topShiftY, L.slotW, "CENTER")
    place(frame.topRight, "TOPRIGHT", L.rightX + topShiftX, L.topY + topShiftY, L.slotW, "RIGHT")

    place(frame.bottomLeft, "TOPLEFT", L.leftX + bottomShiftX, L.bottomY + bottomShiftY, L.slotW, "LEFT")
    place(frame.bottomCenter, "TOP", L.centerX + bottomShiftX, L.bottomY + bottomShiftY, L.slotW, "CENTER")
    place(frame.bottomRight, "TOPRIGHT", L.rightX + bottomShiftX, L.bottomY + bottomShiftY, L.slotW, "RIGHT")

    local function placeDiv(fs, x, y)
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", frame.panel, "TOPLEFT", x, -y)
    end

    placeDiv(frame.topDiv1, L.topDiv1X + topShiftX, L.topY + topShiftY + (L.lineH * 0.5))
    placeDiv(frame.topDiv2, L.topDiv2X + topShiftX, L.topY + topShiftY + (L.lineH * 0.5))
    placeDiv(frame.bottomDiv1, L.bottomDiv1X + bottomShiftX, L.bottomY + bottomShiftY + (L.lineH * 0.5))
    placeDiv(frame.bottomDiv2, L.bottomDiv2X + bottomShiftX, L.bottomY + bottomShiftY + (L.lineH * 0.5))
end

function M:EnsureSlotHandles(frame)
    if frame.slotHandles then return end
    frame.slotHandles = {}
    for _, def in ipairs(SLOT_DEFS) do
        local h = CreateFrame("Frame", nil, frame.panel, "BackdropTemplate")
        h:SetFrameStrata("DIALOG")
        h:EnableMouse(true)
        h:RegisterForDrag("LeftButton")
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h.label:SetPoint("CENTER")
        h.label:SetText(def.label)
        ApplyBackdrop(h, 1, { 0.05, 0.55, 0.95, 0.25 }, { 0.20, 0.75, 1.00, 0.8 })

        h:SetScript("OnDragStart", function(selfRef)
            if not frame.elem or frame.elem.unlockTextSlots ~= true then return end
            local scale = frame:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            selfRef.dragStartX = cx / scale
            selfRef.dragStartY = cy / scale
            selfRef.baseOffX = tonumber(frame.elem[def.offX]) or 0
            selfRef.baseOffY = tonumber(frame.elem[def.offY]) or 0
            selfRef:SetScript("OnUpdate", function(updateRef)
                local mx, my = GetCursorPosition()
                mx, my = mx / scale, my / scale
                local dx = math.floor((mx - updateRef.dragStartX) + 0.5)
                local dy = math.floor((my - updateRef.dragStartY) + 0.5)
                frame.elem[def.offX] = updateRef.baseOffX + dx
                frame.elem[def.offY] = updateRef.baseOffY + dy
                M:ApplyTextLayout(frame, frame.elem, GetTime())
            end)
        end)

        h:SetScript("OnDragStop", function(selfRef)
            selfRef:SetScript("OnUpdate", nil)
            M:UpdateVisuals(frame, frame.elem)
            M:RefreshInstance(frame)
        end)

        frame.slotHandles[def.id] = h
    end
end

function M:UpdateSlotHandles(frame, e)
    if not frame then return end
    if frame.slotHandles then
        for _, h in pairs(frame.slotHandles) do
            if h then h:Hide() end
        end
    end
end

function M:UpdateVisuals(frame, e)
    if not frame or not e then return end
    Ensure(e)

    local w = math.max(180, e.widgetWidth or 340)
    local h = math.max(52, e.widgetHeight or 74)
    local pad = 8
    local barH = Clamp(math.floor(e.barHeight or 16), 8, math.max(8, h - 24))
    local barEdge = Clamp(tonumber(e.barBorderSize) or 1, 0, 8)

    frame:SetSize(w, h)
    frame.panel:SetAllPoints(frame)

    if frame.panel.SetBackdrop then frame.panel:SetBackdrop(nil) end

    local bg = e.barBackgroundColor or { 0, 0, 0, 0.22 }
    local border = e.barBorderColor or { 0.15, 0.15, 0.15, 1 }
    ApplyBackdrop(frame.barFrame, math.max(1, barEdge), bg, (barEdge > 0) and border or { 0, 0, 0, 0 })

    local barTexturePath = TexturePath(e.texture)
    frame.bar:SetStatusBarTexture(barTexturePath)

    local fp = FontPath(e.font)
    local textSize = math.max(9, e.fontSize or 12) + 1
    local textColor = e.textColor or { 1, 1, 1, 1 }

    for _, slot in ipairs({ frame.topLeft, frame.topCenter, frame.topRight, frame.bottomLeft, frame.bottomCenter, frame.bottomRight }) do
        slot:SetFont(fp, textSize, e.fontOutline or "OUTLINE")
        slot:SetTextColor(unpack(textColor))
        slot:SetWordWrap(false)
        if slot.SetMaxLines then slot:SetMaxLines(1) end
        slot:SetShadowOffset(1, -1)
    end

    for _, d in ipairs({ frame.topDiv1, frame.topDiv2, frame.bottomDiv1, frame.bottomDiv2 }) do
        d:SetFont(fp, textSize, e.fontOutline or "OUTLINE")
        d:SetTextColor(unpack(textColor))
        d:SetShadowOffset(1, -1)
        d:SetJustifyH("CENTER")
        d:SetJustifyV("MIDDLE")
    end

    if frame.sessionTimerFS then
        frame.sessionTimerFS:SetFont(fp, textSize, e.fontOutline or "OUTLINE")
        frame.sessionTimerFS:SetTextColor(unpack(textColor))
        frame.sessionTimerFS:SetShadowOffset(1, -1)
        frame.sessionTimerFS:SetJustifyV("MIDDLE")
    end

    local barTop = math.floor((h - barH) * 0.5) - (e.barOffsetY or 0)
    barTop = Clamp(barTop, pad, h - pad - barH)

    frame.barFrame:ClearAllPoints()
    frame.barFrame:SetPoint("TOPLEFT", frame.panel, "TOPLEFT", pad, -barTop)
    frame.barFrame:SetPoint("TOPRIGHT", frame.panel, "TOPRIGHT", -pad, -barTop)
    frame.barFrame:SetHeight(barH)

    local inset = math.min((barEdge > 0) and (barEdge + 1) or 1, math.max(1, math.floor((barH - 4) / 2)))
    frame.bar:ClearAllPoints()
    frame.bar:SetPoint("TOPLEFT", frame.barFrame, "TOPLEFT", inset, -inset)
    frame.bar:SetPoint("BOTTOMRIGHT", frame.barFrame, "BOTTOMRIGHT", -inset, inset)

    frame.segmentContainer:ClearAllPoints()
    frame.segmentContainer:SetPoint("TOPLEFT", frame.barFrame, "TOPLEFT", inset, -inset)
    frame.segmentContainer:SetPoint("BOTTOMRIGHT", frame.barFrame, "BOTTOMRIGHT", -inset, inset)

    local leftX = pad + inset
    local rightX = w - pad - inset
    do
        local panelLeft = frame.panel:GetLeft()
        local barLeft = frame.barFrame:GetLeft()
        local barRight = frame.barFrame:GetRight()
        if panelLeft and barLeft and barRight then
            leftX = math.floor((barLeft - panelLeft) + inset + 0.5)
            rightX = math.floor((barRight - panelLeft) - inset + 0.5)
        end
    end
    local innerW = math.max(40, rightX - leftX)
    local slotW = math.max(70, math.floor(innerW / 3))
    local centerX = math.floor(w * 0.5)
    local slot1Right = leftX + slotW
    local slot2Left = centerX - math.floor(slotW * 0.5)
    local slot2Right = centerX + math.floor(slotW * 0.5)
    local slot3Left = rightX - slotW
    local div1X = math.floor((slot1Right + slot2Left) * 0.5)
    local div2X = math.floor((slot2Right + slot3Left) * 0.5)

    local lineH = textSize + 6
    local topY = math.max(2, barTop - lineH - 6)
    local bottomY = math.min(h - lineH - 2, barTop + barH + 6)

    frame.layout = {
        slotW = slotW,
        lineH = lineH,
        leftX = leftX, centerX = centerX, rightX = rightX,
        topY = topY, bottomY = bottomY,
        topDiv1X = div1X,
        topDiv2X = div2X,
        bottomDiv1X = div1X,
        bottomDiv2X = div2X,
    }

    local segmented = tostring(e.barStyle or "SMOOTH") == "SEGMENTED"
    if segmented then
        local count = Clamp(math.floor(e.segmentCount or 20), 4, 80)
        local gap = Clamp(math.floor(e.segmentGap or 1), 0, 8)
        self:EnsureSegmentPool(frame, count)

        -- Use barFrame dimensions minus insets for reliable width
        local barFrameW = frame.barFrame:GetWidth()
        local barFrameH = frame.barFrame:GetHeight()
        if barFrameW <= 0 then barFrameW = (w - (pad * 2)) end
        if barFrameH <= 0 then barFrameH = barH end
        local cw = math.max(1, barFrameW - (inset * 2))
        local ch = math.max(1, barFrameH - (inset * 2))

        local totalGap = gap * (count - 1)
        local availableW = math.max(count, cw - totalGap)
        local segW = math.max(1, math.floor(availableW / count))

        for i = 1, count do
            local seg = frame.segmentPool[i]
            seg:ClearAllPoints()
            local xPos = (i - 1) * (segW + gap)
            local thisW = segW
            -- Last segment absorbs remaining pixels to fill edge-to-edge
            if i == count then
                thisW = math.max(1, cw - xPos)
            end
            seg:SetPoint("TOPLEFT", frame.segmentContainer, "TOPLEFT", xPos, 0)
            seg:SetSize(thisW, ch)
            seg.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
            seg.fill:SetTexture(barTexturePath)
        end

        frame.bar:Hide()
        frame.segmentContainer:Show()
    else
        frame.segmentContainer:Hide()
        frame.bar:Show()
    end

    self:ApplyTextLayout(frame, e, GetTime())
    self:UpdateSlotHandles(frame, e)
end

function M:RefreshInstance(frame)
    if not frame or not frame.elem then return end
    local e = frame.elem
    Ensure(e)

    local now = GetTime()
    local x = XPState()

    local start = self.SessionStarts[e]
    if not start then start = now; self.SessionStarts[e] = start end
    frame.startedAt = start

    frame.rateLevel = frame.rateLevel or x.lvl
    frame.rateElapsed = frame.rateElapsed or 0
    frame.rateGained = frame.rateGained or 0

    if x.lvl ~= frame.rateLevel then
        frame.rateLevel = x.lvl
        frame.rateElapsed = 0
        frame.rateGained = 0
        frame.lastXP = x.cur
        frame.lastXPTime = now
    else
        if frame.lastXPTime then
            local dt = math.max(0, now - frame.lastXPTime)
            local dx = x.cur - (frame.lastXP or 0)
            if dx < 0 then dx = 0 end
            if dt > 0 and dx > 0 then
                frame.rateElapsed = frame.rateElapsed + dt
                frame.rateGained = frame.rateGained + dx
            end
        end
        frame.lastXP = x.cur
        frame.lastXPTime = now
    end

    local pct = x.isMax and 100 or x.pct
    local sessionTimer = FDur(now - frame.startedAt)
    local last = frame.lastLevelUpAt and ("Last +" .. date("%H:%M", frame.lastLevelUpAt)) or ""

    local eta = ""
    if not x.isMax and frame.rateElapsed > 0 and frame.rateGained > 0 then
        local rate = frame.rateGained / frame.rateElapsed
        if rate > 0 then eta = "ETA " .. FDur(x.rem / rate) end
    end

    local divChar = (e.dividerChar and tostring(e.dividerChar) ~= "") and tostring(e.dividerChar) or "|"
    local autoDivider = "   "

    local map = {
        LEVEL = string.format("Lv %d", x.lvl),
        PERCENT = x.isMax and "MAX" or string.format("%.1f%%", pct),
        SUMMARY = string.format("Lv %d%s%s", x.lvl, autoDivider, x.isMax and "MAX" or string.format("%.1f%%", pct)),
        XP = x.isMax and "MAX" or (FNum(x.cur) .. " / " .. FNum(x.max)),
        REMAIN = x.isMax and "" or ("Remain " .. FNum(x.rem)),
        RESTED = (x.rested > 0) and ("Rested +" .. FNum(x.rested)) or "",
        ETA = eta,
        SESSION = "Session",
        LAST = last,
        EMPTY = "",
    }

    local function buildAutoLine(k1, k2, k3)
        local parts = {}
        local seen = {}
        for _, key in ipairs({ k1, k2, k3 }) do
            local r = NormRole(key)
            if r ~= "EMPTY" and not seen[r] then
                local txt = map[r] or ""
                if txt ~= "" then
                    parts[#parts + 1] = txt
                    seen[r] = true
                end
            end
        end
        return table.concat(parts, autoDivider)
    end

    map.AUTO_TOP = buildAutoLine(e.topAuto1, e.topAuto2, e.topAuto3)
    map.AUTO_BOTTOM = buildAutoLine(e.bottomAuto1, e.bottomAuto2, e.bottomAuto3)

    local function roleValue(role) return map[NormRole(role)] or "" end

    local tl = roleValue(e.topAuto1)
    local tc = roleValue(e.topAuto2)
    local tr = roleValue(e.topAuto3)
    local bl = roleValue(e.bottomAuto1)
    local bc = roleValue(e.bottomAuto2)
    local br = roleValue(e.bottomAuto3)

    frame.topLeft:SetText(tl)
    frame.topCenter:SetText(tc)
    frame.topRight:SetText(tr)
    frame.bottomLeft:SetText(bl)
    frame.bottomCenter:SetText(bc)
    frame.bottomRight:SetText(br)

    frame.topDiv1:SetText(divChar)
    frame.topDiv2:SetText(divChar)
    frame.bottomDiv1:SetText(divChar)
    frame.bottomDiv2:SetText(divChar)

    -- Session Timer: find which slot has SESSION and attach the timer FS next to it
    if frame.sessionTimerFS then
        local sessionSlotFS = nil
        local slotRoles = {
            { role = e.topAuto1, fs = frame.topLeft },
            { role = e.topAuto2, fs = frame.topCenter },
            { role = e.topAuto3, fs = frame.topRight },
            { role = e.bottomAuto1, fs = frame.bottomLeft },
            { role = e.bottomAuto2, fs = frame.bottomCenter },
            { role = e.bottomAuto3, fs = frame.bottomRight },
        }
        for _, info in ipairs(slotRoles) do
            if NormRole(info.role) == "SESSION" then
                sessionSlotFS = info.fs
                break
            end
        end
        if sessionSlotFS and sessionSlotFS:IsShown() then
            -- Measure max timer width using widest-digit template for current format tier
            local elapsed = now - (frame.startedAt or now)
            local timerTemplate = elapsed >= 3600 and "88:88:88" or "88:88"
            sessionSlotFS:SetText(timerTemplate)
            local timerMaxWidth = sessionSlotFS:GetStringWidth()
            if timerMaxWidth <= 0 then timerMaxWidth = elapsed >= 3600 and 58 or 38 end

            -- Timer stays in original slot (keeps native RIGHT/CENTER/LEFT position)
            sessionSlotFS:SetText(sessionTimer)

            -- "Session" label positioned at fixed offset before timer area
            frame.sessionTimerFS:ClearAllPoints()
            frame.sessionTimerFS:SetText("Session")
            frame.sessionTimerFS:SetJustifyH("RIGHT")
            frame.sessionTimerFS:SetPoint("RIGHT", sessionSlotFS, "RIGHT", -(timerMaxWidth + 4), 0)
            frame.sessionTimerFS:Show()
        else
            frame.sessionTimerFS:Hide()
        end
    end

    local showText = (e.compactMode ~= true) or (frame.isHovered == true)
    local function showSlot(slot, txt) if showText and txt ~= "" then slot:Show() else slot:Hide() end end

    showSlot(frame.topLeft, tl)
    showSlot(frame.topCenter, tc)
    showSlot(frame.topRight, tr)
    showSlot(frame.bottomLeft, bl)
    showSlot(frame.bottomCenter, bc)
    showSlot(frame.bottomRight, br)

    local showDiv = (e.showDividers == true and showText)
    if showDiv and tl ~= "" and tc ~= "" then frame.topDiv1:Show() else frame.topDiv1:Hide() end
    if showDiv and tc ~= "" and tr ~= "" then frame.topDiv2:Show() else frame.topDiv2:Hide() end
    if showDiv and bl ~= "" and bc ~= "" then frame.bottomDiv1:Show() else frame.bottomDiv1:Hide() end
    if showDiv and bc ~= "" and br ~= "" then frame.bottomDiv2:Show() else frame.bottomDiv2:Hide() end

    self:ApplyTextLayout(frame, e, now)
    self:UpdateSlotHandles(frame, e)

    local barColor = e.xpBarColor or { 0.10, 0.70, 1.00, 1 }
    if e.enableNearLevelColor == true and not x.isMax then
        if pct >= Clamp(e.nearLevelThreshold or 85, 1, 99) then
            barColor = e.nearLevelColor or { 0.30, 1.00, 0.45, 1 }
        end
    end

    if frame.flashUntil and now < frame.flashUntil then
        barColor = e.flashColor or { 1.00, 0.85, 0.20, 1 }
    else
        frame.flashUntil = nil
    end

    if tostring(e.barStyle or "SMOOTH") == "SEGMENTED" then
        local count = frame.segmentCountActive or 0
        local ratio = x.isMax and 1 or ((x.max > 0) and (x.cur / x.max) or 0)
        local filled = math.floor(ratio * count)
        local partialRatio = (ratio * count) - filled

        for i = 1, count do
            local seg = frame.segmentPool and frame.segmentPool[i]
            if seg then
                if i <= filled then
                    -- Fully filled segment
                    seg.fill:ClearAllPoints()
                    seg.fill:SetAllPoints(seg)
                    seg.fill:Show()
                    seg.fill:SetVertexColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
                elseif i == filled + 1 and partialRatio > 0.001 then
                    -- Partially filled segment
                    local segWidth = seg:GetWidth()
                    if segWidth <= 0 then segWidth = 10 end
                    seg.fill:ClearAllPoints()
                    seg.fill:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
                    seg.fill:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)
                    seg.fill:SetWidth(math.max(1, segWidth * partialRatio))
                    seg.fill:Show()
                    seg.fill:SetVertexColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
                else
                    -- Empty segment
                    seg.fill:Hide()
                end
            end
        end
    else
        frame.bar:SetMinMaxValues(0, x.isMax and 1 or math.max(1, x.max))
        frame.bar:SetValue(x.isMax and 1 or x.cur)
        frame.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4] or 1)
    end
end

function M:RefreshAll()
    for _, inst in ipairs(self.Instances) do self:RefreshInstance(inst) end
end

function M:HandleLevelUp(newLevel)
    local nowEpoch = time()
    local announceMode, milestones = nil, nil

    for _, inst in ipairs(self.Instances) do
        inst.lastLevelUpAt = nowEpoch
        inst.flashUntil = GetTime() + 3.0
        inst.rateLevel = newLevel or (UnitLevel("player") or inst.rateLevel)
        inst.rateElapsed = 0
        inst.rateGained = 0
        inst.lastXP = UnitXP("player") or 0
        inst.lastXPTime = GetTime()

        local e = inst.elem or {}
        if not announceMode and e.announceInChat and e.announceInChat ~= "OFF" then
            announceMode = e.announceInChat
            milestones = ParseMilestones(e.milestoneLevels or "")
        end
    end

    if announceMode and SendChatMessage then
        local channel = AnnounceChannel(announceMode)
        local lv = tonumber(newLevel) or (UnitLevel("player") or 0)
        local msg = ("Level Up! New level: %d"):format(lv)
        if milestones and milestones[lv] then msg = msg .. " (Milestone)" end

        if channel then
            if InCombatLockdown and InCombatLockdown() and channel == "SAY" then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WidgetForge] |r" .. msg)
                else
                    print(msg)
                end
            else
                pcall(SendChatMessage, msg, channel)
            end
        elseif announceMode == "SAY" then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[WidgetForge] |r" .. msg)
            else
                print(msg)
            end
        end
    end
end

function M:HandleEvent(ev, ...)
    if ev == "PLAYER_LEVEL_UP" then self:HandleLevelUp(tonumber((...))) end
    self:RefreshAll()
end

function M:RegisterEvents()
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
end

function M:UnregisterEvents()
    self.eventFrame:UnregisterAllEvents()
end

function M:Load(parent, elem)
    Ensure(elem)

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints(parent)
    frame:EnableMouse(true)
    frame.elem = elem

    frame.panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.panel:SetAllPoints(frame)

    frame.barFrame = CreateFrame("Frame", nil, frame.panel, "BackdropTemplate")
    frame.bar = CreateFrame("StatusBar", nil, frame.barFrame)
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)

    frame.segmentContainer = CreateFrame("Frame", nil, frame.barFrame)
    frame.segmentPool = {}

    frame.topLeft = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.topCenter = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.topRight = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.bottomLeft = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.bottomCenter = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.bottomRight = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    frame.topDiv1 = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.topDiv2 = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.bottomDiv1 = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.bottomDiv2 = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Dedicated timer FontString for SESSION (prevents label jitter)
    frame.sessionTimerFS = frame.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.sessionTimerFS:Hide()

    frame:SetScript("OnEnter", function(selfRef) selfRef.isHovered = true; M:RefreshInstance(selfRef) end)
    frame:SetScript("OnLeave", function(selfRef) selfRef.isHovered = false; M:RefreshInstance(selfRef) end)

    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(selfRef, dt)
        selfRef.elapsed = selfRef.elapsed + dt
        if selfRef.elapsed >= 0.2 then
            selfRef.elapsed = 0
            M:RefreshInstance(selfRef)
        end
    end)

    table.insert(self.Instances, frame)
    if #self.Instances == 1 then self:RegisterEvents() end

    if not self.SessionStarts[elem] then self.SessionStarts[elem] = GetTime() end
    frame.startedAt = self.SessionStarts[elem]

    self:UpdateVisuals(frame, elem)
    self:RefreshInstance(frame)

    frame.Unload = function(selfRef)
        selfRef:SetScript("OnUpdate", nil)
        for i = #M.Instances, 1, -1 do
            if M.Instances[i] == selfRef then table.remove(M.Instances, i); break end
        end
        if #M.Instances == 0 then M:UnregisterEvents() end
    end

    return frame
end

function M:CreateSettings(parentFrame)
    local f = parentFrame
    local e = f.config
    local barIndex = f.barIndex
    Ensure(e)

    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb

    local function RL()
        for _, inst in ipairs(M.Instances) do
            if inst.elem == e then
                M:UpdateVisuals(inst, e)
                M:RefreshInstance(inst)
            end
        end
        if barIndex and _G.WidgetForge then _G.WidgetForge:UpdateBarValues(barIndex, true) end
    end

    local texItems, fontItems = {}, {}
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures then
        for k in pairs(_G.ForgeSkin.Media.Textures) do texItems[#texItems + 1] = { text = tostring(k), value = k } end
        table.sort(texItems, function(a, b) return a.text < b.text end)
    end
    if #texItems == 0 then texItems = { { text = "Default", value = "" } } end

    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts then
        for k in pairs(_G.ForgeSkin.Media.Fonts) do fontItems[#fontItems + 1] = { text = tostring(k), value = k } end
        table.sort(fontItems, function(a, b) return a.text < b.text end)
    end
    if #fontItems == 0 then fontItems = { { text = "Friz Quadrata", value = "" } } end

    local outline = {
        { text = "None", value = "" }, { text = "Outline", value = "OUTLINE" },
        { text = "Thick", value = "THICKOUTLINE" }, { text = "Monochrome", value = "MONOCHROME" },
        { text = "Mono+Outline", value = "MONOCHROME,OUTLINE" },
    }
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Outlines and #_G.ForgeSkin.Media.Outlines > 0 then outline = _G.ForgeSkin.Media.Outlines end

    sb:AddHeader("Layout")
    sb:AddSlider("widgetWidth", "Widget Width", 180, 800, 5, 340, e, RL)
    sb:AddSlider("widgetHeight", "Widget Height", 52, 240, 1, 74, e, RL)
    sb:AddSlider("barHeight", "Bar Height", 8, 80, 1, 16, e, RL)
    sb:AddSlider("barOffsetY", "Bar Offset Y", -120, 120, 1, 0, e, RL)
    sb:AddSlider("topRowNudgeX", "Top Row Nudge X", -80, 80, 1, 0, e, RL)
    sb:AddSlider("topRowNudgeY", "Top Row Nudge Y", -60, 60, 1, 0, e, RL)
    sb:AddSlider("bottomRowNudgeX", "Bottom Row Nudge X", -80, 80, 1, 0, e, RL)
    sb:AddSlider("bottomRowNudgeY", "Bottom Row Nudge Y", -60, 60, 1, 0, e, RL)
    sb:AddSwitch("compactMode", "Compact Mode (hover text)", false, e, RL)

    sb:AddHeader("Element Lists")
    if sb.isRight then sb.y = sb.y - 50; sb.isRight = false end

    local roleText = {}
    local roleColor = {}
    local palette = {}
    for _, item in ipairs(SIMPLE_ELEMS) do
        roleText[item.value] = item.text
        roleColor[item.value] = item.color or { 0.25, 0.25, 0.25, 0.9 }
        palette[#palette + 1] = item
    end

    local function cfgKey(group, idx)
        if group == "top" then return "topAuto" .. idx end
        return "bottomAuto" .. idx
    end

    local function readSlot(group, idx)
        return NormRole(e[cfgKey(group, idx)] or "EMPTY")
    end

    local function writeSlot(group, idx, value)
        e[cfgKey(group, idx)] = NormRole(value or "EMPTY")
    end

    local slotButtons = {}
    local dragState = nil

    local function refreshSlotTexts()
        for _, btn in ipairs(slotButtons) do
            local role = readSlot(btn.groupId, btn.slotIndex)
            local title = roleText[role] or role
            if role == "EMPTY" then title = "Empty Slot" end
            btn.text:SetText(string.format("%d) %s", btn.slotIndex, title))
            local c = roleColor[role] or roleColor.EMPTY
            btn:SetBackdropColor(c[1], c[2], c[3], c[4] or 0.85)
        end
    end

    local function clearDraggedRoleFromOtherSlots(role, skipGroup, skipIndex)
        if not role or role == "EMPTY" then return end
        for _, g in ipairs({ "top", "bottom" }) do
            for i = 1, 3 do
                if not (g == skipGroup and i == skipIndex) and readSlot(g, i) == role then
                    writeSlot(g, i, "EMPTY")
                end
            end
        end
    end

    local function ensureGhost()
        if M._LevelTrackerDragGhost then return M._LevelTrackerDragGhost end
        local g = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        g:SetFrameStrata("TOOLTIP")
        g:SetSize(150, 24)
        g:EnableMouse(false)
        ApplyBackdrop(g, 1, { 0.04, 0.20, 0.32, 0.95 }, { 0.15, 0.65, 1.0, 1 })
        g.text = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        g.text:SetPoint("CENTER")
        M._LevelTrackerDragGhost = g
        return g
    end

    local function nearestSlot()
        local mx, my = GetCursorPosition()
        local closest, minDist = nil, 999999
        for _, btn in ipairs(slotButtons) do
            local scale = btn:GetEffectiveScale()
            local cx, cy = btn:GetCenter()
            if cx and cy then
                local sx, sy = cx * scale, cy * scale
                local dx, dy = (sx - mx), (sy - my)
                local dist = (dx * dx) + (dy * dy)
                if dist < minDist then
                    minDist = dist
                    closest = btn
                end
            end
        end
        return closest
    end

    local function clearSlotHighlights()
        for _, btn in ipairs(slotButtons) do
            btn:SetBackdropBorderColor(0.20, 0.20, 0.20, 1)
        end
    end

    local function beginDrag(kind, label, group, idx, role)
        local ghost = ensureGhost()
        dragState = { kind = kind, group = group, index = idx, role = role }
        ghost.text:SetText(label or "")
        ghost:Show()
    end

    local function stopDrag(applyDrop)
        local ghost = M._LevelTrackerDragGhost
        if ghost then ghost:Hide() end
        clearSlotHighlights()
        if not dragState then return end

        if applyDrop then
            local target = nearestSlot()
            if target then
                if dragState.kind == "slot" then
                    local srcGroup, srcIndex = dragState.group, dragState.index
                    local dstGroup, dstIndex = target.groupId, target.slotIndex
                    if not (srcGroup == dstGroup and srcIndex == dstIndex) then
                        local srcRole = readSlot(srcGroup, srcIndex)
                        local dstRole = readSlot(dstGroup, dstIndex)
                        writeSlot(srcGroup, srcIndex, dstRole)
                        writeSlot(dstGroup, dstIndex, srcRole)
                        refreshSlotTexts()
                        target:SetBackdropBorderColor(0.20, 1.00, 0.35, 1)
                        RL()
                    end
                elseif dragState.kind == "palette" then
                    clearDraggedRoleFromOtherSlots(dragState.role, target.groupId, target.slotIndex)
                    writeSlot(target.groupId, target.slotIndex, dragState.role)
                    refreshSlotTexts()
                    target:SetBackdropBorderColor(0.20, 1.00, 0.35, 1)
                    RL()
                end
            end
        end

        dragState = nil
    end

    local function createSlotButton(groupId, idx, x, y)
        local b = CreateFrame("Button", nil, f.content, "BackdropTemplate")
        b:SetSize(185, 28)
        b:SetPoint("TOPLEFT", x, y)
        b.groupId = groupId
        b.slotIndex = idx
        ApplyBackdrop(b, 1, { 0.08, 0.08, 0.08, 0.85 }, { 0.20, 0.20, 0.20, 1 })
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if idx == 1 then
            b.text:SetPoint("LEFT", 8, 0)
            b.text:SetJustifyH("LEFT")
        elseif idx == 2 then
            b.text:SetPoint("CENTER", 0, 0)
            b.text:SetJustifyH("CENTER")
        else
            b.text:SetPoint("RIGHT", -8, 0)
            b.text:SetJustifyH("RIGHT")
        end
        b.text:SetWidth(169)

        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function(selfRef)
            local role = readSlot(selfRef.groupId, selfRef.slotIndex)
            if role == "EMPTY" then return end
            beginDrag(
                "slot",
                roleText[role] or role,
                selfRef.groupId,
                selfRef.slotIndex,
                role
            )
        end)
        b:SetScript("OnDragStop", function() stopDrag(true) end)

        slotButtons[#slotButtons + 1] = b
        return b
    end

    local lblTop = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblTop:SetPoint("TOPLEFT", 10, sb.y - 2)
    lblTop:SetText("Top Row (drag slots to reorder)")

    local row1Y = sb.y - 24
    createSlotButton("top", 1, 10, row1Y)
    createSlotButton("top", 2, 210, row1Y)
    createSlotButton("top", 3, 410, row1Y)

    local lblBottom = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblBottom:SetPoint("TOPLEFT", 10, sb.y - 62)
    lblBottom:SetText("Bottom Row (drag slots to reorder)")

    local row2Y = sb.y - 84
    createSlotButton("bottom", 1, 10, row2Y)
    createSlotButton("bottom", 2, 210, row2Y)
    createSlotButton("bottom", 3, 410, row2Y)

    local lblPalette = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblPalette:SetPoint("TOPLEFT", 10, sb.y - 122)
    lblPalette:SetText("Element Palette (drag onto any slot)")

    local paletteColumns = 5
    local chipW, chipH = 112, 24
    local chipGapX, chipGapY = 8, 6
    local px, py = 10, sb.y - 144
    for i, item in ipairs(palette) do
        local itemText = item.text
        local itemValue = item.value
        local chip = CreateFrame("Button", nil, f.content, "BackdropTemplate")
        chip:SetSize(chipW, chipH)
        chip:SetPoint("TOPLEFT", px, py)
        local cc = roleColor[itemValue] or roleColor.EMPTY
        ApplyBackdrop(chip, 1, { cc[1], cc[2], cc[3], cc[4] or 0.9 }, { 0.15, 0.65, 1.0, 1 })
        local txt = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("CENTER")
        txt:SetText(itemText)
        chip:RegisterForDrag("LeftButton")
        chip:SetScript("OnDragStart", function()
            beginDrag("palette", itemText, nil, nil, itemValue)
        end)
        chip:SetScript("OnDragStop", function()
            stopDrag(true)
        end)
        chip:SetScript("OnClick", function()
            for _, g in ipairs({ "top", "bottom" }) do
                for si = 1, 3 do
                    if readSlot(g, si) == "EMPTY" then
                        clearDraggedRoleFromOtherSlots(itemValue, g, si)
                        writeSlot(g, si, itemValue)
                        refreshSlotTexts()
                        RL()
                        return
                    end
                end
            end
        end)

        px = px + chipW + chipGapX
        if (i % paletteColumns) == 0 then
            px = 10
            py = py - (chipH + chipGapY)
        end
    end

    f._levelTrackerDragTicker = f._levelTrackerDragTicker or CreateFrame("Frame", nil, f.content)
    f._levelTrackerDragTicker:SetScript("OnUpdate", function()
        if not dragState then return end
        local ghost = M._LevelTrackerDragGhost
        if ghost then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            ghost:ClearAllPoints()
            ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end
        clearSlotHighlights()
        local target = nearestSlot()
        if target then
            target:SetBackdropBorderColor(1, 0.8, 0, 1)
        end
    end)

    refreshSlotTexts()
    local paletteRows = math.ceil(#palette / paletteColumns)
    sb.y = sb.y - (165 + (paletteRows * (chipH + chipGapY)) + 16)

    sb:AddHeader("Text Style")
    sb:AddSlider("fontSize", "Font Size", 9, 30, 1, 12, e, RL)
    sb:AddDropdown("font", "Font Style", fontItems, "Righteous", e, RL)
    sb:AddDropdown("fontOutline", "Font Outline", outline, "OUTLINE", e, RL)
    sb:AddColor("textColor", "Text Color", { 1, 1, 1, 1 }, e, RL)

    sb:AddHeader("Text Extras")
    sb:AddSwitch("showDividers", "Show Dividers", false, e, RL)
    if sb.isRight then sb.y = sb.y - 50; sb.isRight = false end

    local lblDiv = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lblDiv:SetPoint("TOPLEFT", 10, sb.y - 2)
    lblDiv:SetText("Divider Character")

    local divFrame = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
    divFrame:SetSize(220, 28)
    divFrame:SetPoint("TOPLEFT", 10, sb.y - 22)
    if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(divFrame) end
    divFrame:SetBackdropColor(0, 0, 0, 0.5)

    local divBox = CreateFrame("EditBox", nil, divFrame)
    divBox:SetAllPoints(divFrame)
    divBox:SetTextInsets(6, 6, 0, 0)
    divBox:SetFontObject(ChatFontNormal)
    divBox:SetAutoFocus(false)
    divBox:SetText(e.dividerChar or "|")
    divBox:SetScript("OnTextChanged", function(self, user)
        if user then
            e.dividerChar = self:GetText()
            RL()
        end
    end)
    divBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    divBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RL() end)
    sb.y = sb.y - 50

    sb:AddHeader("Bar")
    sb:AddDropdown("texture", "Bar Texture", texItems, "2. Smooth", e, RL)
    sb:AddDropdown("barStyle", "Bar Style", { { text = "Smooth", value = "SMOOTH" }, { text = "Segmented", value = "SEGMENTED" } }, "SMOOTH", e, RL)
    sb:AddSlider("segmentCount", "Segment Count", 4, 80, 1, 20, e, RL)
    sb:AddSlider("segmentGap", "Segment Gap", 0, 8, 1, 1, e, RL)
    sb:AddColor("xpBarColor", "Bar Fill Color", { 0.10, 0.70, 1.00, 1 }, e, RL)
    sb:AddColor("barBackgroundColor", "Bar Background Color", { 0, 0, 0, 0.22 }, e, RL)
    sb:AddSlider("barBorderSize", "Bar Border Size", 0, 6, 1, 1, e, RL)
    sb:AddColor("barBorderColor", "Bar Border Color", { 0.15, 0.15, 0.15, 1 }, e, RL)
    sb:AddColor("flashColor", "Level-Up Flash Color", { 1.00, 0.85, 0.20, 1 }, e, RL)
    sb:AddSwitch("enableNearLevelColor", "Near Level Color Shift", true, e, RL)
    sb:AddSlider("nearLevelThreshold", "Near Level Threshold %", 1, 99, 1, 85, e, RL)
    sb:AddColor("nearLevelColor", "Near Level Color", { 0.30, 1.00, 0.45, 1 }, e, RL)

    sb:AddHeader("Level-Up Actions")

    sb:AddDropdown("announceInChat", "Announce In Chat", {{ text = "Off", value = "OFF" }, { text = "Party", value = "PARTY" }, { text = "Guild", value = "GUILD" }, { text = "Say", value = "SAY" }}, "OFF", e, RL)
    sb:Finish()

    if not f.content then return end
    local by = sb.y - 10

    local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 10, by)
    lbl:SetText("Milestone Levels (comma separated)")

    local ebf = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
    ebf:SetSize(340, 28)
    ebf:SetPoint("TOPLEFT", 10, by - 20)
    if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(ebf) end
    ebf:SetBackdropColor(0, 0, 0, 0.5)

    local eb = CreateFrame("EditBox", nil, ebf)
    eb:SetAllPoints(ebf)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetText(e.milestoneLevels or "10,20,30,40,50,60,70,80")
    eb:SetScript("OnTextChanged", function(self, user) if user then e.milestoneLevels = self:GetText() end end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RL() end)

    if f.content.SetHeight then f.content:SetHeight(math.abs(by) + 95) end
end

