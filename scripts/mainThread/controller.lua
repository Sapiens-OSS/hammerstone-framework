--- Overridden controller file, used for hooking up lifecycle events to the Erectus Mod Loader.
-- All events will be fired in the main thread, using the eventManager
-- @author SirLich

local eventManager = mjrequire "erectus/event/eventManager"
local eventTypes = mjrequire "erectus/event/eventTypes"
local logger = mjrequire "erectus/logging"

local mod = {
	loadOrder = 0, -- Load before everything else
}

function mod:onload(controller)

	logger:log("Loading Erectus Mod Framework...")

	-- Fire off events
	eventManager:call(eventTypes.init)

	-- Save super
	local superWorldLoaded = controller.worldLoaded
	controller.worldLoaded = function(self, world)
		superWorldLoaded(controller, world) -- Shouldn't this be superWorldLoaded(self, world)?
		
		-- logger:log("World loaded, triggering event") -- Don't need this due to another log message in the actual function
		eventManager:call(eventTypes.init)
	end

end

return mod