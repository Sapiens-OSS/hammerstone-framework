--- Shadow of storage.lua.
-- @Author SirLich

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0
}

-- Base
local typeMaps = mjrequire "common/typeMaps"

function mod:onload(storage)
	function storage:addStorage(key, objectType)
		--- Allows adding a storage.
		-- @param key: The key to add, such as 'cake'
		-- @param objectType: The object to add, containing all fields.

		local typeIndexMap = typeMaps.types.storage -- Created automatically in storage.lua

		local index = typeIndexMap[key]
		if not index then
			mj:log("ERROR: attempt to add storage type that isn't in typeIndexMap:", key)
		else
			if storage.types[key] then
				mj:log("WARNING: overwriting storage type:", key)
				mj:log(debug.traceback())
			end
	
			objectType.key = key
			objectType.index = index
			storage.types[key] = objectType
			storage.types[index] = objectType

		end
		return index
	end
end

return mod
