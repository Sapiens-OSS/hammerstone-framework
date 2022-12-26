--- Hammerstone: resource.lua.
-- Mostly used to extend the resource module with additional helpers.
-- @author SirLich

local mod = {
	-- A low load-order makes the most since, as we need these methods to be available
	-- for other shadows.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local log = mjrequire "hammerstone/logging"

function mod:onload(resource)
	--- Allows adding a resource.
	--- @param key: The key to add, such as 'cake'
	--- @param objectType: The object to add, containing all fields.
	function resource:addResource(key, objectType)
		mj:log("ADDING RESOURCE!")
		mj:log(key)
		mj:log(objectType)

		local resourceIndexMap = typeMaps.types.resources -- Created automatically in resource.lua
		local index = resourceIndexMap[key]
		if not index then
			log:error("Attempt to add resource type that isn't in typeIndexMap:", key)
		else
			if resource.types[key] then
				log:warn("Overwriting resource type:", key)
				log:log(debug.traceback())
			end
	
			objectType.key = key
			objectType.index = index
			typeMaps:insert("resource", resource.types, objectType)

			-- Recache the type maps
			resource.validTypes = typeMaps:createValidTypesArray("resource", resource.types)

			-- TODO: This is a hack to ensure ordering somewhat functions
			if resource.alphabeticallyOrderedTypes == nil then
				resource.alphabeticallyOrderedTypes = {}
			end

			for index, value in ipairs(resource.validTypes) do
				if value.key ~= nil and value.key == key then
					table.insert(resource.alphabeticallyOrderedTypes, resource.validTypes[index])
					table.sort(resource.alphabeticallyOrderedTypes, function(a, b)
						return a.name < b.name
					end)
					break
				end
			end
		end

		return index
	end

	-- From the source code of version 0.3.8. It's a local function so copy/paste is the only way to use it :/
	local function createGroupHashesForBuiltInTypes()
		local validGroupTypes = typeMaps:createValidTypesArray("resourceGroup", resource.groups)
		for i,groupType in ipairs(validGroupTypes) do
			if not groupType.containsTypesSet then
				groupType.containsTypesSet = {}
			end
			for j, resourceTypeIndex in ipairs(groupType.resourceTypes) do
				groupType.containsTypesSet[resourceTypeIndex] = true
			end
		end
	end

	--- Allows adding a resource group.
	--- @param key: The key to add, such as 'cake'
	--- @param objectType: The object to add, containing all fields.
	function resource:addResourceGroup(key, objectType)
		local typeIndexMap = typeMaps.types.resourceGroups -- Created automatically in resource.lua

		local index = typeIndexMap[key]
		if not index then
			log:error("Attempt to add resource group type that isn't in typeIndexMap:", key)
		else
			if resource.groups[key] then
				log:warn("Overwriting resource group type:", key)
				log:log(debug.traceback())
			end
	
			objectType.key = key
			objectType.index = index
			typeMaps:insert("resourceGroup", resource.groups, objectType)

			-- Recache the type maps
			createGroupHashesForBuiltInTypes()
		end

		return index
	end

	local super_mjInit = resource.mjInit
	resource.mjInit = function(self)
		super_mjInit(self)
	end
end

return mod
