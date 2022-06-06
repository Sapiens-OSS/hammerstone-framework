--- Shadow of world.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"
local saveState = mjrequire "hammerstone/state/saveState"

function mod:onload(world)

	-- Shadow setBridge
	local superSetBridge = world.setBridge
	world.setBridge = function(self, bridge, serverClientState, isVR)
		superSetBridge(world, bridge, serverClientState, isVR)

		-- local clientWorldSettingsDatabase = bridge.clientWorldSettingsDatabase
		local clientWorldSettingsDatabase = "TEST STRING PARAM"
		mj:log("world set bridge.")
		mj:log(clientWorldSettingsDatabase)
		gameState.worldBridge = bridge
		-- saveState:init(clientWorldSettingsDatabase) -- TODO Consider moving this elsewhere
	end
end

return mod