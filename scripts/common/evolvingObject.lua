--- Shadow of evolvingObject.lua.
-- @Author SirLich

local mod = {
	-- A low load-order makes the most since, as we need these methods to be available
	-- for other shadows.
	loadOrder = 0
}

-- Base
local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"

function mod:onload(evolvingObject)
	function evolvingObject:addEvolvingObject(key, objectType)
		--- Allows adding a evolvingObject.
		-- @param key: The key to add, which must correspond to a gameObject key, such as 'palmFrond'.
		-- @param objectType: The object to add, containing all fields.

		local index = typeMaps:keyToIndex(key, gameObject.validTypes)

		if not index then
			mj:error("Attempting to add evolving object which isn't a GameObject:", key)
		else
			evolvingObject.evolutions[index] = objectType
		end

		return index
	end
end

return mod
