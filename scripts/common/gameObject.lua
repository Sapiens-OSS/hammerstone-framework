--- Hammerstone: gameObject.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"

function mod:onload(gameObject)

	local super_mjInit = gameObject.mjInit
	gameObject.mjInit = function()
		objectManager:init(gameObject)

		super_mjInit()
	end
end


return mod
