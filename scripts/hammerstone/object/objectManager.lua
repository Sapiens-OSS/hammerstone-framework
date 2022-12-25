--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich

local objectManager = {
	modules = {},
	inspectCraftPanelData = {},
}

-- Local database of config information
local objectDB = {
	-- Unstructured game object definitions , read from FS
	objectConfigs = {},

	-- Unstructured storage configurations, read from FS
	storageConfigs = {},

	-- Unstructured recipe configurations, read from FS
	recipeConfigs = {},

	-- Map between storage identifiers and object IDENTIFIERS that should use this storage.
	-- Collected when generating objects, and inserted when generating storages (after converting to index)
	-- @format map<string, array<string>>.
	objectsForStorage = {},

	-- Unstructured storage configurations, read from FS
	recipeConfigs = {},

	-- Unstructured storage configurations, read from FS
	materialConfigs = {},
}

-- TODO: Consider using metaTables to add default values to the objectDB
-- local mt = {
-- 	__index = function ()
-- 		return "10"
-- 	end
-- }
-- setmetatable(objectDB.objectConfigs, mt)

local modules = objectManager.modules

-- Sapiens
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
function objectManager:init()

	-- Initialization guard to prevent infinite looping
	if initialized then
		mj:warn("Attempting to re-initialize objectManager DDAPI! Skipping.")
		return
	else
		log:schema(nil, "")
		log:log("Initializing DDAPI...")
		initialized = true
	end

	-- Expose
	modules.resource = mjrequire "common/resource"

	-- Load configs from FS
	objectManager:loadConfigs()

	-- Register items, in the order the game expects!
	objectManager:generateMaterialDefinitions()
	objectManager:generateResourceDefinitions()
	-- generateGameObjects is called internally, from `gameObject.lua`.
	-- generateStorageObjects is called internally, from `gameObject.lua`.
	-- generateEvolvingObjects is called internally, from `evolvingObject.lua`.
	-- generateRecipeDefinitions is called internally, from `craftable.lua`.
end

-- Loops over known config locations and attempts to load them
-- TODO: Call this method from the correct location
function objectManager:loadConfigs()

	log:log("Loading Configuration files:")

	local routes = {
		{
			path = "/hammerstone/objects/",
			dbTable = objectDB.objectConfigs
		},
		{
			path = "/hammerstone/storage/",
			dbTable = objectDB.storageConfigs
		},
		{
			path = "/hammerstone/recipes/",
			dbTable = objectDB.recipeConfigs
		},
		{
			path = "/hammerstone/materials/",
			dbTable = objectDB.materialConfigs
		}
	}

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0;

	for i, mod in ipairs(mods) do
		for _, route in pairs(routes) do
			local objectConfigDir = mod.path .. route.path
			local configs = fileUtils.getDirectoryContents(objectConfigDir)
			for j, config in ipairs(configs) do
				local fullPath =  objectConfigDir .. config
				count = count + 1;
				objectManager:loadConfig(fullPath, route.dbTable)
			end
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

local function addModules(modulesTable)
	for k, v in pairs(modulesTable) do
		objectManager.modules[k] = v
	end
end

---------------------------------------------------------------------------------
-- Utilities (very temporary stuff, testing phase)
---------------------------------------------------------------------------------

-- Returns result of running predicate on each item in table
function map(tbl, predicate)
	local data = {}
	for i,e in ipairs(tbl) do
		local value = predicate(e)
		if value ~= nil then
			table.insert(data, value)
		end
	end
	return data
end

-- Returns data if running predicate on each item in table returns true
function all(tbl, predicate)
	for i,e in ipairs(tbl) do
		local value = predicate(e)
		if value == nil or value == false then
			return false
		end
	end
	return tbl
end

-- Returns items that have returned true for predicate
function where(tbl, predicate)
	local data = {}
	for i,e in ipairs(tbl) do
		if predicate(e) then
			table.insert(data, e)
		end
	end
	return data
end

local logMissingTables = {}

function logMissing(displayAlias, key, tbl)
	if logMissingTables[tbl] == nil then
		table.insert(logMissingTables, tbl)

		if key == nil then
			log:schema(nil, "    ERROR: " .. displayAlias .. " key is nil.")
			log:schema(nil, debug.traceback())
		else
			log:schema(nil, "    ERROR: " .. displayAlias .. " '" .. key .. "' does not exist. Try one of these instead:")

			for k, _ in pairs(tbl) do
				if type(k) == "string" then
					log:schema(nil, "      " .. k)
				end
			end
		end
	end
end

function logExisting(displayAlias, key, tbl)
	log:schema(nil, "    WARNING: " .. displayAlias .. " already exists with key '" .. key .. "'")
end

function logWrongType(key, typeName)
	log:schema(nil, "    ERROR: " .. key .. " should be of type " .. typeName .. ", not " .. type(key))
end

function logNotImplemented(featureName)
	log:schema(nil, "    WARNING: " .. featureName .. " is used but it is yet to be implemented")
end

-- Returns the index of a type, or nil if not found.
function getTypeIndex(tbl, key, displayAlias)
	if tbl[key] ~= nil then
		return tbl[key].index
	end
	return logMissing(displayAlias, key, tbl)
end

-- Returns the key of a type, or nil if not found.
--- @param tbl table
--- @param key string
--- @param displayAlias string
function getTypeKey(tbl, key, displayAlias)
	if tbl[key] ~= nil then
		return tbl[key].key
	end
	return logMissing(displayAlias, key, tbl)
end

-- Return true if a table has key.
function hasKey(tbl, key)
	return tbl ~= nil and tbl[key] ~= nil
end

-- Return true if a table is null or empty.
function isEmpty(tbl)
	return tbl == nil or next(tbl) == nil
end

-- Returns true if value is of type. Also returns true for value = "true" and typeName = "boolean".
function isType(value, typeName)
	if type(value) == typeName then
		return true
	end
	if typeName == "number" then
		return tonumber(value)
	end
	if typeName == "boolean" then
		return value == "true"
	end
	return false
end

function validate(key, value, options)

	-- Make sure this field has the proper type
	if options.type ~= nil then
		if not isType(value, options.type) then
			return logWrongType(key, options.type)
		end
	end

	-- Make sure this field value has a valid type
	if options.inTypeTable ~= nil then
		--mj:log("inTypeTable " .. key, options.inTypeTable)
		if type(options.inTypeTable) == "table" then
			if not hasKey(options.inTypeTable, value) then
				return logMissing(key, value, options.inTypeTable)
			end
		else
			log:schema(nil, "    ERROR: Value of inTypeTable is not table")
		end
	end

	-- Make sure this field value is a unique type
	if options.notInTypeTable ~= nil then
		if type(options.notInTypeTable) == "table" then
			if hasKey(options.notInTypeTable, value) then
				return logExisting(key, value, options.notInTypeTable)
			end
		else
			log:schema(nil, "    ERROR: Value of notInTypeTable is not table")
		end
	end

	return value
end

function getField(tbl, key, options)
	local value = tbl[key]
	local name = key

	if value == nil then
		return
	end

	if options ~= nil then
		if validate(key, value, options) == nil then
			return
		end

		if options.with ~= nil then
			if type(options.with) == "function" then
				value = options.with(value)
			else
				log:schema("    ERROR: Value of with option is not function")
			end
		end
	end

	return value
end

function getTable(tbl, key, options)
	local values = tbl[key]
	local name = key

	if values == nil then
		return
	end

	if type(values) ~= "table" then
		return log:schema("    ERROR: Value type of key '" .. key .. "' is not table")
	end

	if options ~= nil then

		-- Run basic validation on all elements in the table
		for k, v in pairs(values) do
			if validate(key, v, options) == nil then
				return
			end
		end

		if options.displayName ~= nil then
			name = options.displayName
		end

		if options.length ~= nil and options.length ~= #values then
			return log:schema("    ERROR: Value of key '" .. key .. "' requires " .. options.length .. " elements")
		end

		for k, v in pairs(options) do
			if k == "map" then
				if type(v) == "function" then
					values = map(values, v)
				else
					log:schema("    ERROR: Value of map option is not function")
				end
			end

			if k == "with" then
				if type(v) == "function" then
					values = v(values)
					if values == nil then
						return
					end
				else
					log:schema("    ERROR: Value of with option is not function")
				end
			end
		end
	end

	return values
end

function compile(req, data)
	for k, v in pairs(req) do
		if v and data[k] == nil then
			log:schema(nil, "    Missing " .. k)
			return
		end
	end
	return data
end


---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions()
	log:schema(nil, "")
	log:log("Generating Resource definitions:")
	for i, config in ipairs(objectDB.objectConfigs) do
		objectManager:generateResourceDefinition(config)
	end
end

function objectManager:generateResourceDefinition(config)
	if config == nil then
		log:warn("Warning! Attempting to generate a resource definition that is nil.")
		return
	end

	local resource = mjrequire "common/resource"

	local objectDefinition = config["hammerstone:object_definition"]
	local description = objectDefinition["description"]
	local components = objectDefinition["components"]
	local identifier = description["identifier"]

	-- Resource links prevent a *new* resource from being generated.
	local resourceLinkComponent = components["hammerstone:resource_link"]
	if resourceLinkComponent ~= nil then
		log:log("GameObject " .. identifier .. " linked to resource " .. resourceLinkComponent.identifier .. " no unique resource created.")
		return
	end

	log:log("  " .. identifier)

	local objectComponent = components["hammerstone:object"]
	local name = description["name"]
	local plural = description["plural"]

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = typeMaps.types.gameObject[identifier],
	}

	-- Handle Food
	local foodComponent = components["hammerstone:food"]
	if foodComponent ~= nil then
		--if type() -- TODO
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
	log:schema(nil, "")
	log:log("Generating Storage definitions:")
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

	log:log("  " .. identifier)

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

	--mj:log(newStorage)
	local storageModule = mjrequire "common/storage"
	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

function objectManager:generateEvolvingObjects(mods)
	addModules(mods)

	log:schema(nil, "")
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

	local evolvingObject = modules.evolvingObject

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:evolving_object"]
	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:log("  " .. identifier)
	end

	-- TODO: Make this smart, and can handle day length OR year length.
	-- It claims it reads it as lua (schema), but it actually just multiplies it by days.
	local newEvolvingObject = {
		minTime = evolvingObject.dayLength * evolvingObjectComponent.min_time,
		categoryIndex = evolvingObject.categories[evolvingObjectComponent.category].index,
	}

	if evolvingObjectComponent.transform_to ~= nil then
		local gameObject = mjrequire "common/gameObject"

		local function generateTransformToTable(transform_to)
			local newResource = {}
			for i, identifier in ipairs(transform_to) do
				table.insert(newResource, gameObject.types[identifier].index)
			end
			return newResource
		end

		newEvolvingObject.toTypes = generateTransformToTable(evolvingObjectComponent.transform_to)
	end
	
	evolvingObject:addEvolvingObject(identifier, newEvolvingObject)
end

---------------------------------------------------------------------------------
-- Harvestable Objects
---------------------------------------------------------------------------------

function objectManager:generateHarvestableObjects(mods)
	addModules(mods)

	log:schema(nil, "")
	log:log("Generating Harvestable Objects:")
	for i, config in ipairs(objectDB.objectConfigs) do
		objectManager:generateHarvestableObject(config)
	end
end

function objectManager:generateHarvestableObject(config)
	local harvestableModule = modules.harvestable -- This will crash until we actuall provide this

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:harvestable"]
	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:log("  " .. identifier)
	end

	-- TODO: Make this smart, and can handle day length OR year length.
	-- It claims it reads it as lua (schema), but it actually just multiplies it by days.
	local newEvolvingObject = {
		minTime = evolvingObject.dayLength * evolvingObjectComponent.min_time,
		categoryIndex = evolvingObject.categories[evolvingObjectComponent.category].index,
	}

	if evolvingObjectComponent.transform_to ~= nil then
		local gameObject = mjrequire "common/gameObject"

		local function generateTransformToTable(transform_to)
			local newResource = {}
			for i, identifier in ipairs(transform_to) do
				table.insert(newResource, gameObject.types[identifier].index)
			end
			return newResource
		end

		newEvolvingObject.toTypes = generateTransformToTable(evolvingObjectComponent.transform_to)
	end
	
	-- evolvingObject:addEvolvingObject(identifier, newEvolvingObject)
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

function objectManager:generateGameObjects(mods)
	addModules(mods)

	log:schema(nil, "")
	log:log("Generating Object definitions:")
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
	log:log("  " .. identifier)

	local name = description["name"]
	local plural = description["plural"]
	local scale = objectComponent["scale"]
	local model = objectComponent["model"]
	local physics = objectComponent["physics"]
	local marker_positions = objectComponent["marker_positions"]
	
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
		resourceTypeIndex = modules.resource.types[resourceIdentifier].index,

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Actually register the game object
	modules.gameObject:addGameObject(identifier, newObject)
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------

--- Generates recipe definitions based on the loaded config, and registers them.
function objectManager:generateRecipeDefinitions(mods)
	addModules(mods)

	modules.action = mjrequire "common/action"
	modules.actionSequence = mjrequire "common/actionSequence"
	modules.tool = mjrequire "common/tool"
	
	modules.craftAreaGroup = mjrequire "common/craftAreaGroup"
	modules.constructable = mjrequire "common/constructable"
	modules.skill = mjrequire "common/skill"

	log:schema(nil, "")
	log:schema(nil, "Generating Recipe definitions:")
	for i, config in ipairs(objectDB.recipeConfigs) do
		objectManager:generateRecipeDefinition(config)
	end
end

function objectManager:generateRecipeDefinition(config)

	if config == nil then
		log:schema(nil, "  Warning! Attempting to generate a recipe definition that is nil.")
		return
	end
	
	-- Definition
	local objectDefinition = config["hammerstone:recipe_definition"]
	local description = objectDefinition["description"]
	local identifier = description["identifier"]
	local components = objectDefinition["components"]

	-- Components
	local recipe = components["hammerstone:recipe"]
	local requirements = components["hammerstone:requirements"]
	local output = components["hammerstone:output"]
	local build_sequence = components["hammerstone:build_sequence"]

	log:schema(nil, "  " .. identifier)

	local required = {
		identifier = true,
		name = true,
		plural = true,
		summary = true,

		iconGameObjectType = true,
		classification = true,
		isFoodPreperation = false,
		
		skills = false,
		requiredCraftAreaGroups = false,
		requiredTools = false,

		outputObjectInfo = true,
		
		inProgressBuildModel = true,
		buildSequence = true,
		requiredResources = true,

		-- TODO: outputDisplayCount
		-- TODO: addGameObjectInfo
			-- modelName
			-- resourceTypeIndex
			-- toolUsages {}
	}

	local data = compile(required, {

		-- Description
		identifier = getField(description, "identifier", {
			notInTypeTable = modules.craftable.types
		}),
		name = getField(description, "name"),
		plural = getField(description, "plural"),
		summary = getField(description, "summary"),


		-- Recipe Component
		iconGameObjectType = getField(recipe, "preview_object", {
			inTypeTable = modules.gameObject.types
		}),
		classification = getField(recipe, "classification", {
			inTypeTable = modules.constructable.classifications -- Why is this crashing?
		}),
		isFoodPreperation = getField(recipe, "isFoodPreparation", {
			type = "boolean"
		}),


		-- Output Component
		outputObjectInfo = {
			outputArraysByResourceObjectType = getTable(output, "output_by_object", {
				with = function(tbl)
					local result = {}
					for _, value in pairs(tbl) do -- Loop through all output objects
						
						-- Return if input isn't a valid gameObject
						if getTypeIndex(modules.gameObject.types, value.input, "Game Object") == nil then return end

						-- Get the input's resource index
						local index = modules.gameObject.types[value.input].index

						-- Convert from schema format to vanilla format
						-- If the predicate returns nil for any element, map returns nil
						-- In this case, log an error and return if any output item does not exist in gameObject.types
						result[index] = map(value.output, function(e)
							return getTypeIndex(modules.gameObject.types, e, "Game Object")
						end)
					end
					return result
				end
			}),
		},


		-- Requirements Component
		skills = getTable(requirements, "skills", {
			inTypeTable = modules.skill.types,
			with = function(tbl)
				if #tbl > 0 then
					return {
						required = modules.skill.types[tbl[1] ].index
					}
				end
			end
		}),
		disabledUntilAdditionalSkillTypeDiscovered = getTable(requirements, "skills", {
			inTypeTable = modules.skill.types,
			with = function(tbl)
				if #tbl > 1 then
					return modules.skill.types[tbl[2] ].index
				end
			end
		}),
		requiredCraftAreaGroups = getTable(requirements, "craft_area_groups", {
			map = function(e)
				return getTypeIndex(modules.craftAreaGroup.types, e, "Craft Area Group")
			end
		}),
		requiredTools = getTable(requirements, "tools", {
			map = function(e)
				return getTypeIndex(modules.tool.types, e, "Tool")
			end
		}),


		-- Build Sequence Component
		inProgressBuildModel = getField(build_sequence, "build_sequence_model"),
		buildSequence = getTable(build_sequence, "build_sequence", {
			with = function(tbl)
				if not isEmpty(tbl.steps) then
					-- If steps exist, we create a custom build sequence instead a standard one
					logNotImplemented("Custom Build Sequence") -- TODO: Implement steps
				else
					-- Cancel if action field doesn't exist
					if tbl.action == nil then
						return log:schema(nil, "    Missing Action Sequence")
					end

					-- Get the action sequence
					local sequence = getTypeIndex(modules.actionSequence.types, tbl.action, "Action Sequence")
					if sequence ~= nil then

						-- Cancel if a tool is stated but doesn't exist
						if tbl.tool ~= nil and #tbl.tool > 0 and getTypeIndex(modules.tool.types, tbl.tool, "Tool") == nil then
							return
						end

						-- Return the standard build sequence constructor
						return modules.craftable:createStandardBuildSequence(sequence, tbl.tool)
					end
				end
			end
		}),
		requiredResources = getTable(build_sequence, "resource_sequence", {
			-- Runs for each item and replaces item with return result
			map = function(e)

				-- Get the resource
				local res = getTypeIndex(modules.resource.types, e.resource, "Resource")
				if (res == nil) then return end -- Cancel if resource does not exist

				-- Get the count
				local count = e.count or 1
				if (not isType(count, "number")) then
					return log:schema(nil, "    Resource count for " .. e.resource .. " is not a number")
				end

				if e.action ~= nil then

					-- Return if action is invalid
					local actionType = getTypeIndex(modules.action.types, e.action.action_type, "Action")
					if (actionType == nil) then return end

					-- Return if duration is invalid
					local duration = e.action.duration
					if (not isType(duration, "number")) then
						return log:schema(nil, "    Duration for " .. e.action.action_type .. " is not a number")
					end

					-- Return if duration without skill is invalid
					local durationWithoutSkill = e.action.duration_without_skill or duration
					if (not isType(durationWithoutSkill, "number")) then
						return log:schema(nil, "    Duration without skill for " .. e.action.action_type .. " is not a number")
					end

					return {
						type = res,
						count = count,
						afterAction = {
							actionTypeIndex = actionType,
							duration = duration,
							durationWithoutSkill = durationWithoutSkill,
						}
					}
				end
				return {
					type = res,
					count = count,
				}
			end
		})
	})

	if data ~= nil then
		-- Add recipe
		modules.craftable:addCraftable(identifier, data)

		-- Add items in crafting panels
		for _, group in ipairs(data.requiredCraftAreaGroups) do
			local key = modules.gameObject.typeIndexMap[modules.craftAreaGroup.types[group].key]
			if objectManager.inspectCraftPanelData[key] == nil then
				objectManager.inspectCraftPanelData[key] = {}
			end
			table.insert(objectManager.inspectCraftPanelData[key], modules.constructable.types[identifier].index)
		end
	end
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

--- Generates material definitions based on the loaded config, and registers them.
function objectManager:generateMaterialDefinitions()

	modules.material = mjrequire "common/material"

	log:schema(nil, "")
	log:schema(nil, "Generating Material definitions:")
	for i, config in ipairs(objectDB.materialConfigs) do
		objectManager:generateMaterialDefinition(config)
	end
end

function objectManager:generateMaterialDefinition(config)

	if config == nil then
		log:schema(nil, "  Warning! Attempting to generate a material definition that is nil.")
		return
	end
	
	local materialDefinition = config["hammerstone:material_definition"]
	local materials = materialDefinition["materials"]

	for _, mat in pairs(materials) do

		log:schema(nil, "  " .. mat["identifier"])

		local required = {
			identifier = true,
			color = true,
			roughness = true,
			metal = false,
		}

		local data = compile(required, {

			identifier = getField(mat, "identifier", {
				notInTypeTable = modules.material.types
			}),

			color = getTable(mat, "color", {
				type = "number",
				length = 3,
				with = function(tbl)
					return vec3(tbl[1], tbl[2], tbl[3]) -- Convert number table to vec3
				end
			}),
			
			roughness = getField(mat, "roughness", {
				type = "number"
			}),

			metal = getField(mat, "metal", {
				type = "number"
			})
		})

		if data ~= nil then
			modules.material:addMaterial(data.identifier, data.color, data.roughness, data.metal)
		end
	end
end

return objectManager