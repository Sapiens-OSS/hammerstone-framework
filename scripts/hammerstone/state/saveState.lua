--- Hammerstone: saveState.lua
--- The saveState is a wrapper around all Sapiens save dbs. It also has methods for doing cross-thread saving.
--- For example, saving a client-world setting via the server.
-- @author SirLich

local saveState = {
	clientState = nil,
	serverWorld = nil
}

-- Base
local server = mjrequire "server/server"
local logicInterface = mjrequire "mainThread/logicInterface"

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"


---------------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------------

function saveState:setClientState(clientState)
	--- Only called on the client.
	--- @param clientState string
	saveState.clientState = clientState
end

function saveState:setServerWorld(serverWorld)
	--- Only called on the server.
	saveState.serverWorld = serverWorld
end

function saveState:getClientStateFromServer(clientID)
	return saveState.serverWorld:getClientStates()[clientID]
end

---------------------------------------------------------------------------------
-- Private Shared Settings
---------------------------------------------------------------------------------

function saveState:getValueClient(key, defaultOrNil)
	--- Get a value from the clients privateShared state.
	--- @param key string The 'key' you want to retrieve, e.g. "vt.allowedPlansPerFollower".
	--- @param defaultOrNil any (optional) The default value to return if the key is not found.

	local ret = nil
	if saveState.clientState then
		ret =  saveState.clientState.privateShared[key]
	else
		mj:error("saveState:getValue: clientState is nil")
	end

	if ret == nil then
		ret = defaultOrNil
	end

	return ret
end


function saveState:setValueClient(key, value)
	--- Set a value in the clients privateShared state. May only be called from the client.
	--- @param key string The 'key' you want to set, e.g. "vt.allowedPlansPerFollower".
	--- @param value any The value to set.


	if saveState.clientState then
		local paramTable = {
			key = key,
			value = value
		}

		return logicInterface:callServerFunction(
			"setValueClient",
			paramTable
		)
	else
		mj:error("saveState:setValueClient: clientState is nil")
	end
end

function saveState:getValueServer(key, clientID, defaultOrNil)
	--- Get a value from the server's privateShared state.
	--- May only be called from the server.
	--- @param key string The 'key' you want to retrieve, e.g. "vt.allowedPlansPerFollower".
	--- @param clientID number The clientID of the client you want to get the value from.
	--- @param defaultOrNil any (optional) The default value to return if the key is not found.

	local clientState = saveState:getClientStateFromServer(clientID)
	
	local ret = nil

	if clientState then
		ret = clientState.privateShared[key]
	else
		mj:error("saveState:getValueServer: clientState is nil")
	end

	if ret == nil then
		ret = defaultOrNil
	end

	return ret
end

function saveState:setValueServer(key, value, clientID)
	--- Set a value in the server's privateShared state. May only be called from the server.
	--- @param key string The 'key' you want to set, e.g. "vt.allowedPlansPerFollower".
	--- @param value any The value to set.
	--- @param clientID number The clientID of the client you want to set the value for.

	local clientState = saveState:getClientStateFromServer(clientID)

	if clientState then
		clientState.privateShared[key] = value
	else
		mj:error("saveState:setValueServer: clientState is nil")
	end
end

---------------------------------------------------------------------------------
-- World settings
---------------------------------------------------------------------------------

function saveState:getWorldValue(key, --[[optional]] default)
	--- Gets a key value pair from the world save file.
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


-- TODO: Consider adding 'default' as a param. Will need to use a table for the RPC.
function saveState:getWorldValueFromServer(clientID, key)
	--- Gets a key value pair from the world save file. May only be called from the server.
	-- @param clientID: The client ID for the world settings you are accessing.
	-- @param key: The key for the value.

	mj:log("getWorldValueFromServer called ", clientID, key)
	return server:callClientFunction(
		"getWorldValueFromServer",
		clientID,
		key
	)
end

function saveState:setWorldValue(key, value)
	--- Saves a value into the save file, which can be retrieved via a key.
	-- @param the key to set
	-- @param the value to set

	-- Temporary
	if not gameState or not gameState.world then return end

	gameState.world:getClientWorldSettingsDatabase():setDataForKey(value, key) -- Yes, value comes first. Don't question it.
end


return saveState

