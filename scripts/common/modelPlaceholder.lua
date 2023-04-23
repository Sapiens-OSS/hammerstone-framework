--- Hammerstone: modelPlaceholder.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(modelPlaceholder)
	local super_initRemaps = modelPlaceholder.initRemaps

    mod.modelPlaceholder = modelPlaceholder
    modelPlaceholder.initRemaps = function()
        super_initRemaps()
		moduleManager:addModule("modelPlaceholder", modelPlaceholder)
	end
end

return mod