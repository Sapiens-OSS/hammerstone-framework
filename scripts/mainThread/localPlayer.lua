--- Hammerstone: localPlayer.lua
--- @author SirLich

local mod = {
	loadOrder = 0, -- Load before everything else
}

-- Hammerstone 
local gameState = mjrequire "hammerstone/state/gameState"
local saveState = mjrequire "hammerstone/state/saveState"

function mod:onload(localPlayer)
	local super_init = localPlayer.init
	localPlayer.init = function(self, world, gameUI)
		super_init(self, world, gameUI)
		gameState:OnWorldLoaded(world)
	end

	local super_setBridge = localPlayer.setBridge
	localPlayer.setBridge = function(self, bridge, clientState)
		super_setBridge(localPlayer, bridge, clientState)
		saveState:setClientState(clientState)
	end
end

return mod