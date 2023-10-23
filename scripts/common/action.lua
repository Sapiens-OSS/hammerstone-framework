--- Hammerstone: action.lua

local mod = {
	loadOrder = 0
}

function mod:onload(action)
	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("action", action)
end

return mod