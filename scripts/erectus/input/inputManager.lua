--- Handler for key-presses and mouse input
-- @author SirLich

-- Module setup
local inputManager = {}

-- Requires
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"

--- Initializes the input manager so it can start receiving and sending input events.
function inputManager:init()
	eventManager:addEventListenter(inputManager.keyChanged, eventManager.keyChangedListeners)
end


function inputManager:keyChanged(isDown, mapIndexes, isRepeat)
	mj:log(mapIndexes)
	mj:log("Key changed: " .. tostring(isDown) .. " " .. tostring(mapIndexes) .. " " .. tostring(isRepeat))
end

--- Add a key map to the input manager.
-- TODO: I probably don't need to mirror this, but it could be useful if Dave changes the signature.
function inputManager:addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
	keyMapping:addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
end

-- TODO: Eventually mods should be able to recieve ALL input events.
-- A mod can call this function to add itself to the list of mods that recieve input events (Function: onKeyPress or something)
function inputManager:recieveInputEvents(module)
	
end

return inputManager