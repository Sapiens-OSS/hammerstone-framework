--- The saveState is a wrapper around all Sapiens save dbs. It also has methods for doing cross-thread saving.
--- For example, saving a client-world setting via the server.
-- @author SirLich

local saveState = {
	world = nil
}

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"

function saveState:get(key, --[[optional]] default)
	--- Gets a key value pair from the save file.
	-- @param key: The key for the value.
	-- @param default (optional): The default value to return if the key is not found.

	-- Temporary
	if not gameState.world then return end

	local returnValue = gameState.world:getClientWorldSettingsDatabase():dataForKey(key)
	if returnValue == nil then
		-- TODO: What kind of exception can we raise if no default was supplied, and the key was not available?
		returnValue = default
	end

	return returnValue
end

function saveState:set(key, value)
	--- Saves a value into the save file, which can be retrieved via a key.
	-- @param the key to set
	-- @param the value to set

	-- Temporary
	if not gameState or not gameState.world then return end

	gameState.world:getClientWorldSettingsDatabase():setDataForKey(value, key) -- Yes, value comes first. Don't question it.
end

return saveState
