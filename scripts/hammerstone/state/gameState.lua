--- Entrypoint script for the Hammerstone Framework
-- @author SirLich

-- Module setup
local gameState = {
	-- The current loaded world
	world = nil,

	-- The C bridge for the world
	worldBridge = nil,
}

-- Requires
local logger = mjrequire "hammerstone/logging"

function gameState:OnWorldLoaded(world)
	gameState.world = world
end

-- Module return
return gameState