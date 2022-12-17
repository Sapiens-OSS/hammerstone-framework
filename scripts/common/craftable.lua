--- Hammerstone: craftable.lua
-- @author SirLich

local mod = {
    -- A low low order makes sense, since we want to make these methods available to other mods.
    loadOrder = 0
}

-- Sapiens
local constructable = mjrequire "common/constructable"

function mod:onload(craftable)
    --- Adds a craftable
    -- @param key - The key to add
    -- @param objectData - The objectData table.
    function craftable:addCraftable(key, objectData)
        return constructable:addConstructable(key, objectData)
    end

end

return mod