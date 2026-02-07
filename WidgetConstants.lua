-- =========================================================================
--  WidgetForge CONSTANTS
--  Centralized configuration values for the addon
-- =========================================================================

WIDGETFORGE_CONSTANTS = {
    -- Performance
    UPDATE_INTERVAL = 0.5,          -- Stat update frequency (seconds)
    MAX_BARS = 50,                  -- Maximum number of bars allowed
    
    -- UI Defaults
    DEFAULT_FONT_SIZE = 14,
    DEFAULT_OUTLINE = "OUTLINE",
    DEFAULT_PADDING = 10,
    DEFAULT_BAR_WIDTH = 250,
    DEFAULT_BAR_HEIGHT = 30,
    
    -- Dropdown Limits
    DROPDOWN_MAX_HEIGHT = 200,
    DROPDOWN_ITEM_HEIGHT = 20,
    
    -- Scroll Settings
    SCROLL_WHEEL_SPEED = 20,
    
    -- Version
    VERSION = "1.0.0",
    
    -- Debug
    DEBUG_MODE = false -- Enable Debug Temporarily
}

-- Comprehensive Spec Data (ID -> Main Stat)
WIDGETFORGE_SPECS = {
    -- Death Knight (Str)
    [250] = "Strength", [251] = "Strength", [252] = "Strength",
    -- Demon Hunter (Agi)
    [577] = "Agility", [581] = "Agility",
    -- Druid (Bal/Resto=Int, Feral/Guard=Agi)
    [102] = "Intellect", [103] = "Agility", [104] = "Agility", [105] = "Intellect",
    -- Evoker (Int)
    [1467] = "Intellect", [1468] = "Intellect", [1473] = "Intellect",
    -- Hunter (Agi)
    [253] = "Agility", [254] = "Agility", [255] = "Agility",
    -- Mage (Int)
    [62] = "Intellect", [63] = "Intellect", [64] = "Intellect",
    -- Monk (Brew/Wind=Agi, Mist=Int)
    [268] = "Agility", [269] = "Agility", [270] = "Intellect",
    -- Paladin (Holy=Int, Prot/Ret=Str)
    [65] = "Intellect", [66] = "Strength", [70] = "Strength",
    -- Priest (Int)
    [256] = "Intellect", [257] = "Intellect", [258] = "Intellect",
    -- Rogue (Agi)
    [259] = "Agility", [260] = "Agility", [261] = "Agility",
    -- Shaman (Ele/Resto=Int, Enh=Agi)
    [262] = "Intellect", [263] = "Agility", [264] = "Intellect",
    -- Warlock (Int)
    [265] = "Intellect", [266] = "Intellect", [267] = "Intellect",
    -- Warrior (Str)
    [71] = "Strength", [72] = "Strength", [73] = "Strength"
}

-- Fallback for Low Level (No Spec)
WIDGETFORGE_CLASS_DEFAULTS = {
    WARRIOR = "Strength", PALADIN = "Strength", DEATHKNIGHT = "Strength",
    HUNTER = "Agility", ROGUE = "Agility", MONK = "Agility", DEMONHUNTER = "Agility",
    MAGE = "Intellect", WARLOCK = "Intellect", PRIEST = "Intellect", EVOKER = "Intellect",
    SHAMAN = "Agility", DRUID = "Intellect"
}

-- Helper function for debug logging
function WIDGETFORGE_DEBUG(...)
    if WIDGETFORGE_CONSTANTS.DEBUG_MODE then
        print("|cff00ccff[WidgetForge Debug]|r", ...)
    end
end

