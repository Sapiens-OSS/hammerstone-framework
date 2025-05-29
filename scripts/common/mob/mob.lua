local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(mob)
	moduleManager:addModule("mob", mob)
end

return mod