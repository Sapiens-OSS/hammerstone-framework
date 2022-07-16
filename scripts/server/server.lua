--- Hammerstone shadow: server.lua
--- @author SirLich

local mod = {
	loadOrder = 1,

	-- Local state
	bridge = nil,
	serverWorld = nil,
	server = nil
}

-- Hammerstone
local logger = mjrequire "hammerstone/logging"

local function setValueClient(clientID, paramTable)
	--- Sets a value on private shared.
	--- @param clientID number
	--- @param paramTable table: {key = string, value = any, clientID = number}

	local saveState = mjrequire "hammerstone/state/saveState"
	saveState:setValueServer(paramTable.key, paramTable.value, clientID)
end


local function initHammerstoneServer()
	logger:log("Initializing Hammerstone Server.")

	-- Register net function for cheats (move elsewhere eventually?)
	mod.server:registerNetFunction("setValueClient", setValueClient)
end


function mod:onload(server)
	logger:log("server.lua loaded.")
	mod.server = server
	
	-- Shadow setBridge
	local super_setBridge = server.setBridge
	server.setBridge = function(self, bridge)
		super_setBridge(self, bridge)
		mod.bridge = bridge
		logger:log("Server bridge set.")
	end

	-- Shadow setServerWorld
	local super_setServerWorld = server.setServerWorld
	server.setServerWorld = function(self, serverWorld)
		super_setServerWorld(self, serverWorld)
		mod.serverWorld = serverWorld

		local saveState = mjrequire "hammerstone/state/saveState"
		saveState:setServerWorld(serverWorld)

		-- Now that the brigd is set, we can init
		initHammerstoneServer()
	end
end

return mod