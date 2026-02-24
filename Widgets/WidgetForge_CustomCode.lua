-- =========================================================================
--  WidgetForge - Custom Code Module
--  Allows users to run arbitrary Lua code and display the returned string
-- =========================================================================

local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.CustomCode = {}
local CustomCode = _G.WidgetForge.CustomCode
addonTable.CustomCode = CustomCode

CustomCode.Instances = {}

-- --- WIDGET YÜKLEME ---
function CustomCode:Load(parent, elem)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(elem.widgetWidth or 100, elem.widgetHeight or 30)
    container.elem = elem
    
    local Skin = _G.ForgeSkin
    
    container.text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.text:SetAllPoints()
    
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then
        fontPath = Skin.Media.Fonts[elem.font] or fontPath
    end
    container.text:SetFont(fontPath, elem.fontSize or 14, elem.fontOutline or "OUTLINE")
    container.text:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
    container.text:SetJustifyH(elem.justifyH or "CENTER")
    
    if elem.enableShadow == false then
        container.text:SetShadowColor(0, 0, 0, 0)
        container.text:SetShadowOffset(0, 0)
    else
        container.text:SetShadowColor(0, 0, 0, 1)
        container.text:SetShadowOffset(1, -1)
    end

    local compiledFunc = nil
    local compileError = nil
    
    local function Compile()
        if not elem.code or elem.code == "" then
            compiledFunc = nil
            compileError = "No Code"
            return
        end
        
        local func, err = loadstring(elem.code)
        if func then
            setfenv(func, setmetatable({}, {__index = _G}))
            compiledFunc = func
            compileError = nil
        else
            compiledFunc = nil
            compileError = "Syntax Error"
        end
    end

    Compile()
    container.Compile = Compile

    local timer = 0
    container:SetScript("OnUpdate", function(self, elapsed)
        timer = timer + elapsed
        if timer >= 0.5 then
            timer = 0
            if compileError then
                self.text:SetText("|cffff0000" .. compileError .. "|r")
                return
            end
            
            if compiledFunc then
                local success, result = pcall(compiledFunc)
                if success then
                    self.text:SetText(tostring(result or ""))
                else
                    self.text:SetText("|cffff0000Lua Error|r")
                end
            else
                self.text:SetText("Custom Code")
            end
        end
    end)

    table.insert(CustomCode.Instances, container)
    
    container.Unload = function(self)
        for i, inst in ipairs(CustomCode.Instances) do
            if inst == self then table.remove(CustomCode.Instances, i); break end
        end
    end
    
    return container
end

-- =========================================================================
--  AYARLAR (CODE EDITOR & BUILDER)
-- =========================================================================
function CustomCode:CreateSettings(parentFrame)
    local f = parentFrame
    local elem = f.config
    local barIndex = f.barIndex
    local Skin = _G.ForgeSkin

    local sb = f.builder or _G.WidgetForgeUtils:CreateSettingsBuilder(f.content)
    f.builder = sb 
    
    local function RefreshLive()
        if barIndex and _G.WidgetForge then
            for _, inst in ipairs(CustomCode.Instances) do
                if inst.elem == elem then
                    local fontPath = "Fonts\\FRIZQT__.TTF"
                    if Skin and Skin.Media and Skin.Media.Fonts and elem.font then
                        fontPath = Skin.Media.Fonts[elem.font] or fontPath
                    end
                    inst.text:SetFont(fontPath, elem.fontSize or 14, elem.fontOutline or "OUTLINE")
                    inst.text:SetTextColor(unpack(elem.color or {1, 1, 1, 1}))
                    inst.text:SetJustifyH(elem.justifyH or "CENTER")
                    
                    if elem.enableShadow == false then
                        inst.text:SetShadowColor(0, 0, 0, 0)
                        inst.text:SetShadowOffset(0, 0)
                    else
                        inst.text:SetShadowColor(0, 0, 0, 1)
                        inst.text:SetShadowOffset(1, -1)
                    end
                    
                    inst:SetSize(elem.widgetWidth or 100, elem.widgetHeight or 30)
                    if inst.Compile then inst.Compile() end
                end
            end
            _G.WidgetForge:UpdateBarValues(barIndex)
        end
    end

    sb:AddHeader("Dimensions & Alignment")
    sb:AddSlider("widgetWidth", "Container Width", 30, 400, 1, 100, elem, RefreshLive)
    sb:AddSlider("widgetHeight", "Container Height", 10, 100, 1, 30, elem, RefreshLive)
    sb:AddDropdown("justifyH", "Text Alignment", { {text="Left", value="LEFT"}, {text="Center", value="CENTER"}, {text="Right", value="RIGHT"} }, "CENTER", elem, RefreshLive)

    sb:AddHeader("Typography")
    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then
        for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=k, value=k}) end
    end
    if #fontItems == 0 then fontItems = {{text="Default", value="Fonts\\FRIZQT__.TTF"}} end

    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, RefreshLive)
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 14, elem, RefreshLive)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, RefreshLive)
    sb:AddCheckbox("enableShadow", "Enable Drop Shadow", true, elem, RefreshLive)
    sb:AddColor("color", "Text Color", {1, 1, 1, 1}, elem, RefreshLive)

    sb:Finish()

    -- ==========================================================
    --  %100 FORGESKIN IMPORT/EXPORT UYUMLU MODERN EDİTÖR
    -- ==========================================================
    local bottomY = 0
    if f.content then
        for _, child in ipairs({f.content:GetChildren()}) do
            if child:IsShown() then
                local _, _, _, _, y = child:GetPoint()
                if y and type(y) == "number" then
                    local childBottom = y - child:GetHeight()
                    if childBottom < bottomY then bottomY = childBottom end
                end
            end
        end
        
        bottomY = bottomY - 30
        
        local lbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("TOPLEFT", 10, bottomY) 
        lbl:SetText("|cff00ccffLUA Code Editor:|r (MUST return a string/number)")
        
        local warn = f.content:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
        warn:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
        warn:SetText("WARNING: Do not paste untrusted code!")

        -- 1. Arkaplan Kutusu
        local bg = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", 10, bottomY - 20)
        bg:SetSize(600, 200)
        if Skin then Skin:ApplyBackdrop(bg, 0.4, 0.8) end 

        -- 2. Kendi Kütüphanemizin Hatasız ScrollFrame'i
        -- [GÜNCELLEME] Genişlik arkaplanla aynı (600) yapıldı ve sol köşeye 0 noktasından yapıştırıldı.
        -- Böylece sağdaki kaydırma çubuğu tam olarak duvara yapışacak.
        local sf, scrollChild = Skin:CreateScrollFrame(bg, 600, 190)
        sf:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, -5)

        -- 3. EditBox
        local eb = CreateFrame("EditBox", nil, scrollChild)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(570) 
        -- [GÜNCELLEME] Yazılar soldan 10px boşlukla başlasın ki sol ve sağ simetrik gözüksün.
        eb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -5)
        eb:SetText(elem.code or "return \"Hello World\"")
        
        -- DİKKAT: Boşluğa tıklayınca imlecin (editörün) aktif olması için arkaplanları tıklanabilir yaptık
        bg:EnableMouse(true)
        scrollChild:EnableMouse(true)
        
        local function FocusEditor()
            eb:SetFocus()
        end
        
        bg:SetScript("OnMouseDown", FocusEditor)
        scrollChild:SetScript("OnMouseDown", FocusEditor)
        sf:SetScript("OnMouseDown", FocusEditor)

        -- 4. BÜYÜLÜ ÇÖZÜM: Kendi GetHeight'ini kullanmak
        eb:SetScript("OnTextChanged", function(self, isUserInput)
            local h = self:GetHeight()
            scrollChild:SetHeight(math.max(190, h + 20))
            
            if isUserInput then
                elem.code = self:GetText()
                for _, inst in ipairs(CustomCode.Instances) do
                    if inst.elem == elem and inst.Compile then inst.Compile() end
                end
            end
        end)
        
        eb:GetScript("OnTextChanged")(eb, false)

        -- EditBox'ta ok tuşlarına veya Enter'a basıldığında ScrollFrame'in kamerayı kaydırması
        eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
            local cursorY = math.abs(y)
            local currentScroll = sf:GetVerticalScroll()
            local sfHeight = sf:GetHeight()
            
            if cursorY < currentScroll then
                sf:SetVerticalScroll(math.max(0, cursorY - 10))
            elseif cursorY + h > currentScroll + sfHeight then
                sf:SetVerticalScroll((cursorY + h) - sfHeight + 10)
            end
        end)

        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        
        -- HATALARDAN ARINDIRILMIŞ ŞABLONLAR
        local sY = bottomY - 235
        local sLbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", 10, sY)
        sLbl:SetText("Quick Snippets (Replaces current code):")

        local snippetList = {
            {text = "Select a snippet...", value = "NONE"},
            {text = "--- Player Info ---", value = "NONE"},
            {text = "Player Name & Realm", value = "return UnitName('player') .. ' - ' .. GetRealmName()"},
            {text = "Class & Level", value = "local lvl = UnitLevel('player') or 0\nlocal cls = UnitClass('player') or 'Unknown'\nreturn string.format('Lvl %d %s', lvl, cls)"},
            {text = "Current Speed", value = "local speed = GetUnitSpeed('player') or 0\nreturn string.format('Speed: %.0f%%', (speed/7)*100)"},
            {text = "--- System & World ---", value = "NONE"},
            {text = "FPS & Latency", value = "local _, _, lat = GetNetStats()\nreturn string.format('FPS: %d | MS: %d', floor(GetFramerate()), lat)"},
            {text = "Current Zone", value = "return GetMinimapZoneText() or 'Unknown'"},
            {text = "Coordinates", value = "local m = C_Map.GetBestMapForUnit('player')\nif not m then return '0, 0' end\nlocal p = C_Map.GetPlayerMapPosition(m, 'player')\nif not p then return '0, 0' end\nreturn string.format('%.1f, %.1f', p.x*100, p.y*100)"},
            {text = "--- Utility ---", value = "NONE"},
            {text = "Gold Count", value = "local money = GetMoney() or 0\nreturn GetCoinTextureString(money)"},
            {text = "Free Bag Space", value = "local f, t = 0, 0\nfor i = 0, NUM_BAG_SLOTS do\n  f = f + C_Container.GetContainerNumFreeSlots(i)\n  t = t + C_Container.GetContainerNumSlots(i)\nend\nreturn string.format('Bags: %d/%d', f, t)"},
        }

        local ddSnippets = Skin:CreateDropdown(f.content, 250, snippetList, "NONE", function(val)
            if val ~= "NONE" then
                eb:SetText(val)
                elem.code = val
                for _, inst in ipairs(CustomCode.Instances) do
                    if inst.elem == elem and inst.Compile then inst.Compile() end
                end
                eb:ClearFocus()
            end
        end)
        ddSnippets:SetPoint("TOPLEFT", 10, sY - 15)

        if f.content.SetHeight then 
            f.content:SetHeight(math.abs(sY - 60)) 
        end
    end
end