--- Hammerstone: gameObject.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone

function mod:onload(gameObject)

	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("gameObject", gameObject)

	local super_mjInit = gameObject.mjInit
	gameObject.mjInit = function(self)

		local objectManager = mjrequire "hammerstone/object/objectManager"
		objectManager:generateGameObjects()
		
		super_mjInit(self)
	end
end


return mod
