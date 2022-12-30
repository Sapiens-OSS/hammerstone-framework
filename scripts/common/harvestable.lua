--- Hammerstone: harvestable.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/object/objectManager"

function mod:onload(harvestable)
	moduleManager:addModule("harvestable", harvestable)

	local super_load = harvestable.load
    harvestable.load = function(harvestable_, gameObject)
        super_load(harvestable_, gameObject)
		objectManager:markObjectAsReadyToLoad("harvestable")
    end


end

return mod