--- Hammerstone: craftAreaGroup.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(craftAreaGroup)
	moduleManager:addModule("craftAreaGroup", craftAreaGroup)
end

return mod