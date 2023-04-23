--- Hammerstone: harvestable.lua

local mod = {
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

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

	-- Expose new simpler harvestable function. This one doesn't have any fancy processing; It just allows you to drop some items.
	--- @param key the name of the harvestabl
	--- @param key objectTypesArray the types to drop.
	--- @param completionIndex: Int representing WHEN you want to finish the harvest, and drop the remaining item.
	function harvestable:addHarvestableSimple(key, objectTypesArray, completionIndex)
		local additionInfo = {
			key = key,
			objectTypesArray = objectTypesArray,
			completionIndex = completionIndex
		}

		typeMaps:insert("harvestable", harvestable.types, additionInfo)
	end
	
end

return mod