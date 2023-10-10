--- Hammerstone: fuel.lua

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local resource = mjrequire "common/resource"

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local log = mjrequire "hammerstone/logging"
local shadow = mjrequire "hammerstone/utils/shadow"

local fuel = {}

function fuel:preload(base)
	moduleManager:addModule("fuel", base)
end

function fuel:addFuelGroup(key, objectType)
	--- Allows adding a fuel group (e.g. a campfire).
	--- @param key: The key to add, such as 'cake'
	--- @param objectType: The object to add, containing all fields. Refer to the source code to see all fields.

	if self.fuelGroups[key] then
		log:warn("Overwriting fuel group:", key)
		log:log(debug.traceback())
	end

	objectType.key = key
	typeMaps:insert("fuelGroup", self.fuelGroups, objectType)
end

function fuel:addFuelType(key, fuelAdditionPerFuelGroup)
	--- Allows adding a fuel kind to existing fuel groups.
	--- @param key: The name of the resource type which will be used as fuel. E.g. "charcoal"
	--- @param fuelAdditionPerFuelGroup: Key-value pair where the key is a fuelGroup (e.g. "campfire" or "kiln") and the value is the fuelAddition (e.g. 6.0 is the fuelAddition for logs in the vanilla game)

	if not resource.types[key] then
		log:error("Attempt to add fuel type that isn't in resource.types :", key)
	else
		local resourceType = resource.types[key].index
		for fuelGroup, fA in pairs(fuelAdditionPerFuelGroup) do
			self.fuelGroups[fuelGroup].resources[resourceType] = { fuelAddition = fA }
		end

		-- Rerun fuel:finalize(). If this would cause issues, I advice to override fuel:mjInit and run fuel:addFuelType in there, without super-calling fuel:mjInit
		self:finalize()
	end
end



return shadow:shadow(fuel, 0)