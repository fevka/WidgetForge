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

local function Clamp(v, a, b) if v < a then return a elseif v > b then return b else return v end end
local function FNum(n) n = math.floor((tonumber(n) or 0) + 0.5); return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end
local function FDur(s) s = math.max(0, math.floor(s or 0)); local h=math.floor(s/3600); local m=math.floor((s%3600)/60); local ss=s%60; return h>0 and string.format("%02d:%02d:%02d",h,m,ss) or string.format("%02d:%02d",m,ss) end
local function Just(a) if a=="TOPRIGHT" or a=="RIGHT" or a=="BOTTOMRIGHT" then return "RIGHT" elseif a=="TOP" or a=="CENTER" or a=="BOTTOM" then return "CENTER" end return "LEFT" end
local function NormLayout(v) v=tostring(v or ""):upper(); if v=="SPIL" or v=="SPILT" then v="SPLIT" end; if v~="SPLIT" and v~="ABOVE" and v~="BELOW" and v~="CUSTOM" then v="SPLIT" end; return v end
local function NormRole(v) v=tostring(v or ""):upper(); local ok={AUTO_TOP=1,AUTO_BOTTOM=1,SUMMARY=1,XP=1,REMAIN=1,RESTED=1,ETA=1,SESSION=1,LAST=1,EMPTY=1}; return ok[v] and v or "AUTO_TOP" end
local function ParseMilestones(str) local t={}; if type(str)~="string" then return t end; for tok in string.gmatch(str,"([^,%s]+)") do local n=tonumber(tok); if n and n>0 then t[math.floor(n)]=true end end; return t end

local function TexturePath(key)
    local fb = "Interface\\TargetingFrame\\UI-StatusBar"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures and key then return _G.ForgeSkin.Media.Textures[key] or fb end
    return fb
end

local function FontPath(key)
    local fb = "Fonts\\FRIZQT__.TTF"
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts and key then return _G.ForgeSkin.Media.Fonts[key] or fb end
    return fb
end

local function Backdrop(f, edge, bg, brd)
    if not f or not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", tile=false, edgeSize=edge or 1, insets={left=0,right=0,top=0,bottom=0} })
    if bg then f:SetBackdropColor(bg[1],bg[2],bg[3],bg[4] or 1) end
    if brd then f:SetBackdropBorderColor(brd[1],brd[2],brd[3],brd[4] or 1) end
end

local function XPState()
    local cur=UnitXP("player") or 0; local max=UnitXPMax("player") or 0; local lvl=UnitLevel("player") or 0; local rested=(GetXPExhaustion and GetXPExhaustion()) or 0
    local isMax=max<=0; local pct=isMax and 100 or ((max>0) and ((cur/max)*100) or 0); local rem=isMax and 0 or math.max(0,max-cur)
    return {cur=cur,max=max,lvl=lvl,rested=rested,isMax=isMax,pct=pct,rem=rem}
end

local function AnnounceChannel(m)
    if m=="PARTY" then
        if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        if IsInGroup and IsInGroup() then return "PARTY" end
    elseif m=="GUILD" then
        if IsInGuild and IsInGuild() then return "GUILD" end
    elseif m=="SAY" then
        return "SAY"
    end
    return nil
end

local function Ensure(e)
    if not e then return end
    e.widgetWidth = e.widgetWidth or 320
    e.widgetHeight = e.widgetHeight or 72
    e.barHeight = e.barHeight or 16
    e.barOffsetY = e.barOffsetY or 0
    e.fontSize = e.fontSize or 12
    e.font = e.font or "Righteous"
    e.fontOutline = e.fontOutline or "OUTLINE"
    e.texture = e.texture or "2. Smooth"
    e.textLayout = e.textLayout or "SPLIT"
    e.line1Role = e.line1Role or "AUTO_TOP"
    e.line2Role = e.line2Role or "AUTO_BOTTOM"
    e.textAnchorSpace = e.textAnchorSpace or "PANEL"
    e.topTextAnchor = e.topTextAnchor or "TOPLEFT"
    e.bottomTextAnchor = e.bottomTextAnchor or "BOTTOMLEFT"
    e.topTextOffsetX = e.topTextOffsetX or 0; e.topTextOffsetY = e.topTextOffsetY or 0
    e.bottomTextOffsetX = e.bottomTextOffsetX or 0; e.bottomTextOffsetY = e.bottomTextOffsetY or 0
    if e.panelBgAlpha == nil then e.panelBgAlpha = 0 end
    if e.barBgAlpha == nil then e.barBgAlpha = 0.12 end
    if e.showPanelBorder == nil then e.showPanelBorder = true end
    if e.showBarBorder == nil then e.showBarBorder = true end
    e.panelBorderSize = e.panelBorderSize or 1
    e.barBorderSize = e.barBorderSize or 1
    e.panelBorderColor = e.panelBorderColor or {0.18,0.18,0.18,1}
    e.barBorderColor = e.barBorderColor or {0.15,0.15,0.15,1}
    e.xpBarColor = e.xpBarColor or {0.1,0.7,1,1}
    e.flashColor = e.flashColor or {1,0.85,0.2,1}
    e.textColor = e.textColor or {1,1,1,1}
    if e.compactMode == nil then e.compactMode = false end
    if e.showPercent == nil then e.showPercent = true end
    if e.showRemainingXP == nil then e.showRemainingXP = true end
    if e.showRestedXP == nil then e.showRestedXP = true end
    if e.showSessionTime == nil then e.showSessionTime = false end
    if e.showTimeToLevel == nil then e.showTimeToLevel = false end
    if e.showLastLevelUp == nil then e.showLastLevelUp = true end
    if e.playSoundOnLevelUp == nil then e.playSoundOnLevelUp = true end
    e.announceInChat = e.announceInChat or "OFF"
    e.milestoneLevels = e.milestoneLevels or "10,20,30,40,50,60,70,80"
end

function M:UpdateVisuals(f, e)
    if not f or not e then return end
    Ensure(e)
    local layout = NormLayout(e.textLayout)
    local compact = (e.compactMode == true and layout ~= "SPLIT")
    local minH = compact and 46 or ((layout=="ABOVE" or layout=="BELOW") and 72 or 58)
    if e.widgetHeight < minH then e.widgetHeight = minH end

    local w = math.max(160, e.widgetWidth or 320)
    local h = math.max(minH, e.widgetHeight or 72)
    local fs = math.max(9, e.fontSize or 12)
    local pad, gap, minBar = 6, 3, 8

    f:SetSize(w, h)
    f.panel:SetAllPoints(f)

    local pEdge = (e.showPanelBorder == false) and 0 or (e.panelBorderSize or 1)
    Backdrop(f.panel, math.max(1, pEdge), {0,0,0,e.panelBgAlpha or 0}, (pEdge>0) and (e.panelBorderColor or {0.18,0.18,0.18,1}) or {0,0,0,0})
    local bEdge = (e.showBarBorder == false) and 0 or (e.barBorderSize or 1)
    Backdrop(f.barFrame, math.max(1, bEdge), {0,0,0,e.barBgAlpha or 0.12}, (bEdge>0) and (e.barBorderColor or {0.15,0.15,0.15,1}) or {0,0,0,0})

    f.bar:SetStatusBarTexture(TexturePath(e.texture))
    f.bar:SetStatusBarColor(unpack(e.xpBarColor or {0.1,0.7,1,1}))

    local fp = FontPath(e.font)
    f.top:SetFont(fp, fs+1, e.fontOutline or "OUTLINE")
    f.bottom:SetFont(fp, math.max(9, fs-1), e.fontOutline or "OUTLINE")
    f.top:SetTextColor(unpack(e.textColor or {1,1,1,1}))
    f.bottom:SetTextColor(unpack(e.textColor or {1,1,1,1}))
    f.top:SetWordWrap(false); f.bottom:SetWordWrap(false)
    if f.top.SetMaxLines then f.top:SetMaxLines(1) end
    if f.bottom.SetMaxLines then f.bottom:SetMaxLines(1) end
    f.top:SetShadowOffset(1,-1); f.bottom:SetShadowOffset(1,-1)

    f.top:ClearAllPoints(); f.bottom:ClearAllPoints(); f.barFrame:ClearAllPoints(); f.bar:ClearAllPoints()
    f.top:Show(); f.bottom:Show(); f.barFrame:Show(); f.bar:Show()

    local function PlaceBar(top, bh)
        local maxBh = math.max(minBar, h-(pad*2))
        bh = Clamp(math.floor(bh or e.barHeight or 16), minBar, maxBh)
        local maxTop = math.max(pad, h-pad-bh)
        top = Clamp(math.floor(top or pad), pad, maxTop)
        f.barFrame:SetPoint("TOPLEFT", f.panel, "TOPLEFT", pad, -top)
        f.barFrame:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -pad, -top)
        f.barFrame:SetHeight(bh)
        local inset = math.min((bEdge>0) and (bEdge+1) or 1, math.max(1, math.floor((bh-4)/2)))
        f.bar:SetPoint("TOPLEFT", f.barFrame, "TOPLEFT", inset, -inset)
        f.bar:SetPoint("BOTTOMRIGHT", f.barFrame, "BOTTOMRIGHT", -inset, inset)
    end

    local l1 = fs + 6
    local l2 = math.max(9, fs-1) + 5

    local function TopLine()
        f.top:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 8, -6)
        f.top:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -8, -6)
        f.top:SetJustifyH("LEFT")
    end
    local function BottomLine()
        f.bottom:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 8, 6)
        f.bottom:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -8, 6)
        f.bottom:SetJustifyH("LEFT")
    end

    if compact then
        TopLine(); f.bottom:Hide()
        local topReserve = l1 + pad + gap
        PlaceBar(topReserve, math.min(e.barHeight or 16, math.max(minBar, h-topReserve-pad)))
        return
    end

    if layout == "CUSTOM" then
        local bh = Clamp(e.barHeight or 16, minBar, math.max(minBar, h-(pad*2)))
        local top = math.floor((h-bh)/2) - (e.barOffsetY or 0)
        PlaceBar(top, bh)
        local parent = (e.textAnchorSpace == "BAR") and f.barFrame or f.panel
        local ta = e.topTextAnchor or "TOPLEFT"; local ba = e.bottomTextAnchor or "BOTTOMLEFT"
        f.top:SetPoint(ta, parent, ta, e.topTextOffsetX or 0, e.topTextOffsetY or 0)
        f.bottom:SetPoint(ba, parent, ba, e.bottomTextOffsetX or 0, e.bottomTextOffsetY or 0)
        f.top:SetJustifyH(Just(ta)); f.bottom:SetJustifyH(Just(ba))
        return
    end

    local desired = e.barHeight or 16
    if layout == "ABOVE" then
        TopLine()
        f.bottom:SetPoint("TOPLEFT", f.top, "BOTTOMLEFT", 0, -gap)
        f.bottom:SetPoint("TOPRIGHT", f.top, "BOTTOMRIGHT", 0, -gap)
        f.bottom:SetJustifyH("LEFT")
        local topReserve = pad + l1 + gap + l2 + gap
        local avail = h - topReserve - pad
        if avail < minBar then f.bottom:Hide(); topReserve = pad + l1 + gap; avail = h - topReserve - pad end
        if avail < minBar then f.top:Hide(); topReserve = pad; avail = h - topReserve - pad end
        PlaceBar(topReserve, math.min(desired, math.max(minBar, avail))); return
    end

    if layout == "BELOW" then
        BottomLine()
        f.top:SetPoint("BOTTOMLEFT", f.bottom, "TOPLEFT", 0, gap)
        f.top:SetPoint("BOTTOMRIGHT", f.bottom, "TOPRIGHT", 0, gap)
        f.top:SetJustifyH("LEFT")
        local bottomReserve = pad + l2 + gap + l1 + gap
        local avail = h - pad - bottomReserve
        if avail < minBar then f.top:Hide(); bottomReserve = pad + l2 + gap; avail = h - pad - bottomReserve end
        if avail < minBar then f.bottom:Hide(); bottomReserve = pad; avail = h - pad - bottomReserve end
        PlaceBar(pad, math.min(desired, math.max(minBar, avail))); return
    end

    -- SPLIT
    TopLine(); BottomLine()
    local topReserve = pad + l1 + gap
    local bottomReserve = pad + l2 + gap
    local avail = h - topReserve - bottomReserve
    if avail < minBar then f.bottom:Hide(); bottomReserve = pad; avail = h - topReserve - bottomReserve end
    if avail < minBar then f.top:Hide(); topReserve = pad; avail = h - topReserve - bottomReserve end
    local bh = math.min(desired, math.max(minBar, avail))
    local bt = topReserve + math.floor((math.max(minBar, avail)-bh)/2)
    PlaceBar(bt, bh)
end

function M:RefreshInstance(f)
    if not f or not f.elem then return end
    local e = f.elem; Ensure(e)
    local now = GetTime()
    local x = XPState()

    local start = self.SessionStarts[e]; if not start then start = now; self.SessionStarts[e] = start end
    f.startedAt = start
    f.rateLevel = f.rateLevel or x.lvl
    f.rateElapsed = f.rateElapsed or 0; f.rateGained = f.rateGained or 0
    if x.lvl ~= f.rateLevel then
        f.rateLevel = x.lvl; f.rateElapsed = 0; f.rateGained = 0; f.lastXP = x.cur; f.lastXPTime = now
    else
        if f.lastXPTime then
            local dt = math.max(0, now - f.lastXPTime); local dx = x.cur - (f.lastXP or 0); if dx < 0 then dx = 0 end
            if dt > 0 and dx > 0 then f.rateElapsed = f.rateElapsed + dt; f.rateGained = f.rateGained + dx end
        end
        f.lastXP = x.cur; f.lastXPTime = now
    end

    f.bar:SetMinMaxValues(0, x.isMax and 1 or math.max(1, x.max))
    f.bar:SetValue(x.isMax and 1 or x.cur)

    local p1 = { string.format("Lv %d", x.lvl) }
    if not x.isMax and e.showPercent ~= false then p1[#p1+1] = string.format("%.1f%%", x.pct) elseif x.isMax then p1[#p1+1] = "MAX" end
    local p2 = {}
    if x.isMax then p2[#p2+1] = "Maximum level reached" else
        p2[#p2+1] = FNum(x.cur) .. " / " .. FNum(x.max)
        if e.showRemainingXP ~= false then p2[#p2+1] = "Remain " .. FNum(x.rem) end
        if e.showRestedXP ~= false and x.rested > 0 then p2[#p2+1] = "Rested +" .. FNum(x.rested) end
    end
    local session = (e.showSessionTime == true) and ("Session " .. FDur(now - f.startedAt)) or ""
    local last = (e.showLastLevelUp ~= false and f.lastLevelUpAt) and ("Last +" .. date("%H:%M", f.lastLevelUpAt)) or ""
    local eta = ""
    if e.showTimeToLevel == true and not x.isMax and f.rateElapsed > 0 and f.rateGained > 0 then
        local r = f.rateGained / f.rateElapsed; if r > 0 then eta = "ETA " .. FDur(x.rem / r) end
    end

    local autoTop = table.concat(p1, "   "); if session~="" then autoTop = autoTop .. "   " .. session end; if last~="" then autoTop = autoTop .. "   " .. last end
    local autoBottom = table.concat(p2, "   "); if eta~="" then autoBottom = (autoBottom~="" and (autoBottom.."   ") or "") .. eta end
    local map = {
        AUTO_TOP=autoTop, AUTO_BOTTOM=autoBottom, SUMMARY=table.concat(p1,"   "),
        XP=x.isMax and "MAX" or (FNum(x.cur) .. " / " .. FNum(x.max)),
        REMAIN=x.isMax and "" or ("Remain " .. FNum(x.rem)),
        RESTED=(x.rested>0) and ("Rested +"..FNum(x.rested)) or "",
        ETA=eta, SESSION=session, LAST=last, EMPTY="",
    }

    local l1 = map[NormRole(e.line1Role)] or autoTop
    local l2 = map[NormRole(e.line2Role)] or autoBottom
    local compact = (e.compactMode == true and NormLayout(e.textLayout) ~= "SPLIT")
    if compact then
        if l2 ~= "" then l1 = (l1~="" and (l1.."   ") or "") .. l2 end
        f.top:SetText(l1 or ""); f.bottom:SetText("")
    else
        f.top:SetText(l1 or ""); f.bottom:SetText(l2 or "")
    end

    if f.flashUntil and now < f.flashUntil then f.bar:SetStatusBarColor(unpack(e.flashColor or {1,0.85,0.2,1}))
    else f.flashUntil = nil; f.bar:SetStatusBarColor(unpack(e.xpBarColor or {0.1,0.7,1,1})) end
end

function M:RefreshAll() for _,i in ipairs(self.Instances) do self:RefreshInstance(i) end end

function M:HandleLevelUp(newLevel)
    local nowEpoch = time(); local play = false; local mode=nil; local ms=nil
    for _,i in ipairs(self.Instances) do
        i.lastLevelUpAt = nowEpoch; i.flashUntil = GetTime() + 1.2
        i.rateLevel = newLevel or (UnitLevel("player") or i.rateLevel); i.rateElapsed = 0; i.rateGained = 0; i.lastXP = UnitXP("player") or 0; i.lastXPTime = GetTime()
        local e = i.elem or {}; if e.playSoundOnLevelUp ~= false then play = true end
        if not mode and e.announceInChat and e.announceInChat ~= "OFF" then mode = e.announceInChat; ms = ParseMilestones(e.milestoneLevels or "") end
    end
    if play and PlaySound then if SOUNDKIT and SOUNDKIT.UI_LEVELUP then PlaySound(SOUNDKIT.UI_LEVELUP, "Master") elseif SOUNDKIT and SOUNDKIT.UI_70_MAX_LEVEL_UP then PlaySound(SOUNDKIT.UI_70_MAX_LEVEL_UP, "Master") end end
    if mode and SendChatMessage then local ch = AnnounceChannel(mode); if ch then local lv = tonumber(newLevel) or (UnitLevel("player") or 0); local msg = ("Level Up! New level: %d"):format(lv); if ms and ms[lv] then msg = msg .. " (Milestone)" end; SendChatMessage(msg, ch) end end
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

function M:UnregisterEvents() self.eventFrame:UnregisterAllEvents() end

function M:Load(parent, elem)
    Ensure(elem)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetAllPoints(parent); f.elem = elem
    f.panel = CreateFrame("Frame", nil, f, "BackdropTemplate"); f.panel:SetAllPoints(f)
    f.barFrame = CreateFrame("Frame", nil, f.panel, "BackdropTemplate")
    f.bar = CreateFrame("StatusBar", nil, f.barFrame); f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); f.bar:SetMinMaxValues(0,1); f.bar:SetValue(0)
    f.top = f.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.bottom = f.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.elapsed = 0
    f:SetScript("OnUpdate", function(self, dt) self.elapsed = self.elapsed + dt; if self.elapsed >= 0.25 then self.elapsed = 0; M:RefreshInstance(self) end end)

    table.insert(self.Instances, f)
    if #self.Instances == 1 then self:RegisterEvents() end
    if not self.SessionStarts[elem] then self.SessionStarts[elem] = GetTime() end
    f.startedAt = self.SessionStarts[elem]
    self:UpdateVisuals(f, elem); self:RefreshInstance(f)

    f.Unload = function(selfRef)
        selfRef:SetScript("OnUpdate", nil)
        for i=#M.Instances,1,-1 do if M.Instances[i]==selfRef then table.remove(M.Instances,i) break end end
        if #M.Instances == 0 then M:UnregisterEvents() end
    end
    return f
end

function M:CreateSettings(parentFrame)
    local f = parentFrame; local e = f.config; local barIndex = f.barIndex; Ensure(e)
    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content); f.builder = sb
    local function RL()
        for _,i in ipairs(M.Instances) do if i.elem==e then M:UpdateVisuals(i,e); M:RefreshInstance(i) end end
        if barIndex and _G.WidgetForge then _G.WidgetForge:UpdateBarValues(barIndex, true) end
    end

    local texItems, fontItems = {}, {}
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Textures then for k in pairs(_G.ForgeSkin.Media.Textures) do texItems[#texItems+1]={text=tostring(k),value=k} end table.sort(texItems,function(a,b) return a.text<b.text end) end
    if #texItems==0 then texItems={{text="Default",value=""}} end
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Fonts then for k in pairs(_G.ForgeSkin.Media.Fonts) do fontItems[#fontItems+1]={text=tostring(k),value=k} end table.sort(fontItems,function(a,b) return a.text<b.text end) end
    if #fontItems==0 then fontItems={{text="Friz Quadrata",value=""}} end
    local outline = ({ {text="None",value=""},{text="Outline",value="OUTLINE"},{text="Thick",value="THICKOUTLINE"},{text="Monochrome",value="MONOCHROME"},{text="Mono+Outline",value="MONOCHROME,OUTLINE"} })
    if _G.ForgeSkin and _G.ForgeSkin.Media and _G.ForgeSkin.Media.Outlines and #_G.ForgeSkin.Media.Outlines>0 then outline=_G.ForgeSkin.Media.Outlines end
    local role = { {text="Auto Top",value="AUTO_TOP"},{text="Auto Bottom",value="AUTO_BOTTOM"},{text="Summary",value="SUMMARY"},{text="XP",value="XP"},{text="Remaining",value="REMAIN"},{text="Rested",value="RESTED"},{text="ETA",value="ETA"},{text="Session",value="SESSION"},{text="Last Level",value="LAST"},{text="Empty",value="EMPTY"} }
    local anch = { {text="Top Left",value="TOPLEFT"},{text="Top",value="TOP"},{text="Top Right",value="TOPRIGHT"},{text="Left",value="LEFT"},{text="Center",value="CENTER"},{text="Right",value="RIGHT"},{text="Bottom Left",value="BOTTOMLEFT"},{text="Bottom",value="BOTTOM"},{text="Bottom Right",value="BOTTOMRIGHT"} }

    sb:AddHeader("Layout")
    sb:AddSlider("widgetWidth","Widget Width",160,700,5,320,e,RL)
    sb:AddSlider("widgetHeight","Widget Height",44,220,1,72,e,RL)
    sb:AddSlider("barHeight","Bar Height",8,80,1,16,e,RL)
    sb:AddSlider("barOffsetY","Bar Offset Y (Custom)",-120,120,1,0,e,RL)
    sb:AddDropdown("textLayout","Text Position",{{text="Split (Top/Bottom)",value="SPLIT"},{text="Both Above Bar",value="ABOVE"},{text="Both Below Bar",value="BELOW"},{text="Custom (Free Place)",value="CUSTOM"}},"SPLIT",e,RL)
    sb:AddSwitch("compactMode","Compact Mode",false,e,RL)

    sb:AddHeader("Typography")
    sb:AddSlider("fontSize","Font Size",9,30,1,12,e,RL)
    sb:AddDropdown("font","Font Style",fontItems,"Righteous",e,RL)
    sb:AddDropdown("fontOutline","Font Outline",outline,"OUTLINE",e,RL)
    sb:AddColor("textColor","Text Color",{1,1,1,1},e,RL)

    sb:AddHeader("Line Roles")
    sb:AddDropdown("line1Role","Line 1 Content",role,"AUTO_TOP",e,RL)
    sb:AddDropdown("line2Role","Line 2 Content",role,"AUTO_BOTTOM",e,RL)

    sb:AddHeader("Custom Anchors")
    sb:AddDropdown("textAnchorSpace","Anchor Space",{{text="Panel",value="PANEL"},{text="Bar",value="BAR"}},"PANEL",e,RL)
    sb:AddDropdown("topTextAnchor","Line 1 Anchor",anch,"TOPLEFT",e,RL)
    sb:AddDropdown("bottomTextAnchor","Line 2 Anchor",anch,"BOTTOMLEFT",e,RL)
    sb:AddSlider("topTextOffsetX","Line 1 Offset X",-400,400,1,0,e,RL)
    sb:AddSlider("topTextOffsetY","Line 1 Offset Y",-220,220,1,0,e,RL)
    sb:AddSlider("bottomTextOffsetX","Line 2 Offset X",-400,400,1,0,e,RL)
    sb:AddSlider("bottomTextOffsetY","Line 2 Offset Y",-220,220,1,0,e,RL)

    sb:AddHeader("Bar & Borders")
    sb:AddDropdown("texture","Bar Texture",texItems,"2. Smooth",e,RL)
    sb:AddColor("xpBarColor","XP Bar Color",{0.1,0.7,1,1},e,RL)
    sb:AddColor("flashColor","Level-Up Flash Color",{1,0.85,0.2,1},e,RL)
    sb:AddSlider("panelBgAlpha","Panel Background Alpha",0,0.8,0.01,0,e,RL)
    sb:AddSlider("barBgAlpha","Bar Background Alpha",0,0.8,0.01,0.12,e,RL)
    sb:AddSwitch("showPanelBorder","Show Widget Border",true,e,RL)
    sb:AddSlider("panelBorderSize","Widget Border Size",0,6,1,1,e,RL)
    sb:AddColor("panelBorderColor","Widget Border Color",{0.18,0.18,0.18,1},e,RL)
    sb:AddSwitch("showBarBorder","Show XP Border",true,e,RL)
    sb:AddSlider("barBorderSize","XP Border Size",0,6,1,1,e,RL)
    sb:AddColor("barBorderColor","XP Border Color",{0.15,0.15,0.15,1},e,RL)

    sb:AddHeader("Data Toggles")
    sb:AddSwitch("showPercent","Show Percent",true,e,RL)
    sb:AddSwitch("showRemainingXP","Show Remaining XP",true,e,RL)
    sb:AddSwitch("showRestedXP","Show Rested XP",true,e,RL)
    sb:AddSwitch("showSessionTime","Show Session Time",false,e,RL)
    sb:AddSwitch("showTimeToLevel","Show Time To Level",false,e,RL)
    sb:AddSwitch("showLastLevelUp","Show Last Level-Up Time",true,e,RL)

    sb:AddHeader("Level-Up Actions")
    sb:AddSwitch("playSoundOnLevelUp","Play Sound On Level Up",true,e,RL)
    sb:AddDropdown("announceInChat","Announce In Chat",{{text="Off",value="OFF"},{text="Party",value="PARTY"},{text="Guild",value="GUILD"},{text="Say",value="SAY"}},"OFF",e,RL)
    sb:Finish()

    if not f.content then return end
    local by = sb.y - 10
    local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lbl:SetPoint("TOPLEFT", 10, by); lbl:SetText("Milestone Levels (comma separated)")
    local ebf = CreateFrame("Frame", nil, f.content, "BackdropTemplate"); ebf:SetSize(340,28); ebf:SetPoint("TOPLEFT",10,by-20); if _G.ForgeSkin then _G.ForgeSkin:ApplyBackdrop(ebf) end; ebf:SetBackdropColor(0,0,0,0.5)
    local eb = CreateFrame("EditBox", nil, ebf); eb:SetAllPoints(ebf); eb:SetTextInsets(6,6,0,0); eb:SetFontObject(ChatFontNormal); eb:SetAutoFocus(false); eb:SetText(e.milestoneLevels or "10,20,30,40,50,60,70,80")
    eb:SetScript("OnTextChanged", function(self, ui) if ui then e.milestoneLevels = self:GetText() end end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RL() end)
    if f.content.SetHeight then f.content:SetHeight(math.abs(by) + 90) end
end
