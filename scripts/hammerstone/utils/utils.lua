--- Hammerstone: utils.lua
--- utils exposes some recurring useful functions
--- @author nmattela

local typeMaps = mjrequire "common/typeMaps"

local utils = {}

--- Checks the resource type map if the resource exists.
--- @param resourceKey: The name of the resource to check. E.g. "apple"
--- @deprecated We should probably move this into `resource.lua`?
function utils:resourceExists(resourceKey)
    local typeIndexMap = typeMaps.types.resources -- Created automatically in resource.lua

    local index = typeIndexMap[resourceKey]
    if not index then
        mj:error("Resource does not exist in typeIndexMap:", resourceKey)
    else
        return index
    end
end

return utils