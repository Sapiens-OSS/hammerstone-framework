--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich

local objectManager = {
	gameObject = nil
}

-- Local database of config information
local objectDB = {
	-- Unstructured game object definitions, read from FS
	objectConfigs = {},

	-- Unstructured storage configurations, read from FS
	storageConfigs = {},

	-- Map between storage identifiers and object IDENTIFIERS that should use this storage.
	-- Collected when generating objects, and inserted when generating storages (after converting to index)
	-- @format map<string, array<string>>.
	objectsForStorage = {}
}

-- TODO: Consider using metaTables to add default values to the objectDB
-- local mt = {
-- 	__index = function ()
-- 		return "10"
-- 	end
-- }
-- setmetatable(objectDB.objectConfigs, mt)

-- sapiens
local typeMaps = mjrequire "common/typeMaps"
local rng = mjrequire "common/randomNumberGenerator"

-- Math
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

---------------------------------------------------------------------------------
-- Configuation and Loading
---------------------------------------------------------------------------------

-- Initialize the full Data Driven API (DDAPI).
local initialized = false
function objectManager:init(gameObject)
	-- Initialization guard to prevent infinite looping
	if initialized then
		mj:warn("Attempting to re-initialize objectManager DDAPI! Skipping.")
		return
	else
		log:log("Initializing DDAPI...")
		initialized = true
	end

	-- Expose
	objectManager.gameObject = gameObject

	-- Load configs from FS
	objectManager:loadConfigs()

	-- Register items, in the order the game expects!
	objectManager:generateResourceDefinitions()
	objectManager:generateStorageObjects()
	objectManager:generateGameObjects(gameObject)
	-- generateEvolvingObjects is called internally, from `evolvingObjects.lua`.
end

--- Loops over known config locations and attempts to load them
-- TODO: Do mods get stored in different places when downloaded from steam?
-- TODO: Make sure it only loads configs from enabled mods.
-- TODO: Call this method from the correct location
function objectManager:loadConfigs()
	log:log("Loading Configuration files:")
	local modsDirectory = fileUtils.getSavePath("mods")
	local mods = fileUtils.getDirectoryContents(modsDirectory)
	local count = 0;

	-- Objects
	for i, mod in ipairs(mods) do
		local objectConfigDir = modsDirectory .. "/" .. mod .. "/hammerstone/objects/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectDB.objectConfigs)
		end
	end

	-- Storage
	for i, mod in ipairs(mods) do
		local objectConfigDir = modsDirectory .. "/" .. mod .. "/hammerstone/storage/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectDB.storageConfigs)
		end
	end

	log:log("Loaded Configs totalling: " .. count)
end

function objectManager:loadConfig(path, type)
	log:log("Loading DDAPI Config at " .. path)
	local configString = fileUtils.getFileContents(path)
	local configTable = json:decode(configString)
	table.insert(type, configTable)
end

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions()
	log:log("Generating resource definitions:")
	for i, config in ipairs(objectDB.objectConfigs) do
		objectManager:generateResourceDefinition(config)
	end
end

function objectManager:generateResourceDefinition(config)
	if config == nil then
		log:warn("Warning! Attempting to generate a resource definition that is nil.")
		return
	end

	local objectDefinition = config["hammerstone:object_definition"]
	local description = objectDefinition["description"]
	local components = objectDefinition["components"]
	local identifier = description["identifier"]

	-- Resource links would prevent a *new* resource from being generated.
	local resourceLinkComponent = components["hammerstone:resource_link"]
	if resourceLinkComponent ~= nil then
		log:log("GameObject " .. identifier .. " linked to resource " .. resourceLinkComponent.identifier .. " no unique resource created.")
		return
	end

	log:log("Generting Resource with identifier: " .. identifier)

	local objectComponent = components["hammerstone:object"]
	local name = description["name"]
	local plural = description["plural"]

	-- Local imports. Shoot me.
	local resource = mjrequire "common/resource"

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		-- displayGameObjectTypeIndex = typeMaps.types.gameObject[identifier] -- TODO Fix this shit.
		displayGameObjectTypeIndex = typeMaps.types.gameObject.chickenMeat, -- TODO Fix this shit.
	}

	-- Handle Food
	local foodComponent = components["hammerstone:food"]
	if foodComponent ~= nil then
		newResource.foodValue = foodComponent.value
		newResource.foodPortionCount = foodComponent.portions

		-- TODO These should be implemented with a smarter default value check
		if foodComponent.food_poison_chance ~= nil then
			newResource.foodPoisoningChance = foodComponent.food_poison_chance
		end
		
		if foodComponent.default_disabled ~= nil then
			newResource.defaultToEatingDisabled = foodComponent.default_disabled
		end
	end

	-- TODO: Consider handling `isRawMeat` and `isCookedMeat` for purpose of tutorial integration.

	-- Handle Decorations
	local decorationComponent = components["hammerstone:decoration"]
	if decorationComponent ~= nil then
		newResource.disallowsDecorationPlacing = not decorationComponent["enabled"]
	end

	objectManager:registerObjectForStorage(identifier, components["hammerstone:storage_link"])
	resource:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

--- Generates DDAPI storage objects.
function objectManager:generateStorageObjects()
	log:log("Generating Storage Objects:")
	for i, config in ipairs(objectDB.storageConfigs) do
		objectManager:generateStorageObject(config)
	end
end

--- Special helper function to generate the resource IDs that a storage should use, once they are available.
--- This is a workaround :L
function objectManager:generateResourceForStorage(storageIdentifier)
	-- Shoot me
	local resource = mjrequire "common/resource"

	local newResource = {}

	local objectIdentifiers = objectDB.objectsForStorage[storageIdentifier]
	if objectIdentifiers ~= nil then
		for i, identifier in ipairs(objectIdentifiers) do
			table.insert(newResource, resource.types[identifier].index)
		end
	else
		log:warning("Storage " .. storageIdentifier .. " is being generated with zero items. This is most likely a mistake.")
	end


	return newResource
end

function objectManager:generateStorageObject(config)
	if config == nil then
		log:warn("Attempting to Generate nil Storage Object.")
		return
	end

	-- Load structured information
	local object = config["hammerstone:storage"]
	local description = object["description"]
	local carryComponent = object.components["hammerstone:carry"]
	local storageComponent = object.components["hammerstone:storage"]
	local identifier = description.identifier

	log:log("Generting Storage Object with ID: " .. identifier)

	-- Inlined imports. Bad style. I don't care.
	local gameObjectTypeIndexMap = typeMaps.types.gameObject
	local resource = mjrequire "common/resource";

	local newStorage = {
		key = identifier,
		name = storageComponent.name,
		displayGameObjectTypeIndex = gameObjectTypeIndexMap[storageComponent.preview_object], -- TODO will this work?
		resources = objectManager:generateResourceForStorage(identifier),

		-- TODO: Add fields to customize this.
		storageBox = {
			size =  vec3(0.24, 0.1, 0.24),
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rotation = mat3Rotate(mat3Identity, randomValue * 6.282, vec3(0.0,1.0,0.0))
				return rotation
			end,
			dontRotateToFitBelowSurface = true,
			placeObjectOffset = mj:mToP(vec3(0.0,0.4,0.0)),
		},

		-- TODO Handle this stuff too.
		maxCarryCount = 1,
		maxCarryCountLimitedAbility = 1,
		--carryRotation = mat3Rotate(mat3Rotate(mat3Identity, math.pi * 0.4, vec3(0.0, 0.0, 1.0)), math.pi * 0.1, vec3(1.0, 0.0, 0.0)),
		carryRotation = mat3Rotate(mat3Identity, 1.2, vec3(0.0, 0.0, 1.0)),
		carryOffset = vec3(0.1,0.1,0.0),
	}

	mj:log(newStorage)
	local storageModule = mjrequire "common/storage"
	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Game Object
---------------------------------------------------------------------------------

function objectManager:generateEvolvingObjects(evolvingObject)
	log:log("Generating EvolvingObjects:")

	for i, config in ipairs(objectDB.objectConfigs) do
		objectManager:generateEvolvingObject(evolvingObject, config)
	end
end

function objectManager:generateEvolvingObject(evolvingObject, config)
	if config == nil then
		log:warn("Attempting to generate nil EvolvingObject")
		return
	end

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:evolving_object"]

	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:log("Creating EvolvingObject definition for " .. identifier)
	end

	-- TODO: Make this smart, and can handle day length OR year length.
	-- It claims it reads it as lua (schema), but it actually just multiplies it by days.
	local newEvolvingObject = {
		minTime = evolvingObject.dayLength * evolvingObjectComponent.min_time,
		categoryIndex = evolvingObject.categories[evolvingObjectComponent.category].index,
	}

	if evolvingObjectComponent.transform_to ~= nil then
		local function generateTransformToTable(transform_to)
			local newResource = {}
			for i, identifier in ipairs(transform_to) do
				table.insert(newResource, objectManager.gameObject.types[identifier].index)
			end
		
			return newResource
		end

		newEvolvingObject.toTypes = generateTransformToTable(evolvingObjectComponent.transform_to)
	end
	

	evolvingObject:addEvolvingObject(identifier, newEvolvingObject)
end

---------------------------------------------------------------------------------
-- Game Object
---------------------------------------------------------------------------------

--- Registers an object into a storage.
-- @param identifier - The identifier of the object. e.g., hs:cake
-- @param componentData - The inner-table data for `hammerstone:storage`
function objectManager:registerObjectForStorage(identifier, componentData)
	if componentData == nil then
		return
	end

	-- Initialize this storage container, if this is the first item we're adding.
	local storageIdentifier = componentData.identifier
	if objectDB.objectsForStorage[storageIdentifier] == nil then
		objectDB.objectsForStorage[storageIdentifier] = {}
	end

	-- Shoot me
	local resource = mjrequire "common/resource"

	-- Insert the object identifier for this storage container
	table.insert(objectDB.objectsForStorage[storageIdentifier], identifier)
end

function objectManager:generateGameObjects(gameObject)
	log:log("Generating GameObjects:")

	for i, config in ipairs(objectDB.objectConfigs) do
		objectManager:generateGameObject(config, gameObject)
	end
end

function objectManager:generateGameObject(config, gameObject)
	if config == nil then
		log:warn("Attempting to generate nil GameObject")
		return
	end

	local object_definition = config["hammerstone:object_definition"]
	local description = object_definition["description"]
	local components = object_definition["components"]
	local objectComponent = components["hammerstone:object"]
	local identifier = description["identifier"]
	log:log("Registering GameObject with ID " .. identifier)

	local name = description["name"]
	local plural = description["plural"]
	local scale = objectComponent["scale"]
	local model = objectComponent["model"]
	local physics = objectComponent["physics"]
	local marker_positions = objectComponent["marker_positions"]

	-- Shoot me
	local resource = mjrequire "common/resource"

	
	-- Allow resource linking
	local resourceIdentifier = identifier
	local resourceLinkComponent = components["hammerstone:resource_link"]
	if resourceLinkComponent ~= nil then
		resourceIdentifier = resourceLinkComponent["identifier"]
	end

	-- TODO: toolUsages
	-- TODO: selectionGroupTypeIndexes
	-- TODO: Implement eatByProducts

	-- TODO: These ones are probably for a new component related to world placement.
	-- allowsAnyInitialRotation
	-- randomMaxScale = 1.5,
	-- randomShiftDownMin = -1.0,
	-- randomShiftUpMax = 0.5,
	local newObject = {
		name = name,
		plural = plural,
		modelName = model,
		scale = scale,
		hasPhysics = physics,
		resourceTypeIndex = resource.types[resourceIdentifier].index,

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Actually register the game object
	gameObject:addGameObject(identifier, newObject)
end


return objectManager