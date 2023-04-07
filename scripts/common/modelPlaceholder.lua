--- Hammerstone: modelPlaceholder.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(modelPlaceholder)
	moduleManager:addModule("modelPlaceholder", modelPlaceholder)
end

return mod