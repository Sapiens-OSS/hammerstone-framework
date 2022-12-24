--- Hammerstone: craftable.lua
-- @author SirLich

local mod = {
    -- A low low order makes sense, since we want to make these methods available to other mods.
    loadOrder = 0
}

function mod:onload(craftable)

    local super_load = craftable.load
    craftable.load = function(craftable_, gameObject, flora)
        super_load(craftable_, gameObject, flora)

        local objectManager = mjrequire "hammerstone/object/objectManager"
        objectManager:generateRecipeDefinitions({
            craftable = craftable
        })
    end
end

return mod