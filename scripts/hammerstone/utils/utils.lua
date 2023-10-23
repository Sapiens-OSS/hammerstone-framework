--- Hammerstone: utils.lua
--- utils exposes some recurring useful functions
--- @author nmattela

local utils = {}

-- Returns the sorted keys of a table
-- @param inputTable The table to sort the keys of.
-- @param onlyType The only key type to consider for sorting.
function utils:sortedTableKeys(inputTable, onlyType)
    local sortedKeys = {}

    -- Extract and sort the keys
    for key, _ in pairs(inputTable) do
        if type(key) == onlyType then
            table.insert(sortedKeys, key)
        end
    end

    table.sort(sortedKeys)

    return sortedKeys
end

function utils:rstrip(s, suffix)
    return s:gsub(suffix.."$", "")
end

function utils:strip(s, prefix)
    return (s:sub(0, #prefix) == prefix) and s:sub(#prefix+1) or s
end

function utils:capsCase(s)
    return s:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
end

return utils
