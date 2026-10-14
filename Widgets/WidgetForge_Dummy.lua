local addonName, addon = ...
addon.Dummy = {}
local Dummy = addon.Dummy
local L = WFL
function Dummy:Load(parent, config)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local Skin = _G.ForgeSkin
    f:SetSize(config.width or 100, config.height or 30)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER")
    f.text:SetText(config.text or L("TEXT_DUMMY_WIDGET"))
    f.data = config
    Dummy:UpdateVisuals(f, config)
    return f
end
function Dummy:UpdateVisuals(f, config)
    if not f then return end
    f:SetSize(config.width or 100, config.height or 30)
    f.text:SetText(config.text or L("TEXT_DUMMY_WIDGET"))
    if f.bg then
        local c = config.color or {0.5, 0.5, 0.5, 0.5}
        f.bg:SetColorTexture(unpack(c))
    end
end
