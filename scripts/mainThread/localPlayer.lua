--- Hammerstone: localPlayer.lua
--- @author SirLich

local localPlayer = {
	loadOrder = 0, -- Load before everything else

	-- Exposed to Hammerstone
	bridge = nil,
	clientState = nil
}

-- Hammerstone 
local gameState = mjrequire "hammerstone/state/gameState"
local saveState = mjrequire "hammerstone/state/saveState"
local shadow = mjrequire "hammerstone/utils/shadow"
local modOptionsManager = mjrequire "hammerstone/options/modOptionsManager"

function localPlayer:init(super, world, gameUI)
	super(self, world, gameUI)
	gameState:OnWorldLoaded(world)
end

function localPlayer:setBridge(super, bridge, clientState)
	super(self, bridge, clientState)

	self.bridge = bridge
	self.clientState = clientState
	saveState:initializeClientThread(clientState)

	modOptionsManager:registerUI()
end


return shadow:shadow(localPlayer, 0)