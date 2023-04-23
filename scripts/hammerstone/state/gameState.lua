--- Hammerstone: gameState.lua
--- gameState is an experimental file which stores stateful information
--- about your world.
--- @author SirLich

local gameState = {
	-- The current loaded world
	world = nil,

	-- The C bridge for the world
	worldBridge = nil,

	-- The filePath for the world
	worldPath = nil
}

function gameState:OnWorldLoaded(world)
	gameState.world = world
end

return gameState