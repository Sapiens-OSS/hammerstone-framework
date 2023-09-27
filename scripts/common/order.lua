--- Hammerstone: order.lua
--- @author Witchy

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(order)
	moduleManager:addModule("order", order)
end

return mod