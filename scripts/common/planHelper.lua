--- Hammerstone: planHelper.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(planHelper)
	moduleManager:addModule("planHelper", planHelper)

	
end

return mod