--- Hammerstone: gameObject.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(gameObject)

	local super_mjInit = gameObject.mjInit
	gameObject.mjInit = function(self)
		objectManager:markObjectAsReadyToLoad("gameObject")
		super_mjInit(self)
	end

	moduleManager:addModule("gameObject", gameObject)
end

return mod
