--- Hammerstone: fuel.lua

local mod = {
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"
local resource = mjrequire "common/resource"
local locale = mjrequire "common/locale"

-- Hammerstone
local log = mjrequire "hammerstone/logger"

function mod:onload(fuel)

	--- Unfortunately, fuelGroup is not exposed to us from the vanilla code, so we have to copy/paste everything from the source code for it to become modifiable...

	--- Copied from vanilla fuel.lua from update b20.1
	--- We change this from the source code: change fuelGroup from a local variable to a property of the fuel object
	fuel.fuelGroups = typeMaps:createMap("fuelGroup", {
		{
			key = "campfire",
			name = locale:get("fuelGroup_campfire"),
			resources = {
				[resource.types.branch.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.log.index] = {
					fuelAddition = 6.0,
				},
				[resource.types.pineCone.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.pineConeBig.index] = {
					fuelAddition = 6.0,
				},
			},
			objectTypes = {},
			resourceGroupIndex = resource.groups.campfireFuel.index,
		},
		{
			key = "kiln",
			name = locale:get("fuelGroup_kiln"),
			resources = {
				[resource.types.branch.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.log.index] = {
					fuelAddition = 6.0,
				},
				[resource.types.pineCone.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.pineConeBig.index] = {
					fuelAddition = 6.0,
				},
			},
			objectTypes = {},
			resourceGroupIndex = resource.groups.kilnFuel.index,
		},
		{
			key = "torch",
			name = locale:get("fuelGroup_torch"),
			resources = {
				[resource.types.hay.index] = {
					fuelAddition = 1.0,
				},
			},
			objectTypes = {},
			resourceGroupIndex = resource.groups.torchFuel.index,
		},
		{
			key = "litObject",
			name = locale:get("fuelGroup_litObject"),
			resources = {
				[resource.types.hay.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.branch.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.log.index] = {
					fuelAddition = 6.0,
				},
				[resource.types.pineCone.index] = {
					fuelAddition = 1.0,
				},
				[resource.types.pineConeBig.index] = {
					fuelAddition = 6.0,
				},
			},
			objectTypes = {},
		},
	}) --DONT FORGET TO ADD TO RESOURCE GROUPS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


	-- Copied from vanilla fuel.lua from update b20.1
	-- Changes from the source code: change every occurrence of fuelGroup to fuel.fuelGroups
	function fuel:finalize()
		fuel.validGroupTypes = typeMaps:createValidTypesArray("fuelGroup", fuel.fuelGroups)
		local fuelGroupsByFuelResourceTypes = {}
	
		for i,groupType in ipairs(fuel.validGroupTypes) do
			for resourceTypeIndex,info in pairs(groupType.resources) do
				local gameObjectsTypesForResource = gameObject.gameObjectTypeIndexesByResourceTypeIndex[resourceTypeIndex]
				for j,gameObjectTypeIndex in ipairs(gameObjectsTypesForResource) do
					table.insert(groupType.objectTypes, gameObjectTypeIndex)
				end
	
				local fuelGroupsArray = fuelGroupsByFuelResourceTypes[resourceTypeIndex]
				if not fuelGroupsArray then
					fuelGroupsArray = {}
					fuelGroupsByFuelResourceTypes[resourceTypeIndex] = fuelGroupsArray
				end
				if groupType.resourceGroupIndex then
					table.insert(fuelGroupsArray, groupType)
				end
			end
		end
	
		fuel.groupsByObjectTypeIndex = {
			[gameObject.types.campfire.index] = fuel.fuelGroups.campfire,
			[gameObject.types.torch.index] = fuel.fuelGroups.torch,
			[gameObject.types.brickKiln.index] = fuel.fuelGroups.kiln,
		}
	
		fuel.fuelGroupsByFuelResourceTypes = fuelGroupsByFuelResourceTypes
	
	end

	function fuel:addFuelGroup(key, objectType)
		--- Allows adding a fuel group (e.g. a campfire).
		--- @param key: The key to add, such as 'cake'
		--- @param objectType: The object to add, containing all fields. Refer to the source code to see all fields.

		if fuel.fuelGroups[key] then
			log:warn("Overwriting fuel group:", key)
			log:log(debug.traceback())
		end

		objectType.key = key
		typeMaps:insert("fuelGroup", fuel.fuelGroups, objectType)
	end

	function fuel:addFuelType(key, fuelAdditionPerFuelGroup)
		--- Allows adding a fuel kind to existing fuel groups.
		--- @param key: The name of the resource type which will be used as fuel. E.g. "charcoal"
		--- @param fuelAdditionPerFuelGroup: Key-value pair where the key is a fuelGroup (e.g. "campfire" or "kiln") and the value is the fuelAddition (e.g. 6.0 is the fuelAddition for logs in the vanilla game)

		local typeIndexMap = typeMaps.types.resources -- Created automatically in resource.lua

		local index = typeIndexMap[key]
		if not index then
			log:error("Attempt to add fuel type that isn't in typeIndexMap:", key)
		else
			local resourceType = resource.types[key].index
			for fuelGroup, fA in pairs(fuelAdditionPerFuelGroup) do
				fuel.fuelGroups[fuelGroup].resources[resourceType] = { fuelAddition = fA }
			end

			-- Rerun fuel:finalize(). If this would cause issues, I advice to override fuel:mjInit and run fuel:addFuelType in there, without super-calling fuel:mjInit
			fuel:finalize()
		end
	end


	local super_mjInit = fuel.mjInit

	-- Note we are not calling super_mjInit. We don't need it.
	fuel.mjInit = function(self)
		fuel:finalize()
	end
end

return mod