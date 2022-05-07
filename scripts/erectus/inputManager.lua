--- Handler for key-presses and mouse input
-- @author SirLich

-- Module setup
local inputManager = {}

-- Requires
local keyMapping = mjrequire "mainThread/keyMapping"

--- Add a key map to the input manager.
function inputManager:addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
	keyMapping:addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
end

return inputManager