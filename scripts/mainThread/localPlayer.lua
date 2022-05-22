--- Shadow file
-- @author SirLich

-- Module setup
local mod = {
	loadOrder = 0, -- Load before everything else
}

-- Requires
-- local eventManager = mjrequire "hammerstone/event/eventManager"
local hammerstone = mjrequire "hammerstone/hammerstone"

-- Shadow the localPlayer.lua table
function mod:onload(localPlayer)
	local superInit = localPlayer.init
	localPlayer.init = function(self, world, gameUI)
		superInit(self, world, gameUI)
		hammerstone:OnWorldLoaded(world)
	end
end


-- Module return
return mod