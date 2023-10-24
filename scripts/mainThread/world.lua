--- Hammerstone: world.lua
--- @author SirLich

-- Hammerstone
local gameState = mjrequire "hammerstone/state/gameState"
local shadow = mjrequire "hammerstone/utils/shadow"
local modOptionsManager = mjrequire "hammerstone/options/modOptionsManager"

local world = {}

function world:setBridge(super, bridge, serverClientState, isVR)
	super(self, bridge, serverClientState, isVR)
	gameState.worldBridge = bridge
	modOptionsManager:setWorld(self)
end

return shadow:shadow(world)