--- Hammerstone: gameObject.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"

function mod:onload(gameObject)
	objectManager:init()

	-- TODO ordering is wrong :L
	-- objectManager:generateGameObjects(gameObject)
end


return mod
