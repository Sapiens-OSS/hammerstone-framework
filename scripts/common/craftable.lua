local mod = {
    loadOrder = 0
}

local constructable = mjrequire "common/constructable"

function mod:onload(craftable)

    function craftable:addCraftable(key, objectType)
        return constructable:addConstructable(key, objectType)
    end

end

return mod