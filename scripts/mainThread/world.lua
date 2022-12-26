--- Hammerstone: world.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"

function mod:onload(world)

	-- Shadow setBridge
	local super_setBridge = world.setBridge
	world.setBridge = function(_, bridge, serverClientState, isVR)
		super_setBridge(_, bridge, serverClientState, isVR)
		gameState.worldBridge = bridge
	end
end

return mod