--- Hammerstone: actionSequence.lua

local mod = {
	loadOrder = 0
}

function mod:onload(actionSequence)
	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("actionSequence", actionSequence)
end

return mod