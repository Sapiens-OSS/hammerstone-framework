-- Sapiens
local rng = mjrequire "common/randomNumberGenerator"

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local modules = moduleManager.modules

local storageManager = {
    settings = {
        unwrap = "hammerstone:storage_definition",
        configPath = "/hammerstone/storage",
        luaGetter = "getStorageConfigs",
        configFiles = {},
    }, 
    loaders = {}
}

function storageManager:init(ddapiManager_)
    storageManager.loaders.storage = {
        rootComponent = "hs_storage",
        moduleDependencies = {
            "storage",
            "typeMaps",
            "resource", 
            "gameObject"
        },
        dependencies = {
            "resource",
            "gameObject",
        },
        loadFunction = storageManager.generateStorageObject
    }
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

function storageManager:generateStorageObject(objDef, description, components, identifier, rootComponent)
	-- Components
	local carryComponent = components:getTable("hs_carry")

	-- Allow this field to be undefined, but don't use nil, since we will pull props from here later, with their *own* defaults
	local carryCounts = carryComponent:getTableOrNil("hs_carry_count"):default({})

	local displayObject = rootComponent:getStringOrNil("display_object"):default(identifier):getValue()
	local displayIndex = modules["gameObject"].types[displayObject].index
	log:schema("ddapi", string.format("  Adding display_object '%s' to storage '%s', with index '%s'", displayObject, identifier, displayIndex))

	-- The new storage item

	local baseRotationWeight = rootComponent:getNumberOrNil("base_rotation_weight"):default(0):getValue()
	local baseRotationValue = rootComponent:getTableOrNil("base_rotation"):default(vec3(1.0, 0.0, 0.0)):asVec3()
	local randomRotationWeight = rootComponent:getNumberOrNil("random_rotation_weight"):default(2.0):getValue()
	local randomRotation = rootComponent:getTableOrNil("random_rotation"):default(vec3(1, 0.0, 0.0)):asVec3()

	local newStorage = {
		key = identifier,
		name = description:getStringOrNil("name"):asLocalizedString(utils:getNameKey("storage", identifier)),

		displayGameObjectTypeIndex = displayIndex,
		
		resources = rootComponent:getTableOrNil("resources"):default({}):asTypeIndex(modules["resource"].types, "Resource"),

		storageBox = {
			size =  rootComponent:getTableOrNil("item_size"):default(vec3(0.5, 0.5, 0.5)):asVec3(),
			

			rotationFunction = 
			function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)

				local baseRotation = mat3Rotate(
					mat3Identity,
					math.pi * baseRotationWeight,
					baseRotationValue
				)

				return mat3Rotate(
					baseRotation,
					randomValue * randomRotationWeight,
					randomRotation
				)
			end,
			
			placeObjectOffset = mj:mToP(rootComponent:getTableOrNil("place_offset"):default(vec3(0.0, 0.0, 0.0)):asVec3()),

			placeObjectRotation = mat3Rotate(
				mat3Identity,
				math.pi * rootComponent:getNumberOrNil("place_rotation_weight"):default(0.0):getValue(),
				rootComponent:getTableOrNil("place_rotation"):default(vec3(0.0, 0.0, 1)):asVec3()
			),
		},

		maxCarryCount = carryCounts:getNumberOrNil("normal"):default(1):getValue(),
		maxCarryCountLimitedAbility = carryCounts:getNumberOrNil("limited_ability"):default(1):getValue(),
		maxCarryCountForRunning = carryCounts:getNumberOrNil("running"):default(1):getValue(),


		carryStackType = modules["storage"].stackTypes[carryComponent:getStringOrNil("stack_type"):default("standard"):getValue()],
		carryType = modules["storage"].carryTypes[carryComponent:getStringOrNil("carry_type"):default("standard"):getValue()],

		carryOffset = carryComponent:getTableOrNil("offset"):default(vec3(0.0, 0.0, 0.0)):asVec3(),

		carryRotation = mat3Rotate(mat3Identity,
			carryComponent:getNumberOrNil("rotation_constant"):default(1):getValue(),
			carryComponent:getTableOrNil("rotation"):default(vec3(0.0, 0.0, 1.0)):asVec3()
		),
	}
	
	if rootComponent:hasKey("props") then
		newStorage = rootComponent:getTable("props"):mergeWith(newStorage):clear()
	end

	modules["storage"]:addStorage(identifier, newStorage)
end


return storageManager