--- EventManager for hammerstone mods.
-- You can bind to the events here and react to them.
-- @author SirLich

-- Event manager
local eventManager = {
	events = {}
}

local logger = mjrequire "hammerstone/logging"

--- Calls the event with the given name and passes the given arguments.
function eventManager:call(event, ...)
	logger:log("Calling event " .. event)

	if self.events[event] then
		for i, f in pairs(self.events[event]) do
			logger:log("Calling event " .. event .. " with " .. #{...})
			local status, err = pcall(f, ...)
			if not status then
				if string.find(err, "attempt to index local 'gameObject'") then
					logger:log("Warning: nil gameObject encountered in event " .. event)
				else
					logger:log("Error in event " .. event .. ": " .. err)
				end
			end
		end
	end
end

--- Binds a function to the event with the given name.
function eventManager:bind(event, callback)
	-- Ensure the event is in the table
	if not eventManager.events[event] then
		eventManager.events[event] = {}
	end

	-- Add binding into the event table
	table.insert(eventManager.events[event], callback)
	logger:log("Bound event " .. tostring(event) .. " to callback " .. tostring(callback))
end


return eventManager
