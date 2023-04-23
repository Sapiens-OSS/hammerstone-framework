--- Hammerstone: plan.lua
--- @author SirLich

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(plan)
	moduleManager:addModule("plan", plan)
end

return mod