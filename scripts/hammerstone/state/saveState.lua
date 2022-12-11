--- Hammerstone: saveState.lua
--- The saveState is a wrapper around all Sapiens save dbs. It also has methods for doing cross-thread saving.
--- For example, saving a client-world setting via the server.
-- @author SirLich

local saveState = {
	--- @thread any
	threadName = nil,

	--- @thread client
	clientState = nil,

	--- @thread server
	serverWorld = nil,

	--- @thread logic
	logicThreadPrivateShared = nil
}

-- Base
local server = mjrequire "server/server"

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"

---------------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------------

function saveState:initializeClientThread(clientState)
	--- @thread client
	--- @param clientState string
	saveState.threadName = "client"
	saveState.clientState = clientState
end

function saveState:initializeServerThread(serverWorld)
	--- @thread server
	--- @param serverWorld module
	saveState.threadName = 'server'
	saveState.serverWorld = serverWorld
end

function saveState:initializeLogicThread(clientGOM)
	--- @thread logic
	--- @param clientGOM module
	saveState.threadName = 'logic'
	saveState.clientGOM = clientGOM
end

---------------------------------------------------------------------------------
-- Accessors
---------------------------------------------------------------------------------

function saveState:getClientStateServer(clientID)
--- Returns the clientState associated with this clientID
--- @thread server
--- @param clientID string
--- @return cientState

	if saveState.serverWorld then
		return saveState.serverWorld:getClientStates()[clientID]
	end

	return nil
end

function saveState:resolveClientID(paramTable)
	--- Converts the 'tribeID' field in param table into 'clientID', if possible (in-place).
	--- @thread server
	--- @param paramTable table - The table, potentially containing tribeID and clientID
	--- @return none

	if paramTable and paramTable.tribeID and saveState.serverWorld then
		paramTable.clientID = saveState.serverWorld:clientIDForTribeID(paramTable.tribeID)
	end
end

function saveState:getPrivateShared(paramTable)
	--- Returns privateShared, if possible. Implementation depends on the calling thread
	--- @thread any

	-- Fetch from the client, if possible
	if saveState.clientState then
		return saveState.clientState.privateShared
	end

	-- Resolve client ID
	local clientID = paramTable.clientID
	if clientID == nil and saveState.serverWorld then
		clientID = saveState.serverWorld:clientIDForTribeID(paramTable.tribeID)
	end

	-- Fetch from server, if possible
	local clientState = saveState:getClientStateServer(clientID)
	if clientState then
		server:callClientFunction(
			"setPrivateShared",
			clientID,
			clientState.privateShared
		)

		return clientState.privateShared
	end
	
	-- No private shared to be found, so you're either calling from logicThread, or simply too early.
	-- This may still be nil, but it's the best we can do.
	return saveState.logicThreadPrivateShared
end

---------------------------------------------------------------------------------
-- Get/Set Values using PrivateShared
---------------------------------------------------------------------------------

function saveState:setValue(key, value, paramTable)
	--- Sets a value on privateShared.
	--- @thread any
	--- @param key string - The 'key' that you want to set in privateShared
	--- @param value any - The 'value' that you want to set in privateShared
	--- @param paramTable.clientID string - Client identifier which the server thread uses to find privateShared
	--- @param paramTable.tribeID string - Optional replacement for clientID

	if not paramTable then
		paramTable = {}
	end
	saveState:resolveClientID(paramTable)

	local privateShared = saveState:getPrivateShared(paramTable)

	-- If calling on the client, make a call to the server
	if saveState.threadName == 'client' then
		local logicInterface = mjrequire "mainThread/logicInterface"
		logicInterface:callServerFunction(
			"setValueFromClient",
			{
				key = key,
				value = value
			}
		)
	end

	-- If calling on the logic, make sure the server gets refreshed
	if saveState.threadName == 'logic' then
		local logic = mjrequire "logicThread/logic"
		logic:callServerFunction(
			"setValueFromClient",
			{
				key = key,
				value = value
			}
		)
	end

	-- If calling on the server, make sure logic gets refreshed
	if saveState.threadName == 'server' then
		server:callClientFunction(
			"setPrivateShared",
			paramTable.clientID,
			privateShared
		)
	end

	if privateShared then
		privateShared[key] = value
	else
		-- TODO: Write better error here, maybe using string formatting
		mj:warn("saveState:setValue failed. Was it called too early? ")
	end

	-- mj:log("saveState:setValue, ", key, ", ", value, ", ", saveState.threadName)

end

function saveState:getValue(key, paramTable)
	--- Get a value from privateShared.
	--- @thread any
	--- @param key String - The 'key' you want to retrieve, e.g, "vt.allowedPlansPerFollower".
	--- @param paramTable.default Any - The default value you want to return, if the value cannot be retrieved.
	--- @param paramTable.clientID String - Required for getting values on the server thread
	--- @param paramTable.tribeID String - May be used instead of the client ID if desired

	if not paramTable then
		paramTable = {}
	end

	saveState:resolveClientID(paramTable)

	local returnValue = nil

	local privateShared = saveState:getPrivateShared(paramTable)
	if privateShared then
		returnValue = privateShared[key]
	end

	if returnValue == nil and paramTable then
		returnValue = paramTable.default
	end

	-- mj:log("saveState:getValue: ", key, ", returning: ", returnValue)

	-- This could still be nil!
	return returnValue
end

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

flipflipflip = 12

function saveState:setValueClient(key, value)
	--- Set a value in the clients privateShared state. May only be called from the client.
	--- @param key string The 'key' you want to set, e.g. "vt.allowedPlansPerFollower".
	--- @param value any The value to set.


	if saveState.clientState then
		local paramTable = {
			key = key,
			value = value
		}

		local logicInterface = mjrequire "mainThread/logicInterface"
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

	-- Try from Server
	local clientState = saveState:getClientStateServer(clientID)

	local ret = nil

	local logic = mjrequire "logicThread/logic"
	if clientState then
		ret = clientState.privateShared[key]
	elseif logic.bridge then
		ret = logic:callMainThreadFunction(
			"getValueFromLogic",
			key
		)
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

	local clientState = saveState:getClientStateServer(clientID)

	-- This part is just responsible for attempting to keep the logic thread somewhat fresh
	server:callClientFunction(
		"setPrivateShared",
		clientID,
		saveState:getPrivateShared({
			clientID = clientID
		})
	)

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

