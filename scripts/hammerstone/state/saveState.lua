--- This file is a wrapper around Sapiens per-world settings.
-- @author: SirLich

-- Module setup
local saveState = {
	world = nil
}

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"

function saveState:get(key, --[[optional]] default)
	--- Saves a key-value pair to the save file.
	-- @param the key to get
	-- @param the default value to return if the key is not found

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
	if not gameState.world then return end

	gameState.world:getClientWorldSettingsDatabase():setDataForKey(value, key) -- Yes, value comes first. Don't question it.
end

-- Module return
return saveState
