--- Hammerstone: tool.lua

local mod = {
	loadOrder = 0
}

function mod:onload(tool)
	local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("tool", tool)
end

return mod