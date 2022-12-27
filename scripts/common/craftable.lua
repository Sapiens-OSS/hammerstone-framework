--- Hammerstone: craftable.lua
-- @author SirLich

local mod = {
    -- A low low order makes sense, since we want to make these methods available to other mods.
    loadOrder = 0
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(craftable)
    local super_load = craftable.load
    craftable.load = function(craftable_, gameObject, flora)
        super_load(craftable_, gameObject, flora)
        objectManager:markObjectAsReadyToLoad("recipe")
    end

    moduleManager:addModule("craftable", craftable)
end

return mod