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
    -- Kullanıcının belirlediği kutu boyutu
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

    local compiledFunc = nil
    local compileError = nil
    
    -- Kodu sadece değiştiğinde derle
    local function Compile()
        if not elem.code or elem.code == "" then
            compiledFunc = nil
            compileError = "No Code"
            return
        end
        
        local func, err = loadstring(elem.code)
        if func then
            -- Sandbox: Oyunun kökünü koruma
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
        -- Sadece her 0.5 saniyede bir çalıştır (FPS dostu)
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
    
    local function Refresh()
        if barIndex and _G.WidgetForge then
            _G.WidgetForge:RebuildBarComponents(barIndex)
            for _, inst in ipairs(CustomCode.Instances) do
                if inst.elem == elem and inst.Compile then inst.Compile() end
            end
        end
    end

    sb:AddHeader("Dimensions & Alignment")
    sb:AddSlider("widgetWidth", "Container Width", 30, 400, 1, 100, elem, Refresh)
    sb:AddSlider("widgetHeight", "Container Height", 10, 100, 1, 30, elem, Refresh)
    sb:AddDropdown("justifyH", "Text Alignment", { {text="Left", value="LEFT"}, {text="Center", value="CENTER"}, {text="Right", value="RIGHT"} }, "CENTER", elem, Refresh)

    sb:AddHeader("Typography")
    local fontItems = {}
    if Skin and Skin.Media and Skin.Media.Fonts then
        for k, _ in pairs(Skin.Media.Fonts) do table.insert(fontItems, {text=k, value=k}) end
    end
    if #fontItems == 0 then fontItems = {{text="Default", value="Fonts\\FRIZQT__.TTF"}} end

    sb:AddDropdown("font", "Font Style", fontItems, "Friz Quadrata", elem, Refresh)
    sb:AddSlider("fontSize", "Font Size", 8, 36, 1, 14, elem, Refresh)
    sb:AddDropdown("fontOutline", "Font Outline", { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick Outline", value="THICKOUTLINE"} }, "OUTLINE", elem, Refresh)
    sb:AddColor("color", "Text Color", {1, 1, 1, 1}, elem, Refresh)

    sb:Finish()

    -- --- MODERN CUSTOM KOD EDİTÖRÜ ENJEKSİYONU ---
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
        lbl:SetPoint("TOPLEFT", 20, bottomY)
        lbl:SetText("|cff00ccffLUA Code Editor:|r (MUST return a string/number)")
        
        local warn = f.content:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
        warn:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
        warn:SetText("WARNING: Do not paste untrusted code!")

        -- Kütüphanedeki (ForgeSkin) kendi ScrollFrame fonksiyonumuzu çağırıyoruz
        local sf, scrollChild = Skin:CreateScrollFrame(f.content, 560, 180)
        sf:SetPoint("TOPLEFT", 25, bottomY - 20)
        
        local bg = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", sf, "TOPLEFT", -5, 5)
        bg:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 20, -5) -- Scrollbar için sağda 20px pay bırakıldı
        if Skin then Skin:ApplyBackdrop(bg, 0.5, 0.9) end
        bg:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

        local eb = CreateFrame("EditBox", nil, scrollChild)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(530) -- İçeride metnin scrollbar'a değmemesi için biraz daraltıldı
        eb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, -5)
        eb:SetAutoFocus(false)
        eb:SetText(elem.code or "return \"Hello World\"")
        
        -- EditBox içindeki Fare Tekerleği olayını dışarıdaki ScrollFrame'e pasla
        eb:EnableMouseWheel(true)
        eb:SetScript("OnMouseWheel", function(self, delta)
            if sf:GetScript("OnMouseWheel") then
                sf:GetScript("OnMouseWheel")(sf, delta)
            end
        end)

        -- EditBox'ın içeriğe göre kendi ve ScrollChild yüksekliğini ayarlaması (Kaydırmanın çalışması için şart)
        local measure = scrollChild:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        measure:SetWidth(530)
        measure:SetWordWrap(true)
        measure:Hide()

        eb:SetScript("OnTextChanged", function(self, isUserInput)
            measure:SetText(self:GetText() or "")
            local textHeight = measure:GetStringHeight()
            local newHeight = math.max(180, textHeight + 20)
            
            self:SetHeight(newHeight)
            scrollChild:SetHeight(newHeight)
            
            if isUserInput then
                elem.code = self:GetText()
                for _, inst in ipairs(CustomCode.Instances) do
                    if inst.elem == elem and inst.Compile then inst.Compile() end
                end
            end
        end)
        
        -- İlk yükseklik hesaplamasını tetikle
        eb:GetScript("OnTextChanged")(eb, false)

        -- İmleç (Cursor) hareket ettiğinde görünmeyen yeri kaydırarak göster
        eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
            local current = sf:GetVerticalScroll()
            local sfHeight = sf:GetHeight()
            local cursorTop = math.abs(y)
            local cursorBottom = cursorTop + h
            if cursorTop < current then
                sf:SetVerticalScroll(cursorTop)
            elseif cursorBottom > current + sfHeight then
                sf:SetVerticalScroll(cursorBottom - sfHeight)
            end
        end)

        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        
        -- KATEGORİLİ SNIPPET DROPDOWN MENÜSÜ
        local sY = bottomY - 215
        local sLbl = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", 20, sY)
        sLbl:SetText("Quick Snippets (Replaces current code):")

        local snippetList = {
            {text = "Select a snippet...", value = "NONE"},
            {text = "--- Player Info ---", value = "NONE"},
            {text = "Health %", value = "local c = UnitHealth('player')\nlocal m = UnitHealthMax('player')\nif m == 0 then return '0%' end\nreturn string.format('HP: %.1f%%', (c/m)*100)"},
            {text = "Class & Level", value = "local lvl = UnitLevel('player')\nlocal cls = UnitClass('player')\nreturn string.format('Lvl %d %s', lvl, cls)"},
            {text = "Current Speed", value = "local speed = GetUnitSpeed('player')\nreturn string.format('Speed: %.0f%%', (speed/7)*100)"},
            {text = "--- Target Info ---", value = "NONE"},
            {text = "Target Name", value = "local n = UnitName('target')\nreturn n and ('Target: '..n) or 'No Target'"},
            {text = "Target HP %", value = "local c = UnitHealth('target')\nlocal m = UnitHealthMax('target')\nif m == 0 then return '' end\nreturn string.format('%.1f%%', (c/m)*100)"},
            {text = "--- Utility ---", value = "NONE"},
            {text = "Current Zone", value = "return GetMinimapZoneText() or 'Unknown'"},
            {text = "Gold Count", value = "return GetCoinTextureString(GetMoney())"},
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
        ddSnippets:SetPoint("TOPLEFT", 20, sY - 15)

        if f.content.SetHeight then 
            f.content:SetHeight(math.abs(sY - 60)) 
        end
    end
end