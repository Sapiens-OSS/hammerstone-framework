--- Hammerstone: resource.lua.
--- Mostly used to extend the resource module with additional helpers.
--- @Author SirLich

local mod = {
	-- A low load-order makes the most since, as we need these methods to be available
	-- for other shadows.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

function mod:onload(resource)
	function resource:addResource(key, objectType)
		--- Allows adding a resource.
		--- @param key: The key to add, such as 'cake'
		--- @param objectType: The object to add, containing all fields.

		local typeIndexMap = typeMaps.types.resources -- Created automatically in resource.lua

		local index = typeIndexMap[key]
		if not index then
			mj:error("Attempt to add resource type that isn't in typeIndexMap:", key)
		else
			if resource.types[key] then
				mj:warning("Overwriting resource type:", key)
				mj:log(debug.traceback())
			end
	
			objectType.key = key
			objectType.index = index
			typeMaps:insert("resource", resource.types, objectType)

			-- Recache the type maps
			resource.validTypes = typeMaps:createValidTypesArray("resource", resource.types)
		end

		return index
	end
end

return mod
