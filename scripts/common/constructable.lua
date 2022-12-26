--- Hammerstone: action.lua

local mod = {
	loadOrder = 0
}

function mod:onload(constructable)
	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("constructable", constructable)
end

return mod