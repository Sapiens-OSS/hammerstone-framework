--- Handler for key-presses and mouse input
-- @author SirLich

-- Module setup
local inputManager = {}

-- Requires
local keyMapping = mjrequire "mainThread/keyMapping"
local eventManager = mjrequire "mainThread/eventManager"

local keyMap = {}

-- Key Dampening
-- The keyChanged event fires twice, once when you press and once when you release.
-- We only want to call the callback once, so we dampen the other press, using this table
local keyDampen = {}

-- Util function
local function tablefind(tab,el)
	for index, value in pairs(tab) do
		if value == el then
			return index
		end
	end
	return -1
end

--- Initializes the input manager so it can start receiving and sending input events.
function inputManager:init()
	eventManager:addEventListenter(inputManager.keyChanged, eventManager.keyChangedListeners)
end

-- This is fired when any key that has a mapping is fired, not just ours.
-- mapIndexes contains the pressed keys, which we need to check for one of our keyBinds
function inputManager:keyChanged(mapIndexes, isDown, isRepeat)
	for i,mapIndex in ipairs(mapIndexes) do
		if keyMap[mapIndex] then
			local index = tablefind(keyDampen, mapIndex)
			if index ~= -1 then
				mj:log("Dampened key event")
				table.remove(keyDampen, index)
			else
				mj:log("Didn't dampen key event")
				keyMap[mapIndex](isDown, isRepeat)
				table.insert(keyDampen, mapIndex)
				mj:log(keyDampen)
			end
		end
	end
	return false
end


--- Add a key map to the input manager.
-- TODO: I probably don't need to mirror this, but it could be useful if Dave changes the signature.
function inputManager:addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
	keyMapping.addMapping(groupKey, mapKey, defaultKeyCode, defaultMod, defaultMod2)
end

function inputManager:addGroup(groupKey)
	mj:log("Adding groupkey: " ..groupKey)
	keyMapping.addGroup(groupKey)
end

function inputManager:addKeyChangedCallback(groupKey, mapKey, callback)
	keyMap[keyMapping:getMappingIndex(groupKey, mapKey)] = callback
end

-- TODO: Eventually mods should be able to receive ALL input events.
-- A mod can call this function to add itself to the list of mods that receive input events (Function: onKeyPress or something)
function inputManager:recieveInputEvents(module)

end

return inputManager