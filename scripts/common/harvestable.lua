--- Hammerstone: harvestable.lua

local harvestable = {}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/object/objectManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function harvestable:preload(parent)
	moduleManager:addModule("harvestable", parent)
end

--- @shadow
function harvestable:load(super, gameObject)
	super(self, gameObject)
	objectManager:markObjectAsReadyToLoad("harvestable")
end


--- @expose new simpler harvestable function. This one doesn't have any fancy processing; It just allows you to drop some items.
--- @param key the name of the harvestable
--- @param objectTypesArray the types to drop.
--- @param completionIndex Int representing WHEN you want to finish the harvest, and drop the remaining item.
function harvestable:addHarvestableSimple(key, objectTypesArray, completionIndex)
	local additionInfo = {
		key = key,
		objectTypesArray = objectTypesArray,
		completionIndex = completionIndex
	}

	typeMaps:insert("harvestable", self.types, additionInfo)
end


return shadow:shadow(harvestable)