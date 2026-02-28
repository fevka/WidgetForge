local addonName, addon = ...
if not _G.WidgetForge then _G.WidgetForge = {} end
if not _G.WidgetForge.CursorRing then _G.WidgetForge.CursorRing = {} end

-- Local alias for the module
local CursorRing = _G.WidgetForge.CursorRing
-- Link to internal addon table if needed
addon.CursorRing = CursorRing

local Skin = ForgeSkin

-- ===========================================================================
-- CURSOR RING WIDGET
-- ===========================================================================
function WidgetForge:CreateCursorRing(bar, config)
    local f = CreateFrame("Frame", nil, bar)
    f:SetAllPoints()
    f.config = config -- [FIX] Store config for settings lookup
    f.parentBar = bar
    
    -- Hide the parent bar since Cursor Ring follows mouse (no bar needed)
    if bar then
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    end
    
    -- Ring Frame (Visual) - Parented to UIParent to follow cursor freely
    local ring = CreateFrame("Frame", nil, UIParent)
    local ringSize = config.ringSize or 64
    ring:SetSize(ringSize, ringSize)
    
    local layer = "TOOLTIP"
    if bar and bar.index then
         local pbarConf = WidgetForgeDB.bars[bar.index]
         if pbarConf and pbarConf.layer then
             layer = pbarConf.layer
         end
    end
    ring:SetFrameStrata(layer)
    ring:SetFrameLevel(2000)
    ring:EnableMouse(false)
    
    -- Outer Ring Texture
    ring.texture = ring:CreateTexture(nil, "ARTWORK")
    ring.texture:SetAllPoints()
    ring.texture:SetTexture(config.ringTexture or "Interface\\AddOns\\WidgetForge\\media\\ring.tga")
    local c = config.ringColor or {0, 0.8, 1, 1}
    ring.texture:SetVertexColor(unpack(c))
    ring.texture:SetAlpha(config.ringAlpha or 1.0)
    
    -- ===================================================================
    -- HELPER FUNCTIONS FOR CIRCULAR PROGRESS (WEDGES)
    -- ===================================================================
    local CORNERS = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }
    local BASE_UV = {
        ULx = 0, ULy = 0,
        LLx = 0, LLy = 1,
        URx = 1, URy = 0,
        LRx = 1, LRy = 1,
    }
    local SNAP_POINTS = {
        {0.5, 0}, {1, 0}, {1, 0.5}, {1, 1},
        {0.5, 1}, {0, 1}, {0, 0.5}, {0, 0},
    }
    
    local function ComputeEdgePoint(deg)
        deg = deg % 360
        if deg % 45 == 0 then
            local snap = SNAP_POINTS[math.floor(deg / 45) + 1]
            return snap[1], snap[2]
        end
        local rad = math.rad(deg)
        local tanVal = math.tan(rad)
        if deg < 45 then
            return 0.5 + tanVal / 2, 0
        elseif deg < 135 then
            return 1, 0.5 + math.tan(rad - math.rad(90)) / 2
        elseif deg < 225 then
            return 0.5 - tanVal / 2, 1
        elseif deg < 315 then
            return 0, 0.5 - math.tan(rad - math.rad(90)) / 2
        else
            return 0.5 + tanVal / 2, 0
        end
    end
    
    local VERTEX_MAP = {
        UL = UPPER_LEFT_VERTEX, UR = UPPER_RIGHT_VERTEX,
        LL = LOWER_LEFT_VERTEX, LR = LOWER_RIGHT_VERTEX,
    }
    
    local function DeformCorner(tex, corner, u, v, w, h, coordTbl)
        local dx = (BASE_UV[corner.."x"] - u) * (-w)
        local dy = (BASE_UV[corner.."y"] - v) * h
        tex:SetVertexOffset(VERTEX_MAP[corner], dx, dy)
        coordTbl[corner.."x"] = u
        coordTbl[corner.."y"] = v
    end
    
    local function ApplyCoords(tex, c)
        tex:SetTexCoord(c.ULx, c.ULy, c.LLx, c.LLy, c.URx, c.URy, c.LRx, c.LRy)
    end
    
    local function BuildWedge(tex, startAngle, endAngle, w, h)
        local quadIdx = math.floor((startAngle + 45) / 90)
        local center   = CORNERS[quadIdx + 1]
        local edgeA    = CORNERS[quadIdx + 2]
        local edgeB1   = CORNERS[quadIdx + 3]
        local edgeB2   = CORNERS[quadIdx + 4]
        
        local coords = {}
        DeformCorner(tex, center, 0.5, 0.5, w, h, coords)
        local su, sv = ComputeEdgePoint(startAngle)
        DeformCorner(tex, edgeA, su, sv, w, h, coords)
        
        local sideA = math.floor((startAngle - 45) / 90)
        local sideB = math.floor((endAngle - 45) / 90)
        if sideA == sideB then
            local eu, ev = ComputeEdgePoint(endAngle)
            DeformCorner(tex, edgeB1, eu, ev, w, h, coords)
        else
            DeformCorner(tex, edgeB1, BASE_UV[edgeB1.."x"], BASE_UV[edgeB1.."y"], w, h, coords)
        end
        local eu2, ev2 = ComputeEdgePoint(endAngle)
        DeformCorner(tex, edgeB2, eu2, ev2, w, h, coords)
        
        ApplyCoords(tex, coords)
        tex:Show()
    end
    
    local function RefreshWedges(ringFrame, wedges, degStart, degEnd)
        local w, h = ringFrame:GetSize()
        if w == 0 or h == 0 then return end
        
        if degEnd - degStart >= 360 then
            for vIdx = 1, 3 do
                wedges[vIdx]:SetVertexOffset(UPPER_LEFT_VERTEX, 0, 0)
                wedges[vIdx]:SetVertexOffset(UPPER_RIGHT_VERTEX, 0, 0)
                wedges[vIdx]:SetVertexOffset(LOWER_LEFT_VERTEX, 0, 0)
                wedges[vIdx]:SetVertexOffset(LOWER_RIGHT_VERTEX, 0, 0)
            end
            wedges[1]:SetTexCoord(0,0, 0,1, 1,0, 1,1)
            wedges[1]:Show()
            wedges[2]:Hide()
            wedges[3]:Hide()
            return
        end
        
        if degStart == degEnd then
            wedges[1]:Hide(); wedges[2]:Hide(); wedges[3]:Hide()
            return
        end
        
        local bucket1 = math.floor((degStart + 45) / 90)
        local bucket2 = math.floor((degEnd + 45) / 90)
        
        if bucket1 + 1 >= bucket2 then
            BuildWedge(wedges[1], degStart, degEnd, w, h)
            wedges[2]:Hide(); wedges[3]:Hide()
        elseif bucket1 + 3 >= bucket2 then
            local split = (bucket1 + 1) * 90 + 45
            BuildWedge(wedges[1], degStart, split, w, h)
            BuildWedge(wedges[2], split, degEnd, w, h)
            wedges[3]:Hide()
        else
            local splitA = (bucket1 + 1) * 90 + 45
            local splitB = splitA + 180
            BuildWedge(wedges[1], degStart, splitA, w, h)
            BuildWedge(wedges[2], splitA, splitB, w, h)
            BuildWedge(wedges[3], splitB, degEnd, w, h)
        end
    end

    local function CreateWedgeRing(parent, levelOfs, texPath, size, colorArr, alpha)
        local rFrame = CreateFrame("Frame", nil, parent)
        rFrame:SetSize(size, size)
        rFrame:SetPoint("CENTER")
        rFrame:SetFrameLevel(parent:GetFrameLevel() + levelOfs)
        rFrame:SetAlpha(alpha or 1.0)
        
        local wedges = {}
        for idx = 1, 3 do
            local tex = rFrame:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(texPath)
            tex:SetVertexColor(colorArr[1], colorArr[2], colorArr[3], colorArr[4] or 0.85)
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
            tex:Hide()
            wedges[idx] = tex
        end
        rFrame.wedges = wedges
        return rFrame
    end

    -- Create Primary Inner Ring
    local innerSize = config.innerRingSize or (ringSize * 0.6)
    local ic = config.innerRingColor or {1, 0.8, 0, 1}
    local itex = config.innerRingTexture or "Interface\\AddOns\\WidgetForge\\media\\circle.tga"
    local ialpha = config.innerRingAlpha or 1.0
    local innerRing = CreateWedgeRing(ring, 1, itex, innerSize, ic, ialpha)
    if config.showInnerRing == false and not f.previewMode then innerRing:Hide() end

    -- Create Secondary Inner Ring
    local inner2Size = config.inner2Size or (ringSize * 0.4)
    local i2c = config.inner2Color or {0, 1, 0.2, 1}
    local i2tex = config.inner2Texture or "Interface\\AddOns\\WidgetForge\\media\\circle.tga"
    local i2alpha = config.inner2Alpha or 1.0
    local innerRing2 = CreateWedgeRing(ring, 2, i2tex, inner2Size, i2c, i2alpha)
    if config.showInner2 == false and not f.previewMode then innerRing2:Hide() end
    
    -- Apply general Transparency
    ring:SetAlpha(config.transparency or 1.0)
    
    -- Trail Pool
    if not ring.trailPool then ring.trailPool = {} end
    local function GetTrailFrame()
        local t = table.remove(ring.trailPool)
        if not t then
            t = CreateFrame("Frame", nil, UIParent)
            t:SetFrameStrata("TOOLTIP")
            t:SetFrameLevel(1999)
            t:EnableMouse(false)
            t.texture = t:CreateTexture(nil, "ARTWORK")
            t.texture:SetAllPoints()
        else
            t:SetParent(UIParent)
            t:SetFrameStrata("TOOLTIP")
            t:SetFrameLevel(1999)
        end
        t.texture:SetTexture(config.trailTexture or "Interface\\AddOns\\WidgetForge\\media\\circle.tga")
        t:Show()
        return t
    end
    local function RecycleTrailFrame(t)
        t:Hide()
        t:SetScript("OnUpdate", nil)
        t:SetParent(nil)
        t:SetAlpha(0)
        table.insert(ring.trailPool, t)
    end

    local lastProgress1 = -1
    local lastProgress2 = -1
    
    local function GetTrackProgress(trackMode)
        local progress = 0
        if trackMode == "GCD" or trackMode == "BOTH" then
            local cdInfo = C_Spell.GetSpellCooldown(61304)
            if cdInfo and cdInfo.duration and cdInfo.duration > 0 then
                local gcdElapsed = GetTime() - cdInfo.startTime
                local gcdPct = gcdElapsed / cdInfo.duration
                if gcdPct > 1 then gcdPct = 1 end
                if gcdPct > progress then progress = gcdPct end
            end
        end
        if trackMode == "CAST" or trackMode == "BOTH" then
            local name, _, _, startMS, endMS = UnitCastingInfo("player")
            if not name then
                name, _, _, startMS, endMS = UnitChannelInfo("player")
            end
            if name and startMS and endMS then
                local s = startMS / 1000
                local d = (endMS - startMS) / 1000
                if d > 0 then
                    local castElapsed = GetTime() - s
                    local castPct = castElapsed / d
                    if castPct > 1 then castPct = 1 end
                    if castPct > progress then progress = castPct end
                end
            end
        end
        return progress
    end

    ring:SetScript("OnUpdate", function(self, elapsed)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        
        -- Ring 1
        if config.showInnerRing ~= false and innerRing:IsShown() and not f.previewMode then
            local p1 = GetTrackProgress(config.innerRingMode or "GCD")
            if math.abs(p1 - lastProgress1) > 0.005 then
                RefreshWedges(innerRing, innerRing.wedges, 0, p1 * 360)
                lastProgress1 = p1
            end
        end
        
        -- Ring 2
        if config.showInner2 ~= false and innerRing2:IsShown() and not f.previewMode then
            local p2 = GetTrackProgress(config.inner2Mode or "CAST")
            if math.abs(p2 - lastProgress2) > 0.005 then
                RefreshWedges(innerRing2, innerRing2.wedges, 0, p2 * 360)
                lastProgress2 = p2
            end
        end
        
        -- Trail Logic
        if config.trailEnabled then
            if x ~= self.lastX or y ~= self.lastY then
                self.trailTimer = (self.trailTimer or 0) + elapsed
                local density = config.trailDensity or 0.005
                while self.trailTimer >= density do
                    self.trailTimer = self.trailTimer - density
                    local trail = GetTrailFrame()
                    local trailSize = (config.ringSize or 64) * (config.trailScale or 1.0)
                    trail:SetSize(trailSize, trailSize)
                    trail:ClearAllPoints()
                    trail:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                    local tc = config.trailColor or {1, 1, 1, 1}
                    trail.texture:SetVertexColor(tc[1], tc[2], tc[3], tc[4])
                    trail:SetAlpha(0.6 * (config.ringAlpha or 1.0))
                    local duration = config.trailDuration or 0.5
                    local startTime = GetTime()
                    trail:SetScript("OnUpdate", function(self2, el)
                        local age = GetTime() - startTime
                        if age >= duration then
                            RecycleTrailFrame(self2)
                        else
                            self2:SetAlpha(0.6 * (config.ringAlpha or 1.0) * (1 - age / duration))
                        end
                    end)
                end
            else
                self.trailTimer = 0 -- Reset timer when stationary so a particle drops immediately on move
            end
        end
        self.lastX = x
        self.lastY = y
    end)
    
    function f:UpdateVisuals(conf)
        if not conf then return end
        
        -- Outer Ring
        ring.texture:SetVertexColor(unpack(conf.ringColor or {0, 0.8, 1, 1}))
        ring.texture:SetTexture(conf.ringTexture or "Interface\\AddOns\\WidgetForge\\media\\ring.tga")
        ring.texture:SetAlpha(conf.ringAlpha or 1.0)
        local size = conf.ringSize or 64
        ring:SetSize(size, size)
        
        ring:SetAlpha(conf.transparency or 1.0)
        
        -- Inner Ring 1
        innerRing:SetSize(conf.innerRingSize or (size * 0.6), conf.innerRingSize or (size * 0.6))
        local ic = conf.innerRingColor or {1, 0.8, 0, 1}
        for wIdx = 1, 3 do innerRing.wedges[wIdx]:SetVertexColor(ic[1], ic[2], ic[3], ic[4] or 0.85) end
        for wIdx = 1, 3 do innerRing.wedges[wIdx]:SetTexture(conf.innerRingTexture or "Interface\\AddOns\\WidgetForge\\media\\circle.tga") end
        innerRing:SetAlpha(conf.innerRingAlpha or 1.0)
        if conf.showInnerRing == false then innerRing:Hide() else innerRing:Show() end
        
        -- Inner Ring 2
        innerRing2:SetSize(conf.inner2Size or (size * 0.4), conf.inner2Size or (size * 0.4))
        local i2c = conf.inner2Color or {0, 1, 0.2, 1}
        for wIdx = 1, 3 do innerRing2.wedges[wIdx]:SetVertexColor(i2c[1], i2c[2], i2c[3], i2c[4] or 0.85) end
        for wIdx = 1, 3 do innerRing2.wedges[wIdx]:SetTexture(conf.inner2Texture or "Interface\\AddOns\\WidgetForge\\media\\circle.tga") end
        innerRing2:SetAlpha(conf.inner2Alpha or 1.0)
        if conf.showInner2 == false then innerRing2:Hide() else innerRing2:Show() end
        
        if f.previewMode then
            RefreshWedges(innerRing, innerRing.wedges, 0, 360)
            RefreshWedges(innerRing2, innerRing2.wedges, 0, 360)
        end
    end
    
    function f:ShowPreview()
        f.previewMode = true
        innerRing:Show()
        innerRing2:Show()
        RefreshWedges(innerRing, innerRing.wedges, 0, 360)
        RefreshWedges(innerRing2, innerRing2.wedges, 0, 360)
    end
    
    function f:HidePreview()
        f.previewMode = false
        RefreshWedges(innerRing, innerRing.wedges, 0, 0)
        RefreshWedges(innerRing2, innerRing2.wedges, 0, 0)
    end
    
    f:UpdateVisuals(config)
    
    f:SetScript("OnHide", function() ring:Hide() end)
    f:SetScript("OnShow", function() ring:Show() end)
    
    function f:Unload()
        ring:Hide()
        ring:SetScript("OnUpdate", nil)
        ring:SetParent(nil)
        if f.parentBar then
            f.parentBar:SetAlpha(1)
            f.parentBar:EnableMouse(true)
            f.parentBar = nil
        end
    end
    
    bar.cursorRing = ring
    return f
end

-- ===========================================================================
-- CURSOR RING SETTINGS (Unified Slide-In Panel)
-- ===========================================================================
function WidgetForge.CursorRing:CreateSettings(panel)
    local elem = panel.config
    local f = panel
    local targetBarIdx = panel.barIndex
    
    local function FindWidgets(callback)
        local bars = WidgetForge:GetBarFrames()
        if targetBarIdx and bars[targetBarIdx] then
             local bar = bars[targetBarIdx]
             if bar.customWidgets then
                 for _, cw in ipairs(bar.customWidgets) do
                     if cw.config == elem or (cw.config and cw.config.type == "Cursor Ring") then
                         callback(cw)
                     end
                 end
             end
             return
        end
        for _, barFrame in pairs(bars) do
            if barFrame.customWidgets then
                for _, cw in ipairs(barFrame.customWidgets) do
                     if cw.config == elem then callback(cw) end
                end
            end
        end
    end

    local function Refresh()
        if elem then
            FindWidgets(function(cw)
                if cw.UpdateVisuals then cw:UpdateVisuals(elem) end
            end)
        end
    end

    local function TogglePreview(show)
        FindWidgets(function(cw)
            if cw.ShowPreview then 
                if show then cw:ShowPreview() else cw:HidePreview() end
            end
        end)
    end
    
    TogglePreview(true)
    f.onCloseWidgetSpecific = function()
        TogglePreview(false)
        f.onCloseWidgetSpecific = nil
    end
    
    local sb = f.builder or WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb
    
    -- INITIALIZE DEFAULTS
    if elem.ringSize == nil then elem.ringSize = 64 end
    if elem.ringAlpha == nil then elem.ringAlpha = 1.0 end
    if elem.ringTexture == nil then elem.ringTexture = "Interface\\AddOns\\WidgetForge\\media\\ring.tga" end

    if elem.showInnerRing == nil then elem.showInnerRing = true end
    if elem.innerRingSize == nil then elem.innerRingSize = 38 end
    if elem.innerRingMode == nil then elem.innerRingMode = "GCD" end
    if elem.innerRingAlpha == nil then elem.innerRingAlpha = 1.0 end
    if elem.innerRingTexture == nil then elem.innerRingTexture = "Interface\\AddOns\\WidgetForge\\media\\circle.tga" end

    if elem.showInner2 == nil then elem.showInner2 = false end
    if elem.inner2Size == nil then elem.inner2Size = 24 end
    if elem.inner2Mode == nil then elem.inner2Mode = "CAST" end
    if elem.inner2Alpha == nil then elem.inner2Alpha = 1.0 end
    if elem.inner2Texture == nil then elem.inner2Texture = "Interface\\AddOns\\WidgetForge\\media\\circle.tga" end

    if elem.trailEnabled == nil then elem.trailEnabled = false end
    if elem.trailTexture == nil then elem.trailTexture = "Interface\\AddOns\\WidgetForge\\media\\circle.tga" end
    if elem.trailDuration == nil then elem.trailDuration = 0.5 end
    if elem.trailDensity == nil then elem.trailDensity = 0.005 end
    if elem.trailScale == nil then elem.trailScale = 1.0 end
    if elem.transparency == nil then elem.transparency = 1.0 end
    
    local TEXTURE_OPTIONS = {
        {text = "Ring", value = "Interface\\AddOns\\WidgetForge\\media\\ring.tga"},
        {text = "Circle", value = "Interface\\AddOns\\WidgetForge\\media\\circle.tga"},
        {text = "Circle with Dot", value = "Interface\\AddOns\\WidgetForge\\media\\CircleDot.tga"},
        {text = "Dot", value = "Interface\\AddOns\\WidgetForge\\media\\dot.tga"}
    }
    
    local MODE_OPTIONS = {
        {text = "GCD Only", value = "GCD"},
        {text = "Cast Only", value = "CAST"},
        {text = "Both", value = "BOTH"}
    }

    -- MAIN RING
    sb:AddHeader("Outer Main Ring")
    sb:AddDropdown("ringTexture", "Texture:", TEXTURE_OPTIONS, "Interface\\AddOns\\WidgetForge\\media\\ring.tga", elem, Refresh)
    sb:AddColor("ringColor", "Color", {0, 0.8, 1, 1}, elem, Refresh)
    sb:AddSlider("ringSize", "Size:", 16, 256, 4, 64, elem, Refresh)
    sb:AddSlider("ringAlpha", "Transparency:", 0.1, 1.0, 0.05, 1.0, elem, Refresh)
    
    -- PROGRESS RING 1
    sb:AddHeader("Progress Ring 1")
    sb:AddSwitch("showInnerRing", "Enable", true, elem, Refresh)
    sb:AddDropdown("innerRingMode", "Tracking Mode:", MODE_OPTIONS, "GCD", elem, Refresh)
    sb:AddDropdown("innerRingTexture", "Texture:", TEXTURE_OPTIONS, "Interface\\AddOns\\WidgetForge\\media\\circle.tga", elem, Refresh)
    sb:AddColor("innerRingColor", "Color", {1, 0.8, 0, 1}, elem, Refresh)
    sb:AddSlider("innerRingSize", "Size:", 8, 200, 2, 38, elem, Refresh)
    sb:AddSlider("innerRingAlpha", "Transparency:", 0.1, 1.0, 0.05, 1.0, elem, Refresh)
    
    -- PROGRESS RING 2
    sb:AddHeader("Progress Ring 2")
    sb:AddSwitch("showInner2", "Enable", false, elem, Refresh)
    sb:AddDropdown("inner2Mode", "Tracking Mode:", MODE_OPTIONS, "CAST", elem, Refresh)
    sb:AddDropdown("inner2Texture", "Texture:", TEXTURE_OPTIONS, "Interface\\AddOns\\WidgetForge\\media\\circle.tga", elem, Refresh)
    sb:AddColor("inner2Color", "Color:", {0, 1, 0.2, 1}, elem, Refresh)
    sb:AddSlider("inner2Size", "Size:", 8, 200, 2, 24, elem, Refresh)
    sb:AddSlider("inner2Alpha", "Transparency:", 0.1, 1.0, 0.05, 1.0, elem, Refresh)
    
    -- TRAIL
    sb:AddHeader("Cursor Trail")
    sb:AddSwitch("trailEnabled", "Enable Trail", false, elem, Refresh)
    sb:AddDropdown("trailTexture", "Texture:", TEXTURE_OPTIONS, "Interface\\AddOns\\WidgetForge\\media\\circle.tga", elem, Refresh)
    sb:AddColor("trailColor", "Color", {1, 1, 1, 1}, elem, Refresh)
    sb:AddSlider("trailDuration", "Duration:", 0.1, 2.0, 0.05, 0.5, elem, Refresh)
    sb:AddSlider("trailDensity", "Density:", 0.001, 0.05, 0.001, 0.005, elem, Refresh)
    sb:AddSlider("trailScale", "Scale:", 0.1, 3.0, 0.1, 1.0, elem, Refresh)
    
    -- GLOBAL
    sb:AddHeader("Global Visibility")
    sb:AddSlider("transparency", "Global Alpha:", 0.1, 1.0, 0.05, 1.0, elem, Refresh)
    
    sb:Finish()
end
