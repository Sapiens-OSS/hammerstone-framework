--- Hammerstone: storage.lua.
--- @Author SirLich

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local log = mjrequire "hammerstone/logging"

function mod:onload(storage)
	--- Allows adding a storage.
	--- @param key: The key to add, such as 'cake'
	--- @param objectType: The object to add, containing all fields.
	function storage:addStorage(key, objectType)
		local typeIndexMap = typeMaps.types.storage -- Created automatically in storage.lua

		local index = typeIndexMap[key]
		if not index then
			log:error("attempt to add storage type that isn't in typeIndexMap:", key)
		else
			if storage.types[key] then
				log:warn("overwriting storage type:", key)
				log:warn(debug.traceback())
			end
	
			objectType.key = key
			objectType.index = index
			storage.types[key] = objectType
			storage.types[index] = objectType

		end
		return index
	end

-- TODO: Ordering is wrong
	-- objectManager:generateStorageObjects(storage)
end

return mod
