--- Hammerstone: resource.lua.
-- Mostly used to extend the resource module with additional helpers.
-- @author SirLich


-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local resource = {}

function resource:preload(base)
	moduleManager:addModule("resource", base)
end

--- Allows adding a resource.
--- @param key: The key to add, such as 'cake'
--- @param objectType: The object to add, containing all fields.
function resource:addResource(key, objectType)
	if self.types[key] then
		log:warn("Overwriting resource type:", key)
		log:log(debug.traceback())
	end

	typeMaps:insert("resource", self.types, objectType)

	-- Recache the type maps
	self.validTypes = typeMaps:createValidTypesArray("resource", self.types)

	-- TODO: This is a hack to ensure ordering somewhat functions
	if self.alphabeticallyOrderedTypes == nil then
		self.alphabeticallyOrderedTypes = {}
	end

	for index, value in ipairs(self.validTypes) do
		if value.key ~= nil and value.key == key then
			table.insert(self.alphabeticallyOrderedTypes, self.validTypes[index])
			table.sort(self.alphabeticallyOrderedTypes, function(a, b)
				return a.name < b.name
			end)
			break
		end
	end

	return objectType.index
end

-- Allows injecting a resource into an existing group
-- @param resourceKey the key of the resource to add, such as 'bone_meal'
-- @param groupKey the key of the group, such as 'fertilizer'
function resource:addResourceToGroup(resourceKey, groupKey)
	if not self.groups[groupKey] then
		log:error("Attempt addResourceToGroup, but the group doesn't exist:", groupKey)
	elseif not self.types[resourceKey] then
		log:error("Attempt addResourceToGroup, but the resource doesn't exist:", resourceKey)
	else
		-- Inject resource into existing group
		table.insert(self.groups[groupKey].resourceTypes, self.types[resourceKey].index)
		
		-- Recache the type maps
		self:createGroupHashesForBuiltInTypes()
	end

	return self.groups[groupKey].index
end

--- Allows adding a resource group.
--- @param key: The key to add, such as 'cake'
--- @param objectType: The object to add, containing all fields.
function resource:addResourceGroup(key, objectType)
	if self.groups[key] then
		log:warn("Overwriting resource group type:", key)
		log:log(debug.traceback())
	end

	typeMaps:insert("resourceGroup", self.groups, objectType)

	-- Recache the type maps
	self:createGroupHashesForBuiltInTypes()

	return objectType.index
end

return shadow:shadow(resource, 0)
