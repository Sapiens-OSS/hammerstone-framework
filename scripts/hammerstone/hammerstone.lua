--- Entrypoint script for the Hammerstone Framework
-- @author SirLich

-- Module setup
local hammerstone = {
	world = nil,
}

-- Requires
local logger = mjrequire "hammerstone/logging"

function hammerstone:OnWorldLoaded(world)
	logger:log("World Loaded with Tribe ID " .. world:getTribeID())
	hammerstone.world = world
end

-- Module return
return hammerstone