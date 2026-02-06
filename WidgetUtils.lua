-- =========================================================================
--  WidgetForge UTILITIES
--  Shared utility functions for serialization, validation, and helpers
-- =========================================================================

WidgetForgeUtils = {}

-- =========================================================================
--  SERIALIZATION
-- =========================================================================

-- Serialize a table to a string representation
function WidgetForgeUtils:Serialize(t)
    return ForgeSerializer:Serialize(t)
end

-- Deserialize a string to a table
function WidgetForgeUtils:Deserialize(s)
    local result, err = ForgeSerializer:Deserialize(s)
    if not result then
        WIDGETFORGE_DEBUG("Deserialization Error:", err)
        return nil
    end
    return result
end

-- =========================================================================
--  VALIDATION
-- =========================================================================

-- Validate color table
function WidgetForgeUtils:ValidateColor(color)
    if type(color) ~= "table" then return {1, 1, 1, 1} end
    
    return {
        math.max(0, math.min(1, color[1] or 1)),
        math.max(0, math.min(1, color[2] or 1)),
        math.max(0, math.min(1, color[3] or 1)),
        math.max(0, math.min(1, color[4] or 1))
    }
end

-- Validate bar configuration
function WidgetForgeUtils:ValidateBarConfig(bar)
    if not bar then return false end
    
    bar.name = bar.name or "Unnamed Bar"
    bar.width = math.max(50, math.min(1000, bar.width or 250))
    bar.height = math.max(10, math.min(500, bar.height or 30))
    bar.padding = math.max(0, math.min(100, bar.padding or 10))
    bar.bgColor = self:ValidateColor(bar.bgColor)
    bar.borderColor = self:ValidateColor(bar.borderColor)
    bar.elements = bar.elements or {}
    
    -- Validate elements
    for _, elem in ipairs(bar.elements) do
        elem.color = self:ValidateColor(elem.color)
        elem.size = math.max(8, math.min(50, elem.size or 14))
    end
    
    return true
end

-- =========================================================================
--  HELPERS
-- =========================================================================

-- Deep copy a table
function WidgetForgeUtils:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:DeepCopy(orig_key)] = self:DeepCopy(orig_value)
        end
        setmetatable(copy, self:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    
    return copy
end

-- Format number with K/M suffix
function WidgetForgeUtils:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

-- Safe string truncation
function WidgetForgeUtils:TruncateString(str, maxLen)
    if not str then return "" end
    if string.len(str) <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

-- Get player identifier
function WidgetForgeUtils:GetPlayerID()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Get current spec ID
function WidgetForgeUtils:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex)
    end
    return nil
end

-- =========================================================================
--  DATABASE MIGRATION
-- =========================================================================

function WidgetForgeUtils:MigrateDatabase(db)
    if not db then return end
    
    -- Version check
    if not db.version then
        db.version = WIDGETFORGE_CONSTANTS.VERSION
    end
    
    -- Ensure bars exist
    if not db.bars then
        db.bars = {}
    end
    
    -- Ensure presets exist
    if not db.presets then
        db.presets = {}
    end
    
    -- Sanitize all bars
    for _, bar in pairs(db.bars) do
        self:ValidateBarConfig(bar)
        
        -- Migrate old element types
        if bar.elements then
            for _, elem in pairs(bar.elements) do
                if elem.type == "BagSpace" then elem.type = "Bag Space" end
                if elem.type == "ItemLevel" then elem.type = "Item Level" end
                if elem.type == "CombatTimer" then elem.type = "Combat Timer" end
            end
        end
    end
    
    WIDGETFORGE_DEBUG("Database migrated to version", db.version)
end

