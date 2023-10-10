--- Hammerstone: gameObject.lua
--- @author SirLich

-- Hammerstone
local objectManager = mjrequire "hammerstone/ddapi/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local gameObject = {}

function gameObject:preload(base)
	moduleManager:addModule("gameObject", base)
end

function gameObject:addGameObjects(super)
	super(self)
	objectManager:markObjectAsReadyToLoad("gameObject")
end

return shadow:shadow(gameObject, 0)
