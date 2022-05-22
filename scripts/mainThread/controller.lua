--- Overridden controller file, used for hooking up lifecycle events to the Hammerstone Mod Loader.
-- All events will be fired in the main thread, using the eventManager
-- @author SirLich

local eventManager = mjrequire "hammerstone/event/eventManager"
local eventTypes = mjrequire "hammerstone/event/eventTypes"
local logger = mjrequire "hammerstone/logging"
local inputManager = mjrequire "hammerstone/input/inputManager"
local hammerstone = mjrequire "hammerstone/hammerstone"

local mod = {
	loadOrder = 0, -- Load before everything else
}

function mod:onload(controller)

	logger:log("Loading Hammerstone Mod Framework...")

	-- Setup other Hammerstone Mod Framework stuff
	inputManager:init()

	-- Fire off events
	eventManager:call(eventTypes.init)
end

return mod