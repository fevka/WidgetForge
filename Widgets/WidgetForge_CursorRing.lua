local Skin = ForgeSkin

-- ===========================================================================
-- CURSOR RING WIDGET
-- ===========================================================================
function WidgetForge:CreateCursorRing(bar, config)
    local f = CreateFrame("Frame", nil, bar)
    f:SetAllPoints()
    
    -- Hide the parent bar since Cursor Ring follows mouse (no bar needed)
    -- [MODIFIED] Do not hide bar blindly, as other widgets might be on it (e.g. M+ Dashboard)
    -- bar:SetAlpha(0)
    -- bar:EnableMouse(false)
    
    -- Ring Frame (Visual) - Parented to UIParent to follow cursor freely
    local ring = CreateFrame("Frame", nil, UIParent)
    local ringSize = config.ringSize or 64
    ring:SetSize(ringSize, ringSize)
    ring:SetFrameStrata("TOOLTIP")
    ring:SetFrameLevel(2000)
    ring:EnableMouse(false)
    
    -- Outer Ring Texture
    ring.texture = ring:CreateTexture(nil, "ARTWORK")
    ring.texture:SetAllPoints()
    ring.texture:SetTexture("Interface\\AddOns\\WidgetForge\\media\\ring.tga")
    local c = config.ringColor or {0, 0.8, 1, 1}
    ring.texture:SetVertexColor(unpack(c))
    
    -- ===================================================================
    -- INNER CIRCLE: Circular Progress via Vertex Deformation
    -- ===================================================================
    local innerSize = config.innerRingSize or (ringSize * 0.6)
    local innerRing = CreateFrame("Frame", nil, ring)
    innerRing:SetSize(innerSize, innerSize)
    innerRing:SetPoint("CENTER")
    innerRing:SetFrameLevel(2001)
    
    local ic = config.innerRingColor or {1, 0.8, 0, 1}
    local CIRCLE_TEX = "Interface\\AddOns\\WidgetForge\\media\\circle.tga"
    
    -- Create 3 wedge textures (enough to cover any arc across quadrants)
    local wedges = {}
    for idx = 1, 3 do
        local tex = innerRing:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(CIRCLE_TEX)
        tex:SetVertexColor(ic[1], ic[2], ic[3], ic[4] or 0.85)
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        tex:Hide()
        wedges[idx] = tex
    end
    
    -- Corner order for quadrant traversal (repeats for circular wrapping)
    local CORNERS = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }
    
    -- Default UV coordinates for each corner
    local BASE_UV = {
        ULx = 0, ULy = 0,
        LLx = 0, LLy = 1,
        URx = 1, URy = 0,
        LRx = 1, LRy = 1,
    }
    
    -- Exact UV positions at 45° increments (0°=top-center clockwise)
    local SNAP_POINTS = {
        {0.5, 0},   -- 0°
        {1,   0},   -- 45°
        {1,   0.5}, -- 90°
        {1,   1},   -- 135°
        {0.5, 1},   -- 180°
        {0,   1},   -- 225°
        {0,   0.5}, -- 270°
        {0,   0},   -- 315°
    }
    
    -- Map an angle (degrees, 0°=top, clockwise) to UV coordinate on square edge
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
    
    -- Move a single corner of a texture: set its UV + vertex offset
    local VERTEX_MAP = {
        UL = UPPER_LEFT_VERTEX,
        UR = UPPER_RIGHT_VERTEX,
        LL = LOWER_LEFT_VERTEX,
        LR = LOWER_RIGHT_VERTEX,
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
    
    -- Build a single wedge between startAngle and endAngle
    local function BuildWedge(tex, startAngle, endAngle, w, h)
        local quadIdx = math.floor((startAngle + 45) / 90)
        local center   = CORNERS[quadIdx + 1]
        local edgeA    = CORNERS[quadIdx + 2]
        local edgeB1   = CORNERS[quadIdx + 3]
        local edgeB2   = CORNERS[quadIdx + 4]
        
        local coords = {}
        
        -- Pin one corner to the center of the texture
        DeformCorner(tex, center, 0.5, 0.5, w, h, coords)
        -- Start edge
        local su, sv = ComputeEdgePoint(startAngle)
        DeformCorner(tex, edgeA, su, sv, w, h, coords)
        
        -- End edges: if arc crosses a quadrant boundary, snap the intermediate corner
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
    
    -- Refresh all 3 wedges to display arc from degStart → degEnd
    local function RefreshWedges(degStart, degEnd)
        local w, h = innerRing:GetSize()
        if w == 0 or h == 0 then return end
        
        if degEnd - degStart >= 360 then
            -- Full circle: show one wedge with default coords, hide others
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
            -- Single wedge spans the arc
            BuildWedge(wedges[1], degStart, degEnd, w, h)
            wedges[2]:Hide(); wedges[3]:Hide()
        elseif bucket1 + 3 >= bucket2 then
            -- Two wedges
            local split = (bucket1 + 1) * 90 + 45
            BuildWedge(wedges[1], degStart, split, w, h)
            BuildWedge(wedges[2], split, degEnd, w, h)
            wedges[3]:Hide()
        else
            -- Three wedges
            local splitA = (bucket1 + 1) * 90 + 45
            local splitB = splitA + 180
            BuildWedge(wedges[1], degStart, splitA, w, h)
            BuildWedge(wedges[2], splitA, splitB, w, h)
            BuildWedge(wedges[3], splitB, degEnd, w, h)
        end
    end
    
    -- Show/Hide inner ring based on config
    if config.showInnerRing == false then
        innerRing:Hide()
    else
        innerRing:Show()
    end
    
    -- Apply Transparency
    ring:SetAlpha(config.transparency or 1.0)
    
    -- Trail Pool (Recycling)
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
            t.texture:SetTexture("Interface\\AddOns\\WidgetForge\\media\\ring.tga")
        else
            t:SetParent(UIParent) -- [FIX] Restore parent to ensure correct scaling inheritance
            t:SetFrameStrata("TOOLTIP") -- Reset strata just in case
            t:SetFrameLevel(1999)
        end
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

    -- GCD/Cast tracking state
    local lastGCDStart = 0
    local castStart, castDuration = 0, 0
    local activeStart, activeDuration = 0, 0
    
    -- Optimization: Cache last values to avoid needless redraws
    local lastProgress = -1
    
    -- Update Script
    ring:SetScript("OnUpdate", function(self, elapsed)
        -- Throttled Update? No, mouse needs smooth movement.
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        
        -- GCD / Cast Tracking → Circular Progress (skip if preview mode)
        if config.showInnerRing ~= false and innerRing:IsShown() and not f.previewMode then
            local trackMode = config.innerRingMode or "GCD"
            local progress = 0
            
            -- GCD Progress
            if trackMode == "GCD" or trackMode == "BOTH" then
                local cdInfo = C_Spell.GetSpellCooldown(61304)
                if cdInfo and cdInfo.duration and cdInfo.duration > 0 then
                    local gcdElapsed = GetTime() - cdInfo.startTime
                    local gcdPct = gcdElapsed / cdInfo.duration
                    if gcdPct > 1 then gcdPct = 1 end
                    if gcdPct > progress then progress = gcdPct end
                end
            end
            
            -- Cast Progress
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
            
            -- Optimization: Only refresh wedges if change > 0.5% (visual threshold)
            if math.abs(progress - lastProgress) > 0.005 then
                local fillAngle = progress * 360
                RefreshWedges(0, fillAngle)
                lastProgress = progress
            end
        end
        
        -- Trail Logic (Pooled)
        if config.trailEnabled then
            self.trailTimer = (self.trailTimer or 0) + elapsed
            local density = config.trailDensity or 0.005
            while self.trailTimer >= density do
                self.trailTimer = self.trailTimer - density
                
                local trail = GetTrailFrame()
                local trailSize = (config.ringSize or 64) * (config.trailScale or 1.0)
                trail:SetSize(trailSize, trailSize)
                trail:ClearAllPoints() -- [FIX] Prevent anchor accumulation on recycled frames
                trail:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                
                local tc = config.trailColor or {1, 1, 1, 1}
                trail.texture:SetVertexColor(tc[1], tc[2], tc[3], tc[4])
                trail:SetAlpha(0.6)
                
                local duration = config.trailDuration or 0.5
                local startTime = GetTime()
                
                trail:SetScript("OnUpdate", function(self2, el)
                    local age = GetTime() - startTime
                    if age >= duration then
                        RecycleTrailFrame(self2)
                    else
                        self2:SetAlpha(0.6 * (1 - age / duration))
                    end
                end)
            end
        end
    end)
    
    function f:UpdateVisuals(conf)
        if not conf then return end
        local col = conf.ringColor or {0, 0.8, 1, 1}
        ring.texture:SetVertexColor(unpack(col))
        local size = conf.ringSize or 64
        ring:SetSize(size, size)
        ring:SetAlpha(conf.transparency or 1.0)
        
        -- Inner Ring
        local iSize = conf.innerRingSize or (size * 0.6)
        innerRing:SetSize(iSize, iSize)
        local iCol = conf.innerRingColor or {1, 0.8, 0, 1}
        for wIdx = 1, 3 do
            wedges[wIdx]:SetVertexColor(iCol[1], iCol[2], iCol[3], iCol[4] or 0.85)
        end
        if conf.showInnerRing == false then innerRing:Hide() else innerRing:Show() end
        
        -- If in preview mode, show full circle
        if f.previewMode then
            RefreshWedges(0, 360)
        end
    end
    
    function f:ShowPreview()
        f.previewMode = true
        innerRing:Show()
        RefreshWedges(0, 360)
    end
    
    function f:HidePreview()
        f.previewMode = false
        RefreshWedges(0, 0)
    end
    
    f:UpdateVisuals(config)
    
    -- Cleanup when bar is destroyed/hidden
    f:SetScript("OnHide", function() ring:Hide() end)
    f:SetScript("OnShow", function() ring:Show() end)
    
    function f:Unload()
        ring:Hide()
        ring:SetScript("OnUpdate", nil)
        ring:SetParent(nil)
    end
    
    bar.cursorRing = ring
    return f
end

-- ===========================================================================
-- CURSOR RING SETTINGS POPUP
-- ===========================================================================
function WidgetForge:OpenCursorRingSettings(barIndex, elemIndex, elem)
    local f = WidgetForge.CursorRingSettingsFrame
    if not f then
        f = CreateFrame("Frame", "ForgeCursorRingSettings", UIParent, "BackdropTemplate")
        f:SetSize(540, 600) -- Same width as Dragonriding settings
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true); f:SetMovable(true)
        Skin:ApplyBackdrop(f)
        
        Skin:CreateTitleBar(f, "Cursor Ring Settings", function() f:Hide() end)
        
        local content = CreateFrame("Frame", nil, f)
        content:SetPoint("TOPLEFT", 20, -40)
        content:SetPoint("BOTTOMRIGHT", -20, 20)
        f.content = content
        
        WidgetForge.CursorRingSettingsFrame = f
        
        -- ESC key closes only this popup (not the main config behind it)
        f:SetPropagateKeyboardInput(true)
        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        f:HookScript("OnShow", function(self) self:EnableKeyboard(true) end)
        f:HookScript("OnHide", function(self) self:EnableKeyboard(false) end)
    end
    
    -- Clear old content via Builder Release
    if f.builder then
        f.builder:Release()
    end
    
    f:Show()
    
    -- Real-time visual refresh: finds the active cursor ring widget and calls UpdateVisuals
    local function RefreshCursorRing()
        local bars = WidgetForge:GetBarFrames()
        if bars and bars[barIndex] then
            local barFrame = bars[barIndex]
            if barFrame.customWidgets then
                for _, cw in ipairs(barFrame.customWidgets) do
                    if cw.UpdateVisuals then
                        cw:UpdateVisuals(elem)
                    end
                end
            end
        end
    end
    
    -- Show inner circle as preview when settings are open
    f.activeBarIndex = barIndex
    local bars = WidgetForge:GetBarFrames()
    if bars and bars[barIndex] and bars[barIndex].customWidgets then
        for _, cw in ipairs(bars[barIndex].customWidgets) do
            if cw.ShowPreview then cw:ShowPreview() end
        end
    end
    
    -- Set OnHide to cleanup preview (only once, uses stored barIndex)
    if not f.hidePreviewHooked then
        f.hidePreviewHooked = true
        f:HookScript("OnHide", function()
            local idx = f.activeBarIndex
            if idx then
                local brs = WidgetForge:GetBarFrames()
                if brs and brs[idx] and brs[idx].customWidgets then
                    for _, cw in ipairs(brs[idx].customWidgets) do
                        if cw.HidePreview then cw:HidePreview() end
                    end
                end
            end
        end)
    end
    
    -- Initialize Builder
    local sb = WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb
    
    -- === INITIALIZE DEFAULTS ===
    if elem.ringSize == nil then elem.ringSize = 64 end
    if elem.showInnerRing == nil then elem.showInnerRing = true end
    if elem.innerRingSize == nil then elem.innerRingSize = 38 end
    if elem.innerRingMode == nil then elem.innerRingMode = "GCD" end
    if elem.trailEnabled == nil then elem.trailEnabled = false end
    if elem.trailDuration == nil then elem.trailDuration = 0.5 end
    if elem.trailDensity == nil then elem.trailDensity = 0.005 end
    if elem.trailScale == nil then elem.trailScale = 1.0 end
    if elem.transparency == nil then elem.transparency = 1.0 end
    
    -- === CONTROLS ===
    
    -- --- Outer Ring ---
    sb:AddHeader("Outer Ring")
    sb:AddColor("ringColor", "Ring Color:", {0, 0.8, 1, 1}, elem, RefreshCursorRing)
    sb:AddSlider("ringSize", "Ring Size:", 16, 256, 4, 64, elem, RefreshCursorRing)
    
    -- --- Inner Ring (GCD / Cast) ---
    sb:AddHeader("Inner Ring (GCD / Cast)")
    sb:AddCheckbox("showInnerRing", "Enable Inner Ring", true, elem, RefreshCursorRing)
    sb:AddColor("innerRingColor", "Inner Ring Color:", {1, 0.8, 0, 1}, elem, RefreshCursorRing)
    sb:AddSlider("innerRingSize", "Inner Ring Size:", 8, 200, 2, 38, elem, RefreshCursorRing)
    sb:AddDropdown("innerRingMode", "Tracking Mode:", {
        {text = "GCD Only", value = "GCD"},
        {text = "Cast Only", value = "CAST"},
        {text = "Both", value = "BOTH"}
    }, "GCD", elem, RefreshCursorRing)
    
    -- --- Cursor Trail ---
    sb:AddHeader("Cursor Trail")
    sb:AddCheckbox("trailEnabled", "Enable Trail", false, elem, RefreshCursorRing)
    sb:AddColor("trailColor", "Trail Color:", {1, 1, 1, 1}, elem, RefreshCursorRing)
    sb:AddSlider("trailDuration", "Trail Duration:", 0.1, 2.0, 0.05, 0.5, elem, RefreshCursorRing)
    sb:AddSlider("trailDensity", "Trail Density:", 0.001, 0.05, 0.001, 0.005, elem, RefreshCursorRing)
    sb:AddSlider("trailScale", "Trail Scale:", 0.1, 3.0, 0.1, 1.0, elem, RefreshCursorRing)
    
    -- --- Visibility ---
    sb:AddHeader("Visibility")
    sb:AddSlider("transparency", "Transparency:", 0.1, 1.0, 0.05, 1.0, elem, RefreshCursorRing, true) -- Force Full Row
    
    sb:Finish()
end
