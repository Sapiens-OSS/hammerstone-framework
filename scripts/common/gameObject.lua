--- Hammerstone: gameObject.lua
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"

function mod:onload(gameObject)


	-- local super_mjInit = gameObject.mjInit
	-- gameObject.mjInit = function()
	-- 	mj:log("MJ INIT CALLED. WHY?")

	-- 	super_mjInit()
	-- end

	objectManager:init(gameObject)
	
	-- TODO ordering is wrong :L
	-- objectManager:generateGameObjects(gameObject)
end


return mod
