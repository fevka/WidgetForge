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
    DEBUG_MODE = false
}

-- Helper function for debug logging
function WIDGETFORGE_DEBUG(...)
    if WIDGETFORGE_CONSTANTS.DEBUG_MODE then
        print("|cff00ccff[WidgetForge Debug]|r", ...)
    end
end

