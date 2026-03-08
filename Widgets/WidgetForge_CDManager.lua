local ForgeUI = _G.ForgeUI
if not ForgeUI then
    return
end

local Module = {
    holder = nil,
    eventFrame = nil,
    tickerFrame = nil,
    entries = {},
    viewerChildren = {},
    scanElapsed = 0,
    activeDrag = nil,
    noBarWarned = {},
}
local LCG = _G.LibStub and _G.LibStub("LibCustomGlow-1.0", true)
local GLOW_KEY = "forgeui_cd_pulse"
local SimpleMenu = CreateFrame("Frame", "ForgeUI_CooldownSimpleMenu", UIParent, "BackdropTemplate")
SimpleMenu:SetSize(220, 10)
SimpleMenu:SetFrameStrata("TOOLTIP")
SimpleMenu:SetFrameLevel(5000)
SimpleMenu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
SimpleMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
SimpleMenu:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
SimpleMenu:Hide()
SimpleMenu.buttons = {}

local function Clamp01(v, fallback)
    local n = tonumber(v)
    if not n then
        n = fallback or 0
    end
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function IsTruthy(v)
    if v == true or v == 1 then
        return true
    end
    if type(v) == "string" then
        local s = string.lower(v)
        return s == "true" or s == "1" or s == "yes" or s == "on"
    end
    return false
end

local function SafeTruthy(v, fallback)
    local ok, result = pcall(function()
        return v and true or false
    end)
    if ok then
        return result
    end
    return fallback and true or false
end

local function StopPulseGlow(frame)
    if not frame then
        return
    end
    frame._forgePulseGlowOn = nil
    frame._forgePulseGlowKind = nil
    frame._forgePulseGlowStyle = nil
    if LCG and LCG.PixelGlow_Stop then
        pcall(LCG.PixelGlow_Stop, LCG, frame.border or frame, GLOW_KEY)
    end
    if LCG and LCG.AutoCastGlow_Stop then
        pcall(LCG.AutoCastGlow_Stop, LCG, frame.border or frame, GLOW_KEY)
    end
    if LCG and LCG.ButtonGlow_Stop then
        pcall(LCG.ButtonGlow_Stop, LCG, frame.border or frame)
    end
end

local function StartPulseGlow(frame, cfg, kind)
    if not frame then
        return
    end
    if not LCG then
        return
    end
    local iconStyle = (cfg and cfg.iconStyle) or {}
    local isCooldown = (kind == "cooldown")
    local style = tostring(isCooldown and (iconStyle.cooldownPulseType or "autocast") or (iconStyle.buffPulseType or "pixel"))
    local speed = tonumber(isCooldown and iconStyle.cooldownPulseSpeed or iconStyle.buffPulseSpeed) or tonumber(iconStyle.pulseSpeed) or 3.0
    local freq = math.max(0.05, math.min(1.2, speed / 12))
    local color = {
        Clamp01(isCooldown and iconStyle.cooldownPulseR or iconStyle.buffPulseR, Clamp01(iconStyle.borderActiveR, 0.0)),
        Clamp01(isCooldown and iconStyle.cooldownPulseG or iconStyle.buffPulseG, Clamp01(iconStyle.borderActiveG, 0.75)),
        Clamp01(isCooldown and iconStyle.cooldownPulseB or iconStyle.buffPulseB, Clamp01(iconStyle.borderActiveB, 1.0)),
        Clamp01(isCooldown and iconStyle.cooldownPulseA or iconStyle.buffPulseA, Clamp01(iconStyle.borderActiveA, 1.0)),
    }

    if frame._forgePulseGlowOn and frame._forgePulseGlowKind == kind and frame._forgePulseGlowStyle == style then
        return
    end
    StopPulseGlow(frame)

    if style == "button" and LCG.ButtonGlow_Start then
        pcall(LCG.ButtonGlow_Start, LCG, frame.border or frame, color, freq)
    elseif style == "autocast" and LCG.AutoCastGlow_Start then
        pcall(LCG.AutoCastGlow_Start, LCG, frame.border or frame, color, 4, freq, 1, 0, 0, GLOW_KEY)
    elseif LCG.PixelGlow_Start then
        pcall(LCG.PixelGlow_Start, LCG, frame.border or frame, color, 8, freq, nil, 2, 0, 0, false, GLOW_KEY)
    end

    frame._forgePulseGlowOn = true
    frame._forgePulseGlowKind = kind
    frame._forgePulseGlowStyle = style
end

local function ShowSimpleMenu(items)
    if type(items) ~= "table" then
        return
    end

    local lineH = 20
    local count = 0
    for i = 1, #items do
        local it = items[i]
        if it and not it.isTitle then
            count = count + 1
            local btn = SimpleMenu.buttons[count]
            if not btn then
                btn = CreateFrame("Button", nil, SimpleMenu)
                btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
                btn:GetHighlightTexture():SetVertexColor(0.2, 0.2, 0.2, 0.35)
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
                btn.text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
                btn.text:SetJustifyH("LEFT")
                SimpleMenu.buttons[count] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", SimpleMenu, "TOPLEFT", 1, -1 - ((count - 1) * lineH))
            btn:SetPoint("TOPRIGHT", SimpleMenu, "TOPRIGHT", -1, -1 - ((count - 1) * lineH))
            btn:SetHeight(lineH)
            btn.text:SetText(it.text or "-")
            local clickFn = it.func
            btn:SetScript("OnClick", function()
                SimpleMenu:Hide()
                if clickFn then
                    clickFn()
                end
            end)
            btn:Show()
        end
    end

    for i = count + 1, #SimpleMenu.buttons do
        SimpleMenu.buttons[i]:Hide()
    end

    if count == 0 then
        return
    end

    SimpleMenu:SetHeight((count * lineH) + 2)

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    SimpleMenu:ClearAllPoints()
    SimpleMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 8, y - 8)
    SimpleMenu:Show()
end

local VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

local function SafeHideViewer(viewer)
    if not viewer then
        return
    end
    if viewer.SetAlpha then
        viewer:SetAlpha(0)
    end
    if viewer.EnableMouse then
        viewer:EnableMouse(false)
    end
    if viewer.IsShown and not viewer:IsShown() and viewer.Show then
        pcall(function()
            viewer:Show()
        end)
    end
end

local function SetCooldownFromSetValues(targetCooldown, startValue, durationValue)
    if not targetCooldown then
        return false
    end
    local ok = pcall(function()
        targetCooldown:SetCooldown(startValue, durationValue)
    end)
    return ok and targetCooldown:IsShown()
end

local function SetCooldownFromDuration(targetCooldown, durationObj)
    if not targetCooldown or not durationObj or not targetCooldown.SetCooldownFromDurationObject then
        return false
    end
    local ok = pcall(function()
        targetCooldown:SetCooldownFromDurationObject(durationObj)
    end)
    return ok and targetCooldown:IsShown()
end

local function TryDurationObjectFields(targetCooldown, info)
    if type(info) ~= "table" then
        return false
    end

    local fields = {
        info.durationObj,
        info.cooldownDuration,
        info.durationObject,
        info.chargeDuration,
    }

    for i = 1, #fields do
        if fields[i] and SetCooldownFromDuration(targetCooldown, fields[i]) then
            return true
        end
    end

    return false
end

local function SetCooldownFromSpellID(targetCooldown, spellID)
    if not targetCooldown then
        return false
    end
    if type(spellID) ~= "number" or not C_Spell then
        return false
    end

    if C_Spell.GetSpellCooldownDuration then
        local obj = C_Spell.GetSpellCooldownDuration(spellID)
        if SetCooldownFromDuration(targetCooldown, obj) then
            return true
        end
    end

    if C_Spell.GetSpellChargeDuration then
        local obj = C_Spell.GetSpellChargeDuration(spellID)
        if SetCooldownFromDuration(targetCooldown, obj) then
            return true
        end
    end

    if C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info and SetCooldownFromSetValues(targetCooldown, info.startTime, info.duration) then
            return true
        end
    end

    return false
end

local function ApplyChildCooldownToFrame(child, frame)
    if not child or not frame or not frame.cooldown then
        return false
    end

    pcall(function()
        frame.cooldown:SetCooldown(0, 0)
    end)

    local childCooldown = child.Cooldown or child.cooldown

    if childCooldown and childCooldown.GetCooldownDuration and frame.cooldown.SetCooldownFromDurationObject then
        local okDuration, durationObj = pcall(childCooldown.GetCooldownDuration, childCooldown)
        if okDuration and durationObj then
            local ok = pcall(function()
                frame.cooldown:SetCooldownFromDurationObject(durationObj)
            end)
            if ok and frame.cooldown:IsShown() then
                return true
            end
        end
    end

    local info = child.cooldownInfo
    if info then
        if TryDurationObjectFields(frame.cooldown, info) then
            return true
        end

        if SetCooldownFromSetValues(frame.cooldown, info.startTime, info.duration) then
            return true
        end

        local spellID = info.overrideSpellID or info.spellID or info.overrideTooltipSpellID
        if spellID and SetCooldownFromSpellID(frame.cooldown, spellID) then
            return true
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDuration and child.auraInstanceID then
        local unit = child.auraDataUnit or "player"
        local ok, auraDurationObj = pcall(C_UnitAuras.GetAuraDuration, unit, child.auraInstanceID)
        if ok and auraDurationObj and SetCooldownFromDuration(frame.cooldown, auraDurationObj) then
            return true
        end
    end

    return false
end

local function GetViewerChildIcon(child)
    if not child then
        return nil
    end
    if child.Icon and child.Icon.GetTexture then
        local t = child.Icon:GetTexture()
        if t then
            return t
        end
    end
    if child.icon and child.icon.GetTexture then
        local t = child.icon:GetTexture()
        if t then
            return t
        end
    end
    if child.GetNormalTexture then
        local nt = child:GetNormalTexture()
        if nt and nt.GetTexture then
            local t = nt:GetTexture()
            if t then
                return t
            end
        end
    end

    local info = child.cooldownInfo
    if info and C_Spell and C_Spell.GetSpellInfo then
        local spellID = info.overrideSpellID or info.spellID or info.overrideTooltipSpellID
        if spellID then
            local si = C_Spell.GetSpellInfo(spellID)
            if si and si.iconID then
                return si.iconID
            end
        end
    end
    return nil
end

local function GetViewerChildStack(child)
    if not child then
        return nil
    end

    local candidates = {
        child.Count,
        child.count,
        child.StackCount,
        child.stackCount,
    }

    for i = 1, #candidates do
        local obj = candidates[i]
        if obj then
            if obj.GetText then
                local t = obj:GetText()
                local n = tonumber(t)
                if n and n > 1 then
                    return n
                end
            elseif type(obj) == "number" and obj > 1 then
                return obj
            end
        end
    end

    local info = child.cooldownInfo
    if type(info) == "table" then
        local n = tonumber(info.stackCount or info.count or info.charges)
        if n and n > 1 then
            return n
        end
    end

    return nil
end

local function GetViewerChildLabel(child)
    if not child then
        return ""
    end
    if child.Name and child.Name.GetText then
        local t = child.Name:GetText()
        if t and t ~= "" then
            return t
        end
    end
    local info = child.cooldownInfo
    if info and C_Spell and C_Spell.GetSpellInfo then
        local spellID = info.overrideSpellID or info.spellID or info.overrideTooltipSpellID
        if spellID then
            local si = C_Spell.GetSpellInfo(spellID)
            if si and si.name then
                return si.name
            end
        end
    end
    return ""
end

local function FindChildBarSource(child)
    if not child then
        return nil
    end

    local candidates = {
        child.Bar,
        child.bar,
        child.StatusBar,
        child.statusBar,
        child.ProgressBar,
        child.progressBar,
    }
    for i = 1, #candidates do
        local b = candidates[i]
        if b and b.GetObjectType and b:GetObjectType() == "StatusBar" then
            return b
        end
    end

    if child.GetRegions then
        local regions = { child:GetRegions() }
        for i = 1, #regions do
            local r = regions[i]
            if r and r.GetObjectType and r:GetObjectType() == "StatusBar" then
                return r
            end
        end
    end

    return nil
end

local function UpdateFrameBarFromSource(frame, cfg)
    if not frame or not frame.barStatus or not frame.sourceBar then
        return false
    end

    local okRange, minValue, maxValue = pcall(frame.sourceBar.GetMinMaxValues, frame.sourceBar)
    local okValue, currentValue = pcall(frame.sourceBar.GetValue, frame.sourceBar)
    if not okRange or not okValue or minValue == nil or maxValue == nil or currentValue == nil then
        return false
    end

    local okApply = pcall(function()
        frame.barStatus:SetMinMaxValues(minValue, maxValue)
        frame.barStatus:SetValue(currentValue)
        local barStyle = (cfg and cfg.barStyle) or {}
        if frame.sourceBar.GetStatusBarColor and frame.barStatus.SetStatusBarColor and (barStyle.useSourceColor ~= false) then
            local r, g, b, a = frame.sourceBar:GetStatusBarColor()
            frame.barStatus:SetStatusBarColor(r or 1, g or 1, b or 1, a or 1)
        elseif frame.barStatus.SetStatusBarColor then
            frame.barStatus:SetStatusBarColor(
                Clamp01(barStyle.fillR, 0.85),
                Clamp01(barStyle.fillG, 0.72),
                Clamp01(barStyle.fillB, 0.2),
                Clamp01(barStyle.fillA, 0.95)
            )
        end
        if frame.sourceBar.GetReverseFill and frame.barStatus.SetReverseFill then
            frame.barStatus:SetReverseFill(frame.sourceBar:GetReverseFill() and true or false)
        end
    end)
    return okApply
end

local function BuildEntryKey(ref, child)
    local info = child and child.cooldownInfo
    local spellID = info and (info.overrideSpellID or info.spellID or info.overrideTooltipSpellID) or 0
    local actionSlot = child and child.action or 0
    local auraID = child and child.auraInstanceID or 0

    -- Keep a stable key for manual positioning.
    -- spellID is stable across updates; auraInstanceID/index are not.
    if spellID and spellID > 0 then
        return table.concat({
            ref.viewerName or "viewer",
            "spell",
            tostring(spellID),
            tostring(actionSlot or 0),
        }, ":")
    end

    return table.concat({
        ref.viewerName or "viewer",
        "aura",
        tostring(auraID or 0),
        tostring(ref.idx or 0),
    }, ":")
end

local function GetChildPreferredMode(child, cfg, viewerName)
    if not child then
        return "icon"
    end
    if cfg and cfg.preferNativeBars and viewerName == "BuffBarCooldownViewer" then
        return "bar"
    end
    if cfg and cfg.preferNativeBars and child.cooldownInfo and child.cooldownInfo.viewer and child.cooldownInfo.viewer == "bar" then
        return "bar"
    end
    if cfg and cfg.preferNativeBars and child.GetObjectType and child:GetObjectType() == "StatusBar" then
        return "bar"
    end
    if cfg and cfg.preferNativeBars and child.Bar and child.Bar.GetObjectType and child.Bar:GetObjectType() == "StatusBar" then
        return "bar"
    end
    if cfg and cfg.preferNativeBars and child.GetName and child:GetName() and string.find(child:GetName(), "BuffBar", 1, true) then
        return "bar"
    end
    return "icon"
end

local function GetRenderMode(cfg, key, child, viewerName)
    if cfg and type(cfg.renderModeByKey) == "table" and cfg.renderModeByKey[key] then
        return cfg.renderModeByKey[key]
    end
    return GetChildPreferredMode(child, cfg, viewerName)
end

local function ApplyRenderMode(frame, mode, iconSize, cfg)
    if not frame then
        return
    end

    local iconStyle = (cfg and cfg.iconStyle) or {}
    local barStyle = (cfg and cfg.barStyle) or {}
    local iconZoom = Clamp01(iconStyle.iconZoom, 0.08)
    local pad = math.max(1, math.floor((iconSize or 30) * iconZoom))

    if mode == "bar" then
        frame.mode = "bar"
        StopPulseGlow(frame)
        local h = math.max(18, math.floor((iconSize or 30) * (tonumber(barStyle.heightMultiplier) or 1.0)))
        local w = math.max(120, math.floor((iconSize or 30) * (tonumber(barStyle.widthMultiplier) or 4.4)))
        w = math.max(w, tonumber(barStyle.minWidth) or 170)
        frame:SetSize(w, h)
        frame.stack:SetShown(iconStyle.showStackNumbers ~= false)
        frame.border:SetBackdropBorderColor(
            Clamp01(barStyle.borderR, 0.65),
            Clamp01(barStyle.borderG, 0.55),
            Clamp01(barStyle.borderB, 0.2),
            Clamp01(barStyle.borderA, 1.0)
        )
        frame.icon:ClearAllPoints()
        local showBarIcon = barStyle.showIcon ~= false
        frame.icon:SetShown(showBarIcon)
        if showBarIcon then
            frame.icon:SetPoint("LEFT", frame, "LEFT", 1, 0)
            frame.icon:SetSize(h - 2, h - 2)
        else
            frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
            frame.icon:SetSize(1, 1)
        end
        frame.cooldown:SetAllPoints(frame.icon)
        frame.cooldown:SetHideCountdownNumbers(true)
        frame.cooldown:SetAlpha(0)
        frame.barBG:Show()
        frame.barStatus:Show()
        frame.barBG:SetVertexColor(
            Clamp01(barStyle.bgR, 0.08),
            Clamp01(barStyle.bgG, 0.08),
            Clamp01(barStyle.bgB, 0.08),
            Clamp01(barStyle.bgA, 0.8)
        )
        if frame.barStatus.SetStatusBarColor then
            frame.barStatus:SetStatusBarColor(
                Clamp01(barStyle.fillR, 0.85),
                Clamp01(barStyle.fillG, 0.72),
                Clamp01(barStyle.fillB, 0.2),
                Clamp01(barStyle.fillA, 0.95)
            )
        end
        frame.barText:SetShown(barStyle.showLabel ~= false)
        frame.barText:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, math.floor(tonumber(barStyle.textSize) or 11)), "OUTLINE")
    else
        frame.mode = "icon"
        local iconMul = tonumber(iconStyle.sizeMultiplier) or 1.0
        local s = math.max(16, math.floor((iconSize or 30) * iconMul))
        frame:SetSize(s, s)
        frame.stack:SetShown(iconStyle.showStackNumbers ~= false)
        frame.border:SetBackdropBorderColor(
            Clamp01(iconStyle.borderNormalR, 0.18),
            Clamp01(iconStyle.borderNormalG, 0.18),
            Clamp01(iconStyle.borderNormalB, 0.18),
            Clamp01(iconStyle.borderNormalA, 1.0)
        )
        frame.icon:ClearAllPoints()
        frame.icon:SetShown(true)
        frame.icon:SetPoint("TOPLEFT", pad, -pad)
        frame.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
        frame.cooldown:SetAllPoints(frame.icon)
        frame.cooldown:SetHideCountdownNumbers(iconStyle.showCooldownNumbers == false)
        frame.cooldown:SetAlpha(1)
        frame.barBG:Hide()
        frame.barStatus:Hide()
        frame.barText:Hide()
    end
end

local function UpdateIconBorderVisual(frame, cfg)
    if not frame or frame.mode ~= "icon" or not frame.border or not frame.border.SetBackdropBorderColor then
        StopPulseGlow(frame)
        return
    end
    local iconStyle = (cfg and cfg.iconStyle) or {}
    local nr = Clamp01(iconStyle.borderNormalR, 0.18)
    local ng = Clamp01(iconStyle.borderNormalG, 0.18)
    local nb = Clamp01(iconStyle.borderNormalB, 0.18)
    local na = Clamp01(iconStyle.borderNormalA, 1.0)
    local ar = Clamp01(iconStyle.borderActiveR, 0.0)
    local ag = Clamp01(iconStyle.borderActiveG, 0.75)
    local ab = Clamp01(iconStyle.borderActiveB, 1.0)
    local aa = Clamp01(iconStyle.borderActiveA, 1.0)

    local pulseEnabled = IsTruthy(iconStyle.activeBorderPulse)
    local allowCooldownPulse = IsTruthy(iconStyle.pulseOnCooldowns)
    local ignoreGCD = IsTruthy(iconStyle.ignoreGCDPulse)
    local cooldownAllowed = allowCooldownPulse and frame.cooldownIsActive == true and not (ignoreGCD and frame.cooldownIsGCD == true)
    local pulseKind = nil
    if frame.buffIsActive == true then
        pulseKind = "buff"
    elseif cooldownAllowed then
        pulseKind = "cooldown"
    end

    if not pulseEnabled then
        StopPulseGlow(frame)
        frame.border:SetBackdropBorderColor(nr, ng, nb, na)
        return
    end

    if pulseKind then
        frame.border:SetBackdropBorderColor(ar, ag, ab, aa)
        StartPulseGlow(frame, cfg, pulseKind)
    else
        StopPulseGlow(frame)
        frame.border:SetBackdropBorderColor(nr, ng, nb, na)
    end
end

local function EnsureHolder(self, cfg)
    if self.holder then
        self.holder:ClearAllPoints()
        self.holder:SetPoint(cfg.splitPoint or "CENTER", UIParent, cfg.splitPoint or "CENTER", cfg.splitX or 0, cfg.splitY or -140)
        return
    end

    self.holder = ForgeUI:CreateHolder(
        "ForgeUI_CooldownSplitHolder",
        64,
        32,
        cfg.splitPoint or "CENTER",
        UIParent,
        cfg.splitPoint or "CENTER",
        cfg.splitX or 0,
        cfg.splitY or -140
    )
    self.holder:SetFrameStrata("TOOLTIP")
    self.holder:SetFrameLevel(200)

    self.holder.title = self.holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.holder.title:SetPoint("BOTTOMLEFT", self.holder, "TOPLEFT", 2, 4)
    self.holder.title:SetText(cfg.groupHeaderText or "Tracked Bars")

    self.holder.lockText = self.holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.holder.lockText:SetPoint("BOTTOMRIGHT", self.holder, "TOPRIGHT", -2, 4)
end

local function EnsureEntryFrame(key, cfg, parent)
    local entry = Module.entries[key]
    if entry then
        return entry
    end

    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(cfg.splitIconSize or 30, cfg.splitIconSize or 30)

    if _G.ForgeSkin and _G.ForgeSkin.ApplyBackdrop then
        _G.ForgeSkin:ApplyBackdrop(f, 0.9, 1)
    else
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetDrawBling(false)
    f.cooldown:SetDrawEdge(false)
    f.cooldown:SetHideCountdownNumbers(false)
    f.cooldown:EnableMouse(false)

    f.remain = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.remain:SetPoint("BOTTOMRIGHT", -2, 2)
    f.remain:SetText("")

    f.stack = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.stack:SetPoint("TOPRIGHT", -2, -2)
    f.stack:SetText("")

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetFrameLevel(f:GetFrameLevel() + 4)
    f.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f.border:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

    f.barBG = f:CreateTexture(nil, "BACKGROUND")
    f.barBG:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 4, 0)
    f.barBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.barBG:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.barBG:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    f.barBG:Hide()

    f.barStatus = CreateFrame("StatusBar", nil, f)
    f.barStatus:SetPoint("TOPLEFT", f.barBG, "TOPLEFT", 1, -1)
    f.barStatus:SetPoint("BOTTOMRIGHT", f.barBG, "BOTTOMRIGHT", -1, 1)
    f.barStatus:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.barStatus:SetStatusBarColor(0.85, 0.72, 0.2, 0.95)
    f.barStatus:SetMinMaxValues(0, 1)
    f.barStatus:SetValue(0)
    f.barStatus:Hide()

    f.barText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.barText:SetPoint("LEFT", f.barBG, "LEFT", 4, 0)
    f.barText:SetPoint("RIGHT", f.barBG, "RIGHT", -4, 0)
    f.barText:SetJustifyH("LEFT")
    f.barText:SetText("")
    f.barText:Hide()

    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            Module:OpenContextMenu(self)
            return
        end
        if button ~= "LeftButton" or not Module:IsUnlockEnabled() then
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            Module:UngroupEntry(self.entryKey, self)
        end
        self.isDragging = true
        Module:BeginGroupDrag(self)
        self:StartMoving()
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        if self.isDragging then
            self:StopMovingOrSizing()
            self.isDragging = nil
            Module:HandleDrop(self)
        end
    end)
    f:SetScript("OnHide", function(self)
        if self.isDragging then
            self:StopMovingOrSizing()
            self.isDragging = nil
        end
    end)
    f:SetScript("OnUpdate", function(self)
        if self.isDragging then
            Module:UpdateGroupDragVisual(self)
        end
    end)

    Module.entries[key] = f
    return f
end

function Module:ScanViewerChildren()
    wipe(self.viewerChildren)

    for _, viewerName in ipairs(VIEWER_NAMES) do
        local viewer = _G[viewerName]
        if viewer then
            SafeHideViewer(viewer)
            local children = { viewer:GetChildren() }
            for i = 1, #children do
                local child = children[i]
                if child and child.cooldownInfo then
                    tinsert(self.viewerChildren, { viewerName = viewerName, child = child, idx = i })
                end
            end
        end
    end
end

function Module:RefreshAll()
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    if not cfg.enabled or not cfg.splitEnabled then
        if self.holder then
            self.holder:Hide()
        end
        return
    end

    EnsureHolder(self, cfg)
    self.holder:Show()
    if self.holder.title then
        self.holder.title:SetShown(cfg.groupShowHeader ~= false)
        self.holder.title:SetText(cfg.groupHeaderText or "Tracked Bars")
    end
    if self.holder.lockText then
        self.holder.lockText:SetText(self:IsUnlockEnabled() and "Unlocked" or "Locked")
    end
    self:ScanViewerChildren()

    local iconSize = math.max(20, tonumber(cfg.splitIconSize) or 30)
    local spacing = math.max(2, tonumber(cfg.splitSpacing) or 4)

    local visible = {}
    local seen = {}
    local byKey = {}

    for i = 1, #self.viewerChildren do
        local ref = self.viewerChildren[i]
        local child = ref.child
        local key = BuildEntryKey(ref, child)
        local frame = EnsureEntryFrame(key, cfg, self.holder)
        frame.entryKey = key

        local icon = GetViewerChildIcon(child) or "Interface\\Icons\\INV_Misc_QuestionMark"
        frame.icon:SetTexture(icon)
        local stackCount = GetViewerChildStack(child)
        frame.stack:SetText(stackCount and tostring(stackCount) or "")
        frame.barText:SetText(GetViewerChildLabel(child))
        local mode = GetRenderMode(cfg, key, child, ref.viewerName)
        frame.renderMode = mode
        ApplyRenderMode(frame, frame.renderMode, iconSize, cfg)

        local active = ApplyChildCooldownToFrame(child, frame)
        local childCooldown = child and (child.Cooldown or child.cooldown)
        local childShown = child and child.IsShown and child:IsShown()
        local cooldownShown = childCooldown and childCooldown.IsShown and childCooldown:IsShown()
        local viewerName = tostring(ref.viewerName or "")
        local isBuffViewer = string.find(viewerName, "Buff", 1, true) ~= nil
        local childOnGCD = false
        local okGCD, gcdValue = pcall(function()
            if child and child.cooldownInfo and child.cooldownInfo.isOnGCD ~= nil then
                return child.cooldownInfo.isOnGCD
            end
            return child and child.isOnGCD
        end)
        if okGCD then
            childOnGCD = SafeTruthy(gcdValue, false)
        end

        frame.cooldownDuration = nil
        frame.cooldownIsActive = active and true or false
        frame.cooldownIsGCD = childOnGCD
        frame.buffIsActive = isBuffViewer and (childShown or (child and child.auraInstanceID ~= nil)) and true or false

        local rawActive = (active or childShown or cooldownShown) and true or false
        local now = GetTime()
        if rawActive then
            frame.activeVisualUntil = now + 0.25
        elseif frame.activeVisualUntil and now < frame.activeVisualUntil then
            rawActive = true
        else
            frame.activeVisualUntil = nil
        end
        frame.isActive = rawActive

        if frame.isActive then
            if frame.mode == "bar" then
                frame:SetAlpha(Clamp01(cfg.barStyle and cfg.barStyle.activeAlpha, 1.0))
            else
                frame:SetAlpha(Clamp01(cfg.iconStyle and cfg.iconStyle.activeAlpha, 1.0))
            end
        else
            pcall(function()
                frame.cooldown:SetCooldown(0, 0)
            end)
            if frame.mode == "bar" then
                frame:SetAlpha(Clamp01(cfg.barStyle and cfg.barStyle.inactiveAlpha, 0.55))
            else
                frame:SetAlpha(Clamp01(cfg.iconStyle and cfg.iconStyle.inactiveAlpha, 0.45))
            end
        end

        local nativeBarSource = FindChildBarSource(child)
        frame.nativeBarSource = nativeBarSource
        frame.hasNativeBar = nativeBarSource ~= nil

        if frame.renderMode == "bar" then
            frame.sourceBar = nativeBarSource
            if not UpdateFrameBarFromSource(frame, cfg) then
                frame.renderMode = "icon"
                ApplyRenderMode(frame, "icon", iconSize, cfg)
                if cfg.renderModeByKey and cfg.renderModeByKey[key] == "bar" then
                    cfg.renderModeByKey[key] = "icon"
                    if not self.noBarWarned[key] then
                        self.noBarWarned[key] = true
                        ForgeUI:Print("Bar mode only works for Blizzard native bar sources. Reverted to icon: " .. tostring(key))
                    end
                end
            end
        else
            frame.sourceBar = nil
        end

        UpdateIconBorderVisual(frame, cfg)
        frame.remain:SetText("")
        frame.icon:SetDesaturated((not frame.isActive) and (cfg.iconStyle and cfg.iconStyle.desaturateInactive))
        frame.sortKey = key
        frame:Show()
        byKey[key] = frame

        seen[key] = true
        tinsert(visible, frame)
    end

    for key, frame in pairs(self.entries) do
        if not seen[key] then
            StopPulseGlow(frame)
            frame:Hide()
        end
    end

    table.sort(visible, function(a, b)
        return tostring(a.sortKey or a) < tostring(b.sortKey or b)
    end)

    if #visible == 0 then
        self.holder:SetSize(64, 32)
        return
    end

    local columns = math.max(1, tonumber(cfg.splitColumns) or 8)
    columns = math.min(columns, #visible)
    local rows = math.ceil(#visible / columns)

    self.holder:SetSize((columns * iconSize) + ((columns - 1) * spacing) + 8, (rows * iconSize) + ((rows - 1) * spacing) + 8)

    local freeMode = cfg.iconPositions and type(cfg.iconPositions) == "table"
    for index, frame in ipairs(visible) do
        local isInActiveDrag = self.activeDrag and self.activeDrag.members and self.activeDrag.members[frame.entryKey]
        if frame.isDragging or isInActiveDrag then
            frame:EnableMouse(true)
        else
            local pos = freeMode and cfg.iconPositions[frame.entryKey] or nil
            frame:ClearAllPoints()

            if pos and pos.point and pos.x and pos.y then
                frame:SetPoint(pos.point, UIParent, pos.relPoint or "CENTER", pos.x, pos.y)
            else
                local row = math.floor((index - 1) / columns)
                local col = (index - 1) % columns
                frame:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 4 + col * (iconSize + spacing), -4 - row * (iconSize + spacing))
            end

            ApplyRenderMode(frame, frame.renderMode, iconSize, cfg)
            frame:EnableMouse(self:IsUnlockEnabled())
        end
    end

    local groups = {}
    if type(cfg.iconGroups) == "table" then
        for key, frame in pairs(byKey) do
            local anchor = cfg.iconGroups[key]
            if anchor and byKey[anchor] then
                groups[anchor] = groups[anchor] or {}
                tinsert(groups[anchor], key)
            end
        end
    end

    for anchor, members in pairs(groups) do
        if byKey[anchor] then
            local hasAnchor = false
            for i = 1, #members do
                if members[i] == anchor then
                    hasAnchor = true
                    break
                end
            end
            if not hasAnchor then
                tinsert(members, 1, anchor)
            end
        end

        if #members >= 2 then
            local direction = tostring((cfg.iconGroupDirection and cfg.iconGroupDirection[anchor]) or cfg.groupDirection or "HORIZONTAL")
            local horizontal = direction ~= "VERTICAL"
            table.sort(members, function(a, b)
                if a == anchor then
                    return true
                end
                if b == anchor then
                    return false
                end
                return tostring(a) < tostring(b)
            end)

            local anchorPos = cfg.iconPositions and cfg.iconPositions[anchor] or nil
            local baseX = nil
            local baseY = nil
            if anchorPos and type(anchorPos.x) == "number" and type(anchorPos.y) == "number" then
                baseX, baseY = anchorPos.x, anchorPos.y
            else
                local af = byKey[anchor]
                if af and af.GetCenter then
                    local cx, cy = af:GetCenter()
                    local ux, uy = UIParent:GetCenter()
                    if type(cx) == "number" and type(cy) == "number" and type(ux) == "number" and type(uy) == "number" then
                        baseX = math.floor((cx - ux) + 0.5)
                        baseY = math.floor((cy - uy) + 0.5)
                    end
                end
            end

            if type(baseX) == "number" and type(baseY) == "number" then
                cfg.iconPositions = cfg.iconPositions or {}
                cfg.iconPositions[anchor] = {
                    point = "CENTER",
                    relPoint = "CENTER",
                    x = baseX,
                    y = baseY,
                }

                for i = 1, #members do
                    local mk = members[i]
                    local mf = byKey[mk]
                    local isInActiveDrag = self.activeDrag and self.activeDrag.members and self.activeDrag.members[mk]
                    if mf and not mf.isDragging and not isInActiveDrag then
                        ApplyRenderMode(mf, mf.renderMode, iconSize, cfg)
                        mf:ClearAllPoints()
                        if horizontal then
                            local xOffset = 0
                            for j = 1, i - 1 do
                                local prev = byKey[members[j]]
                                xOffset = xOffset + ((prev and prev:GetWidth()) or iconSize) + spacing
                            end
                            mf:SetPoint("CENTER", UIParent, "CENTER", baseX + xOffset, baseY)
                        else
                            local yOffset = 0
                            for j = 1, i - 1 do
                                local prev = byKey[members[j]]
                                yOffset = yOffset + ((prev and prev:GetHeight()) or iconSize) + spacing
                            end
                            mf:SetPoint("CENTER", UIParent, "CENTER", baseX, baseY - yOffset)
                        end
                        mf:EnableMouse(self:IsUnlockEnabled())
                    end
                end
            end
        end
    end
end

function Module:Tick()
    local cfg = ForgeUI:GetModuleConfig("cooldowns")

    local drag = self.activeDrag
    if drag and drag.leader and drag.leader.isDragging then
        self:UpdateGroupDragVisual(drag.leader)
    end

    for _, frame in pairs(self.entries) do
        if frame and frame:IsShown() then
            if frame.renderMode == "bar" and frame.sourceBar then
                UpdateFrameBarFromSource(frame, cfg)
            else
                UpdateIconBorderVisual(frame, cfg)
            end
        end
    end

    self.scanElapsed = self.scanElapsed + 0.15
    if self.scanElapsed >= 0.75 then
        self.scanElapsed = 0
        self:RefreshAll()
    end
end

function Module:IsUnlockEnabled()
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    return cfg and cfg.unlockIcons
end

function Module:OpenContextMenu(frame)
    if not frame or not frame.entryKey then
        return
    end

    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    local key = frame.entryKey
    local anchor = self:GetGroupAnchor(cfg, key)
    local mode = frame.renderMode or frame.mode or GetRenderMode(cfg, key, nil)
    local isBar = (mode == "bar")

    local menu = {
        {
            text = "ForgeUI Cooldown",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Ungroup",
            notCheckable = true,
            func = function()
                self:UngroupEntry(key, frame)
                self:RefreshAll()
            end,
        },
        {
            text = "Make Anchor",
            notCheckable = true,
            func = function()
                cfg.iconGroups = cfg.iconGroups or {}
                local members = self:CollectGroupMembers(cfg, anchor)
                for mk in pairs(members) do
                    cfg.iconGroups[mk] = key
                end
                cfg.iconGroups[key] = key
                self:RefreshAll()
            end,
        },
        {
            text = "Delete Group",
            notCheckable = true,
            func = function()
                cfg.iconGroups = cfg.iconGroups or {}
                local members = self:CollectGroupMembers(cfg, anchor)
                for mk in pairs(members) do
                    cfg.iconGroups[mk] = nil
                end
                self:RefreshAll()
            end,
        },
        {
            text = isBar and "Render: Icon" or "Render: Bar",
            notCheckable = true,
            func = function()
                cfg.renderModeByKey = cfg.renderModeByKey or {}
                if not isBar and not frame.hasNativeBar then
                    ForgeUI:Print("This icon has no native Blizzard bar source.")
                    return
                end
                cfg.renderModeByKey[key] = isBar and "icon" or "bar"
                self:RefreshAll()
            end,
        },
        {
            text = "Direction: Horizontal",
            checked = tostring((cfg.iconGroupDirection and cfg.iconGroupDirection[anchor]) or cfg.groupDirection or "HORIZONTAL") ~= "VERTICAL",
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                cfg.iconGroupDirection = cfg.iconGroupDirection or {}
                cfg.iconGroupDirection[anchor] = "HORIZONTAL"
                self:RefreshAll()
            end,
        },
        {
            text = "Direction: Vertical",
            checked = tostring((cfg.iconGroupDirection and cfg.iconGroupDirection[anchor]) or cfg.groupDirection or "HORIZONTAL") == "VERTICAL",
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                cfg.iconGroupDirection = cfg.iconGroupDirection or {}
                cfg.iconGroupDirection[anchor] = "VERTICAL"
                self:RefreshAll()
            end,
        },
    }

    ShowSimpleMenu(menu)
end

function Module:CollectGroupMembers(cfg, anchorKey)
    local out = {}
    if not cfg or type(cfg.iconGroups) ~= "table" or not anchorKey then
        out[anchorKey] = true
        return out
    end

    out[anchorKey] = true
    for key, anchor in pairs(cfg.iconGroups) do
        if anchor == anchorKey then
            out[key] = true
        end
    end
    return out
end

function Module:GetGroupAnchor(cfg, key)
    if not cfg or type(cfg.iconGroups) ~= "table" or not key then
        return key
    end
    local anchor = cfg.iconGroups[key]
    if type(anchor) ~= "string" or anchor == "" then
        return key
    end
    return anchor
end

function Module:MergeIntoBar(sourceKey, targetKey)
    if not sourceKey or not targetKey or sourceKey == targetKey then
        return
    end

    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    cfg.iconGroups = cfg.iconGroups or {}
    cfg.iconPositions = cfg.iconPositions or {}

    local srcAnchor = self:GetGroupAnchor(cfg, sourceKey)
    local dstAnchor = self:GetGroupAnchor(cfg, targetKey)
    if srcAnchor == dstAnchor then
        return
    end

    for key, anchor in pairs(cfg.iconGroups) do
        if anchor == srcAnchor then
            cfg.iconGroups[key] = dstAnchor
        end
    end

    cfg.iconGroups[sourceKey] = dstAnchor
    cfg.iconGroups[targetKey] = dstAnchor
    cfg.iconGroups[dstAnchor] = dstAnchor
    if cfg.iconGroups[srcAnchor] == srcAnchor then
        cfg.iconGroups[srcAnchor] = dstAnchor
    end

    cfg.iconPositions[sourceKey] = nil
end

function Module:FindDropTarget(dragFrame)
    if not dragFrame then
        return nil
    end

    local dl, dr, dt, db = dragFrame:GetLeft(), dragFrame:GetRight(), dragFrame:GetTop(), dragFrame:GetBottom()
    if not dl or not dr or not dt or not db then
        return nil
    end

    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    local dragAnchor = self:GetGroupAnchor(cfg, dragFrame.entryKey)

    local best = nil
    local bestArea = 0
    for _, frame in pairs(self.entries) do
        if frame ~= dragFrame and frame:IsShown() then
            local frameAnchor = self:GetGroupAnchor(cfg, frame.entryKey)
            if frameAnchor ~= dragAnchor then
                local fl, fr, ft, fb = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
                if fl and fr and ft and fb then
                    local overlapW = math.min(dr, fr) - math.max(dl, fl)
                    local overlapH = math.min(dt, ft) - math.max(db, fb)
                    if overlapW > 0 and overlapH > 0 then
                        local area = overlapW * overlapH
                        if area > bestArea then
                            best = frame
                            bestArea = area
                        end
                    end
                end
            end
        end
    end
    return best
end

function Module:BeginGroupDrag(frame)
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    local anchorKey = self:GetGroupAnchor(cfg, frame.entryKey)
    local members = self:CollectGroupMembers(cfg, anchorKey)

    local fx, fy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if type(fx) ~= "number" or type(fy) ~= "number" or type(ux) ~= "number" or type(uy) ~= "number" then
        return
    end

    local anchorPos = cfg.iconPositions and cfg.iconPositions[anchorKey] or nil
    local anchorX, anchorY
    if anchorPos and type(anchorPos.x) == "number" and type(anchorPos.y) == "number" then
        anchorX, anchorY = anchorPos.x, anchorPos.y
    else
        local af = self.entries[anchorKey]
        if af then
            local acx, acy = af:GetCenter()
            if type(acx) == "number" and type(acy) == "number" then
                anchorX = math.floor((acx - ux) + 0.5)
                anchorY = math.floor((acy - uy) + 0.5)
            end
        end
    end
    anchorX = anchorX or 0
    anchorY = anchorY or 0

    local offsets = {}
    for key in pairs(members) do
        local mf = self.entries[key]
        if mf and mf:GetCenter() then
            local cx, cy = mf:GetCenter()
            if type(cx) == "number" and type(cy) == "number" then
                offsets[key] = { x = cx - fx, y = cy - fy }
            end
        end
    end
    offsets[frame.entryKey] = offsets[frame.entryKey] or { x = 0, y = 0 }

    self.activeDrag = {
        leader = frame,
        leaderKey = frame.entryKey,
        anchorKey = anchorKey,
        members = members,
        offsets = offsets,
        startCenterX = fx,
        startCenterY = fy,
        startAnchorX = anchorX,
        startAnchorY = anchorY,
    }
end

function Module:UpdateGroupDragVisual(frame)
    local drag = self.activeDrag
    if not drag or drag.leader ~= frame or not frame.isDragging then
        return
    end

    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(ux) ~= "number" or type(uy) ~= "number" then
        return
    end

    for key in pairs(drag.members) do
        if key ~= frame.entryKey then
            local mf = self.entries[key]
            local off = drag.offsets[key]
            if mf and off then
                mf:ClearAllPoints()
                mf:SetPoint("CENTER", UIParent, "CENTER", (cx + off.x) - ux, (cy + off.y) - uy)
            end
        end
    end
end

function Module:UngroupEntry(key, frame)
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    cfg.iconGroups = cfg.iconGroups or {}
    cfg.iconPositions = cfg.iconPositions or {}

    local anchor = self:GetGroupAnchor(cfg, key)
    local members = self:CollectGroupMembers(cfg, anchor)

    local memberList = {}
    for mk in pairs(members) do
        tinsert(memberList, mk)
    end

    if #memberList <= 1 then
        cfg.iconGroups[key] = nil
        self:SaveIconPosition(key, frame)
        return
    end

    if key == anchor then
        local newAnchor = nil
        for i = 1, #memberList do
            if memberList[i] ~= key then
                newAnchor = memberList[i]
                break
            end
        end
        if not newAnchor then
            cfg.iconGroups[key] = nil
            self:SaveIconPosition(key, frame)
            return
        end

        for i = 1, #memberList do
            local mk = memberList[i]
            if mk ~= key then
                cfg.iconGroups[mk] = newAnchor
            end
        end
        cfg.iconGroups[newAnchor] = newAnchor
        cfg.iconGroups[key] = nil

        if cfg.iconPositions[anchor] and not cfg.iconPositions[newAnchor] then
            cfg.iconPositions[newAnchor] = {
                point = cfg.iconPositions[anchor].point or "CENTER",
                relPoint = cfg.iconPositions[anchor].relPoint or "CENTER",
                x = cfg.iconPositions[anchor].x or 0,
                y = cfg.iconPositions[anchor].y or 0,
            }
        end
    else
        cfg.iconGroups[key] = nil
    end

    self:SaveIconPosition(key, frame)
end

function Module:HandleDrop(frame)
    if not frame or not frame.entryKey then
        return
    end

    local drag = self.activeDrag
    self.activeDrag = nil

    local target = self:FindDropTarget(frame)
    if target and target.entryKey then
        self:MergeIntoBar(frame.entryKey, target.entryKey)
        ForgeUI:Print("Merged into bar: " .. tostring(frame.entryKey) .. " -> " .. tostring(target.entryKey))
        self:RefreshAll()
        return
    end

    if drag and drag.anchorKey then
        local cx, cy = frame:GetCenter()
        local dx, dy = 0, 0
        if type(cx) == "number" and type(cy) == "number" and type(drag.startCenterX) == "number" and type(drag.startCenterY) == "number" then
            dx = cx - drag.startCenterX
            dy = cy - drag.startCenterY
        end
        local cfg = ForgeUI:GetModuleConfig("cooldowns")
        cfg.iconPositions = cfg.iconPositions or {}
        cfg.iconPositions[drag.anchorKey] = {
            point = "CENTER",
            relPoint = "CENTER",
            x = math.floor((drag.startAnchorX + dx) + 0.5),
            y = math.floor((drag.startAnchorY + dy) + 0.5),
        }
    else
        self:SaveIconPosition(frame.entryKey, frame)
    end

    self:RefreshAll()
end

function Module:SaveIconPosition(key, frame)
    if not key or not frame then
        return
    end

    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    cfg.iconPositions = cfg.iconPositions or {}
    local anchorKey = self:GetGroupAnchor(cfg, key)
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(ux) ~= "number" or type(uy) ~= "number" then
        return
    end
    cfg.iconPositions[anchorKey] = {
        point = "CENTER",
        relPoint = "CENTER",
        x = math.floor((cx - ux) + 0.5),
        y = math.floor((cy - uy) + 0.5),
    }
end

function Module:ResetPositions()
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    cfg.iconPositions = {}
    cfg.iconGroups = {}
    ForgeUI:Print("Cooldown icon positions reset.")
    self:RefreshAll()
end

function Module:ToggleUnlock()
    local cfg = ForgeUI:GetModuleConfig("cooldowns")
    cfg.unlockIcons = not cfg.unlockIcons
    ForgeUI:Print("Cooldown icon unlock: " .. tostring(cfg.unlockIcons))
    self:RefreshAll()
end

function Module:DebugDump()
    local active = 0
    for _, frame in pairs(self.entries) do
        if frame:IsShown() then
            active = active + 1
        end
    end

    local visibleChildren = 0
    for i = 1, #self.viewerChildren do
        local child = self.viewerChildren[i].child
        if child and child.IsShown and child:IsShown() then
            visibleChildren = visibleChildren + 1
        end
    end

    ForgeUI:Print(string.format(
        "CD Debug -> viewerChildren=%d visibleChildren=%d activeIcons=%d",
        #self.viewerChildren,
        visibleChildren,
        active
    ))
end

function Module:Initialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    self.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("UNIT_AURA")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.eventFrame:SetScript("OnEvent", function()
        Module:RefreshAll()
    end)

    self.tickerFrame = CreateFrame("Frame")
    self.tickerFrame.acc = 0
    self.tickerFrame:SetScript("OnUpdate", function(_, elapsed)
        Module.tickerFrame.acc = Module.tickerFrame.acc + elapsed
        if Module.tickerFrame.acc < 0.15 then
            return
        end
        Module.tickerFrame.acc = 0
        Module:Tick()
    end)

    C_Timer.After(1.0, function()
        Module:RefreshAll()
    end)
end

ForgeUI:RegisterModule("cooldowns", Module)
