--- Hammerstone: storage.lua.
--- @Author SirLich

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local storage = {}

function storage:preload(base)
	moduleManager:addModule("storage", base)
end

--- Allows adding a storage.
--- @param key: The key to add, such as 'cake'
--- @param objectType: The object to add, containing all fields.
function storage:addStorage(key, objectType)
	if self.types[key] then
		log:warn("overwriting storage type:", key)
		log:warn(debug.traceback())
	end

	typeMaps:insert("storage", self.types, objectType)

	return objectType.index
end

return shadow:shadow(storage, 0)
