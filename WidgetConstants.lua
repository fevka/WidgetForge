WIDGETFORGE_CONSTANTS = {
    UPDATE_INTERVAL = 0.5,          
    MAX_BARS = 50,                  
    DEFAULT_FONT_SIZE = 14,
    DEFAULT_OUTLINE = "OUTLINE",
    DEFAULT_PADDING = 10,
    DEFAULT_BAR_WIDTH = 250,
    DEFAULT_BAR_HEIGHT = 30,
    DROPDOWN_MAX_HEIGHT = 200,
    DROPDOWN_ITEM_HEIGHT = 20,
    SCROLL_WHEEL_SPEED = 20,
    VERSION = "1.1.4",
    TOUR_VERSION = 1,
    DEBUG_MODE = false 
}
WIDGETFORGE_CUSTOM_FONTS = WIDGETFORGE_CUSTOM_FONTS or {}
WIDGETFORGE_SPECS = {
    [250] = "Strength", [251] = "Strength", [252] = "Strength",
    [577] = "Agility", [581] = "Agility", [1480] = "Agility",
    [102] = "Intellect", [103] = "Agility", [104] = "Agility", [105] = "Intellect",
    [1467] = "Intellect", [1468] = "Intellect", [1473] = "Intellect",
    [253] = "Agility", [254] = "Agility", [255] = "Agility",
    [62] = "Intellect", [63] = "Intellect", [64] = "Intellect",
    [268] = "Agility", [269] = "Agility", [270] = "Intellect",
    [65] = "Intellect", [66] = "Strength", [70] = "Strength",
    [256] = "Intellect", [257] = "Intellect", [258] = "Intellect",
    [259] = "Agility", [260] = "Agility", [261] = "Agility",
    [262] = "Intellect", [263] = "Agility", [264] = "Intellect",
    [265] = "Intellect", [266] = "Intellect", [267] = "Intellect",
    [71] = "Strength", [72] = "Strength", [73] = "Strength"
}
WIDGETFORGE_CLASS_DEFAULTS = {
    WARRIOR = "Strength", PALADIN = "Strength", DEATHKNIGHT = "Strength",
    HUNTER = "Agility", ROGUE = "Agility", MONK = "Agility", DEMONHUNTER = "Agility",
    MAGE = "Intellect", WARLOCK = "Intellect", PRIEST = "Intellect", EVOKER = "Intellect",
    SHAMAN = "Agility", DRUID = "Intellect"
}
function WIDGETFORGE_DEBUG(...)
    if WIDGETFORGE_CONSTANTS.DEBUG_MODE then
        print("|cff00ccff[WidgetForge Debug]|r", ...)
    end
end
