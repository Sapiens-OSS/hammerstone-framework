--- Hammerstone: server.lua
--- @author SirLich

local mod = {
	loadOrder = 1,

	-- Exposed to Hammerstone
	bridge = nil,
	serverWorld = nil,
	server = nil
}

-- Hammerstone
local logger = mjrequire "hammerstone/logging"
local function setValueFromClient(clientID, paramTable)
	--- Intended for propogating a value from the client thread, to the server (which is authorative)
	--- @param clientID string - The client identifier which called this net function
	--- @param paramTable.key string - The 'key' you want to set
	--- @param paramTable.value any - The 'value' you want to set

	local saveState = mjrequire "hammerstone/state/saveState"
	saveState:setValue(paramTable.key, paramTable.value, {clientID = clientID})
end


local function initHammerstoneServer()
	logger:log("Initializing Hammerstone Server.")

	-- Register net function for cheats (move elsewhere eventually?)
	mod.server:registerNetFunction("setValueFromClient", setValueFromClient)
end


function mod:onload(server)
	logger:log("server.lua loaded.")
	mod.server = server

	local super_setBridge = server.setBridge
	server.setBridge = function(self, bridge)
		super_setBridge(self, bridge)
		mod.bridge = bridge
		logger:log("Server bridge set.")
	end

	local super_setServerWorld = server.setServerWorld
	server.setServerWorld = function(self, serverWorld)
		super_setServerWorld(self, serverWorld)
		mod.serverWorld = serverWorld

		local saveState = mjrequire "hammerstone/state/saveState"
		saveState:initializeServerThread(serverWorld)

		-- Now that the bridge is set, we can init
		initHammerstoneServer()
	end
end

return mod