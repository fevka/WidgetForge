ForgeSerializer = {}
local function SerializeValue(v)
    local t = type(v)
    if t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "string" then
        return string.format("%q", v) 
    elseif t == "table" then
        return ForgeSerializer:Serialize(v)
    else
        return "nil"
    end
end
function ForgeSerializer:Serialize(tbl)
    local parts = {}
    table.insert(parts, "{")
    local first = true
    for k, v in pairs(tbl) do
        if not first then table.insert(parts, ",") end
        first = false
        if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
            table.insert(parts, k .. "=")
        else
            table.insert(parts, "[" .. SerializeValue(k) .. "]=")
        end
        table.insert(parts, SerializeValue(v))
    end
    table.insert(parts, "}")
    return table.concat(parts)
end
function ForgeSerializer:Deserialize(str)
    if not str or str == "" then return nil end
    local f, err = loadstring("return " .. str)
    if not f then 
        return nil, "Syntax Error: " .. (err or "Unknown")
    end
    local env = {} 
    setfenv(f, env)
    local success, result = pcall(f)
    if not success then
        return nil, "Execution Error: " .. (result or "Unknown")
    end
    return result
end
