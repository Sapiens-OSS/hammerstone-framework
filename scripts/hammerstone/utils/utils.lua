--- Hammerstone: utils.lua
--- utils exposes some recurring useful functions
--- @author nmattela

local typeMaps = mjrequire "common/typeMaps"

local utils = {}

function utils:resourceExists(resourceKey)
    --- Checks the resource type map if the resource exists.
    --- @param resourceKey: The name of the resource to check. E.g. "apple"

    local typeIndexMap = typeMaps.types.resources -- Created automatically in resource.lua

    local index = typeIndexMap[key]
    if not index then
        mj:error("Resource does not exist in typeIndexMap:", key)
    else
        return index
    end
end

return utils