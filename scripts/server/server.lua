--- Shadow function
-- @author SirLich


-- Module setup
local mod = {
	loadOrder = 1,

	-- Local state
	bridge = nil,
	serverWorld = nil,
	server = nil
}

-- Requires
local logger = mjrequire "hammerstone/logging"

-- Required because net-functions can only pass one argument
local function unlockSkill(clientID, paramTable)
	mod.serverWorld:completeDiscoveryForTribe(paramTable.tribeID, paramTable.skillTypeIndex)
end


local function initHammerstoneServer()
	logger:log("Initializing Hammerstone Server")

	-- serverWorld:completeDiscoveryForTribe(tribeID, skillTypeIndex)

	-- Register net function for cheats (move elsewhere eventually?)
	mod.server:registerNetFunction("unlockSkill", unlockSkill)
end

function mod:onload(server)
	logger:log("Server Loaded")
	mod.server = server
	
	-- Shadow setBridge
	local superSetBridge = server.setBridge
	server.setBridge = function(self, bridge)
		superSetBridge(self, bridge)
		mod.bridge = bridge

		logger:log("Server bridge set")
	end

	-- Shadow setServerWorld
	local superSetServerWorld = server.setServerWorld
	server.setServerWorld = function(self, serverWorld)
		superSetServerWorld(self, serverWorld)
		mod.serverWorld = serverWorld

		logger:log("Server world set")

		-- Now that the brigd is set, we can init
		initHammerstoneServer()
	end
end




-- Module return
return mod