--- Hammerstone: craftAreaGroup.lua

local mod = {
	loadOrder = 0
}

function mod:onload(craftAreaGroup)
	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("craftAreaGroup", craftAreaGroup)
end

return mod