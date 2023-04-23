--- Hammerstone: seat.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(seat)
	moduleManager:addModule("seat", seat)
end

return mod