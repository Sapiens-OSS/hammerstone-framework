--- Overridden controller file, used for hooking up lifecycle events to the Erectus Mod Loader.
-- All events will be fired in the main thread, using the eventManager
-- @author SirLich

local eventManager = mjrequire "erectus/eventManager"
local eventTypes = mjrequire "erectus/eventTypes"

local mod = {
	loadOrder = 0,
}

function mod:onload(controller)

	-- Save super
	local superWorldLoaded = controller.worldLoaded

	-- Fire off events
	eventManager:call(eventTypes.init)

	controller.worldLoaded = function(self, world)
		superWorldLoaded(controller, world)
		
		mj:log("World loaded.")
		eventManager:call(eventTypes.init)

		-- eventManager.call(eventTypes.worldLoaded, world)
	end

end

return mod