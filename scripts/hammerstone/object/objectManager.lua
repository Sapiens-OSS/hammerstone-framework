--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich, earmuffs

local objectManager = {
	inspectCraftPanelData = {},
}

-- Local database of config information
local objectDB = {
	-- Unstructured game object definitions , read from FS
	objectConfigs = {},

	-- Unstructured storage configurations, read from FS
	storageConfigs = {},

	-- Map between storage identifiers and object IDENTIFIERS that should use this storage.
	-- Collected when generating objects, and inserted when generating storages (after converting to index)
	-- @format map<string, array<string>>.
	objectsForStorage = {},

	-- Unstructured storage configurations, read from FS
	recipeConfigs = {},

	-- Unstructured storage configurations, read from FS
	materialConfigs = {},

	-- Unstructured storage configurations, read from FS
	skillConfigs = {},
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

-- TODO: Make this flag less idiotic
local configsLoadedFromFS = false

--- Data structure which defines how a config is loaded, and in which order. 
-- @field path - The path of the object, relative to the mod-root
-- @field dbTable - The table containing the loaded configs
-- @field enabled - Whether to load/process this type of config. Useful for debugging/testing
-- @field moduleDependencies - Table list of modules which need to be loaded before this type of config is loaded
-- @field loaded - Whether the route has already been loaded
-- @field loadFunction - Function which is called when the config type will be loaded. Must take in a single param: the config to load!

-- DNE: This module doesn't exist, it's just a quick testing hack
local routes = {
	gameObject = {
		path = "/hammerstone/objects/",
		dbTable = objectDB.objectConfigs,
		enabled = true,
		loaded = false,
		moduleDependencies = {
			"dne"
		}
	},
	storage = {
		path = "/hammerstone/storage/",
		dbTable = objectDB.storageConfigs,
		enabled = true,
		loaded = false,
		moduleDependencies = {
			"storage"
		},
		loadFunction = "generateStorageObject" -- TODO: Strings as functions :()
	},
	recipe = {
		path = "/hammerstone/recipes/",
		dbTable = objectDB.recipeConfigs,
		enabled = false,
		loaded = false,
		moduleDependencies = {"dne"}
	},
	material = {
		path = "/hammerstone/materials/",
		dbTable = objectDB.materialConfigs,
		enabled = true,
		loaded = false,
		moduleDependencies = {"dne"}
	},
	skill = {
		path = "/hammerstone/skills/",
		dbTable = objectDB.skillConfigs,
		enabled = false,
		loaded = false,
		moduleDependencies = {"dne"}
	}
}

-- Guards against the same code being run multiple times.
-- Takes in a unique ID to identify this code
local runOnceGuards = {}
local function runOnceGuard(guard)
	if runOnceGuards[guard] == nil then
		runOnceGuards[guard] = true
		return false
	end
	return true
end

-- TODO: Consider using metaTables to add default values to the objectDB
-- local mt = {
-- 	__index = function ()
-- 		return "10"
-- 	end
-- }
-- setmetatable(objectDB.objectConfigs, mt)

-- Sapiens
local typeMaps = moduleManager:get("typeMaps")
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
local utils = mjrequire "hammerstone/object/objectUtils" -- TOOD: Are we happy name-bungling imports?

---------------------------------------------------------------------------------
-- Configuation and Loading
---------------------------------------------------------------------------------

local function newModuleAdded(modules)
	objectManager:tryLoadObjectDefinitions()
end

moduleManager:bind(newModuleAdded)

-- Initialize the full Data Driven API (DDAPI).
function objectManager:init()
	if runOnceGuard("ddapi") then return end

	--local now = os.time()
	log:schema("ddapi", os.date())

	log:log("\nInitializing DDAPI...")
	log:schema("ddapi", "\nInitializing DDAPI...")

	-- Load configs from FS
	objectManager:loadConfigs()
	-- objectManager:generateResourceDefinitions()

	-- generateMaterialDefinitions is called internally, from `material.lua`.
	-- generateResourceDefinitions is called internally, from `resource.lua`.
	-- generateGameObjects is called internally, from `gameObject.lua`.
	-- generateStorageObjects is called internally, from `gameObject.lua`.
	-- generateEvolvingObjects is called internally, from `evolvingObject.lua`.
	-- generateRecipeDefinitions is called internally, from `craftable.lua`.
end

-- Loops over known config locations and attempts to load them
function objectManager:loadConfigs()
	configsLoadedFromFS = true
	log:schema("ddapi", "Loading configuration files:")

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0; local disabledCount = 0

	for i, mod in ipairs(mods) do
		for _, route in pairs(routes) do
			if route.enabled then
				local objectConfigDir = mod.path .. route.path
				local configs = fileUtils.getDirectoryContents(objectConfigDir)
				for j, config in ipairs(configs) do
					local fullPath =  objectConfigDir .. config
					count = count + 1;

					objectManager:loadConfig(fullPath, route.dbTable)
				end
			else
				disabledCount = disabledCount + 1
			end
		end
	end

	log:schema("ddapi", "Loaded configs totalling: " .. count)

	if disabledCount ~= 0 then
		log:schema("ddapi", "Disabled configs totalling: " .. disabledCount)
		log:schema("ddapi", "Disabled configs:")
		for _, route in pairs(routes) do
			if not route.enabled then
				log:schema("ddapi", "  " .. route.path)
			end
		end
	end
end

--- Loads a single config from the filesystem and decodes it from json to lua
-- @param path
-- @param type
function objectManager:loadConfig(path, type)
	log:schema("ddapi", "  " .. path)
	local configString = fileUtils.getFileContents(path)
	local configTable = json:decode(configString)
	table.insert(type, configTable)
end


local function canLoadObjectType(routeName, route)
	-- Wait for configs to be loaded from the FS
	if configsLoadedFromFS == false then
		return false
	end

	-- Don't double-load objects
	if route.loaded == true then
		return false
	end

	-- Don't load until all dependencies are satisfied.
	for i, moduleDependency in pairs(route.moduleDependencies) do
		if moduleManager.modules[moduleDependency] == nil then
			return false
		end
	end

	-- If checks pass, then we can load the object
	route.loaded = true
	return true
end

--- Attempts to load all object definitions
-- Prevents duplicates
function objectManager:tryLoadObjectDefinitions()
	mj:log("Attempting to load new object definitions:")
	for routeName, route in pairs(routes) do
		if canLoadObjectType(routeName, route) then
			objectManager:loadObjectDefinition(routeName, route)
		end
	end
end

-- Loads a single object
function objectManager:loadObjectDefinition(routeName, route)
	log:schema("ddapi", "\nGenerating " .. routeName .. " definitions:")

	local configs = route.dbTable
	if configs ~= nil and #route.dbTable ~= 0 then
		for i, config in ipairs(route.dbTable) do
			mj:log(route)
			mj:log(config)
			objectManager[route.loadFunction](self, config) --Wtf oh my god
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions()
	if runOnceGuard("resource") then return end
	log:schema("ddapi", "\nGenerating Resource definitions:")

	if objectDB.objectConfigs ~= nil and #objectDB.objectConfigs ~= 0 then
		for i, config in ipairs(objectDB.objectConfigs) do
			objectManager:generateResourceDefinition(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateResourceDefinition(config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate a resource definition that is nil.")
		return
	end

	local objectDefinition = config["hammerstone:object_definition"]
	local description = objectDefinition["description"]
	local components = objectDefinition["components"]
	local identifier = description["identifier"]

	-- Resource links prevent a *new* resource from being generated.
	local resourceLinkComponent = components["hammerstone:resource_link"]
	if resourceLinkComponent ~= nil then
		log:schema("ddapi", "GameObject " .. identifier .. " linked to resource " .. resourceLinkComponent.identifier .. ". No unique resource created.")
		return
	end

	log:schema("ddapi", "  " .. identifier)

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
	moduleManager:get("resource"):addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

--- Generates DDAPI storage objects.
function objectManager:generateStorageObjects()
	if runOnceGuard("storage") then return end
	log:schema("ddapi", "\nGenerating Storage definitions:")

	if objectDB.storageConfigs ~= nil and #objectDB.storageConfigs ~= 0 then
		for i, config in ipairs(objectDB.storageConfigs) do
			objectManager:generateStorageObject(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

--- Special helper function to generate the resource IDs that a storage should use, once they are available.
--- This is a workaround :L
function objectManager:generateResourceForStorage(storageIdentifier)

	local newResource = {}

	local objectIdentifiers = objectDB.objectsForStorage[storageIdentifier]
	if objectIdentifiers ~= nil then
		for i, identifier in ipairs(objectIdentifiers) do
			table.insert(newResource, moduleManager:get("resource").types[identifier].index)
		end
	else
		log:schema("ddapi", "WARNING: Storage " .. storageIdentifier .. " is being generated with zero items. This is most likely a mistake.")
		log:schema("ddapi", "Available data:")
		log:schema("ddapi", objectDB.objectsForStorage)
	end

	return newResource
end

function objectManager:generateStorageObject(config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate nil StorageObject!")
		return
	end

	-- Modules
	local storageModule = moduleManager:get("storage")

	-- Load structured information
	local storageDefinition = config["hammerstone:storage_definition"]
	local description = storageDefinition["description"]
	local storageComponent = storageDefinition.components["hammerstone:storage"]
	local carryComponent = storageDefinition.components["hammerstone:carry"]

	local gameObjectTypeIndexMap = typeMaps.types.gameObject

	local identifier = utils:getField(description, "identifier")

	log:schema("ddapi", "  " .. identifier)

	-- Prep
	local random_rotation = utils:getField(storageComponent, "random_rotation_weight", {
		default = 2.0
	})
	local rotation = utils:getVec3(storageComponent, "rotation", {
		default = vec3(0.0, 0.0, 0.0)
	})

	local carryCounts = utils:getTable(carryComponent, "carry_count", {
		default = {} -- Allow this field to be undefined, but don't use nil
	})
	
	local newStorage = {
		key = identifier,
		name = utils:getField(description, "name"),

		displayGameObjectTypeIndex = gameObjectTypeIndexMap[utils:getField(storageComponent, "preview_object")],
		
		-- TODO: This needs to be reworked to make sure that it's possible to reference vanilla resources here (?)
		resources = objectManager:generateResourceForStorage(identifier),

		storageBox = {
			size =  utils:getVec3(storageComponent, "size", {
				default = vec3(0.5, 0.5, 0.5)
			}),
			
			-- TODO consider giving more control here
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rot = mat3Rotate(mat3Identity, randomValue * random_rotation, rotation)
				return rot
			end,

			dontRotateToFitBelowSurface = utils:getField(storageComponent, "rotate_to_fit_below_surface", {
				default = true,
				type = "boolean"
			}),
			
			placeObjectOffset = mj:mToP(utils:getVec3(storageComponent, "offset", {
				default = vec3(0.0, 0.0, 0.0)
			}))
		},

		maxCarryCount = utils:getField(carryCounts, "normal", {default=1}),
		maxCarryCountLimitedAbility = utils:getField(carryCounts, "limited_ability", {default=1}),
		maxCarryCountForRunning = utils:getField(carryCounts, "running", {default=1}),

		carryStackType = storageModule.stackTypes[utils:getField(carryComponent, "stack_type", {default="standard"})],
		carryType = storageModule.carryTypes[utils:getField(carryComponent, "carry_type", {default="standard"})],

		carryOffset = utils:getVec3(carryComponent, "offset", {
			default = vec3(0.0, 0.0, 0.0)
		}),

		carryRotation = mat3Rotate(mat3Identity,
			utils:getField(carryComponent, "rotation_constant", { default = 1}),
			utils:getVec3(carryComponent, "rotation", { default = vec3(0.0, 0.0, 0.0)})
		),
	}

	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

function objectManager:generateEvolvingObjects()
	if runOnceGuard("evolving") then return end
	log:schema("ddapi", "\nGenerating EvolvingObjects:")

	if objectDB.objectConfigs ~= nil and #objectDB.objectConfigs ~= 0 then
		for i, config in ipairs(objectDB.objectConfigs) do
			objectManager:generateEvolvingObject(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateEvolvingObject(config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate nil EvolvingObject.")
		return
	end

	local evolvingObject = moduleManager:get("evolvingObject")

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:evolving_object"]
	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
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
				table.insert(newResource, moduleManager:get("gameObject").types[identifier].index)
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

function objectManager:generateHarvestableObjects()
	if runOnceGuard("harvestable") then return end
	log:schema("ddapi", "\nGenerating Harvestable Objects:")

	if objectDB.objectConfigs ~= nil and #objectDB.objectConfigs ~= 0 then
		for i, config in ipairs(objectDB.objectConfigs) do
			objectManager:generateHarvestableObject(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateHarvestableObject(config)
	local harvestableModule = moduleManager:get("harvestable") -- This will crash until we actuall provide this

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:harvestable"]
	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
	end

	-- TODO: Make this smart, and can handle day length OR year length.
	-- It claims it reads it as lua (schema), but it actually just multiplies it by days.
	local newEvolvingObject = {
		minTime = moduleManager:get("evolvingObject").dayLength * evolvingObjectComponent.min_time,
		categoryIndex = moduleManager:get("evolvingObject").categories[evolvingObjectComponent.category].index,
	}

	if evolvingObjectComponent.transform_to ~= nil then
		local function generateTransformToTable(transform_to)
			local newResource = {}
			for i, identifier in ipairs(transform_to) do
				table.insert(newResource, moduleManager:get("gameObject").types[identifier].index)
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

	-- Insert the object identifier for this storage container
	table.insert(objectDB.objectsForStorage[storageIdentifier], identifier)
end

function objectManager:generateGameObjects()
	if runOnceGuard("gameObjects") then return end
	log:schema("ddapi", "\nGenerating Object definitions:")

	if objectDB.objectConfigs ~= nil and #objectDB.objectConfigs ~= 0 then
		for i, config in ipairs(objectDB.objectConfigs) do
			objectManager:generateGameObject(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateGameObject(config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate nil GameObject.")
		return
	end

	local object_definition = config["hammerstone:object_definition"]
	local description = object_definition["description"]
	local components = object_definition["components"]
	local objectComponent = components["hammerstone:object"]
	local identifier = description["identifier"]
	log:schema("ddapi", "  " .. identifier)

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

	-- If resource link doesn't exist, don't crash the game
	local resourceIndex = utils:getTypeIndex(moduleManager:get("resource").types, resourceIdentifier, "Resource")
	if resourceIndex == nil then return end

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
		resourceTypeIndex = resourceIndex,

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Actually register the game object
	moduleManager:get("gameObject"):addGameObject(identifier, newObject)
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------

--- Generates recipe definitions based on the loaded config, and registers them.
function objectManager:generateRecipeDefinitions()
	if runOnceGuard("recipe") then return end
	log:schema("ddapi", "\nGenerating Recipe definitions:")

	if objectDB.recipeConfigs ~= nil and #objectDB.recipeConfigs ~= 0 then
		for i, config in ipairs(objectDB.recipeConfigs) do
			objectManager:generateRecipeDefinition(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateRecipeDefinition(config)

	if config == nil then
		log:schema("ddapi", "  Warning! Attempting to generate a recipe definition that is nil.")
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

	log:schema("ddapi", "  " .. identifier)

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

	local data = utils:compile(required, {

		-- Description
		identifier = utils:getField(description, "identifier", {
			notInTypeTable = moduleManager:get("craftable").types
		}),
		name = utils:getField(description, "name"),
		plural = utils:getField(description, "plural"),
		summary = utils:getField(description, "summary"),


		-- Recipe Component
		iconGameObjectType = utils:getField(recipe, "preview_object", {
			inTypeTable = moduleManager:get("gameObject").types
		}),
		classification = utils:getField(recipe, "classification", {
			inTypeTable = moduleManager:get("constructable").classifications -- Why is this crashing?
		}),
		isFoodPreperation = utils:getField(recipe, "isFoodPreparation", {
			type = "boolean"
		}),


		-- Output Component
		outputObjectInfo = {
			outputArraysByResourceObjectType = utils:getTable(output, "output_by_object", {
				with = function(tbl)
					local result = {}
					for _, value in pairs(tbl) do -- Loop through all output objects
						
						-- Return if input isn't a valid gameObject
						if utils:getTypeIndex(moduleManager:get("gameObject").types, value.input, "Game Object") == nil then return end

						-- Get the input's resource index
						local index = moduleManager:get("gameObject").types[value.input].index

						-- Convert from schema format to vanilla format
						-- If the predicate returns nil for any element, map returns nil
						-- In this case, log an error and return if any output item does not exist in gameObject.types
						result[index] = utils:map(value.output, function(e)
							return utils:getTypeIndex(moduleManager:get("gameObject").types, e, "Game Object")
						end)
					end
					return result
				end
			}),
		},


		-- Requirements Component
		skills = utils:getTable(requirements, "skills", {
			inTypeTable = moduleManager:get("skill").types,
			with = function(tbl)
				if #tbl > 0 then
					return {
						required = moduleManager:get("skill").types[tbl[1] ].index
					}
				end
			end
		}),
		disabledUntilAdditionalSkillTypeDiscovered = utils:getTable(requirements, "skills", {
			inTypeTable = moduleManager:get("skill").types,
			with = function(tbl)
				if #tbl > 1 then
					return moduleManager:get("skill").types[tbl[2] ].index
				end
			end
		}),
		requiredCraftAreaGroups = utils:getTable(requirements, "craft_area_groups", {
			map = function(e)
				return utils:getTypeIndex(moduleManager:get("craftAreaGroup").types, e, "Craft Area Group")
			end
		}),
		requiredTools = utils:getTable(requirements, "tools", {
			map = function(e)
				return utils:getTypeIndex(moduleManager:get("tool").types, e, "Tool")
			end
		}),


		-- Build Sequence Component
		inProgressBuildModel = utils:getField(build_sequence, "build_sequence_model"),
		buildSequence = utils:getTable(build_sequence, "build_sequence", {
			with = function(tbl)
				if not utils:isEmpty(tbl.steps) then
					-- If steps exist, we create a custom build sequence instead a standard one
					logNotImplemented("Custom Build Sequence") -- TODO: Implement steps
				else
					-- Cancel if action field doesn't exist
					if tbl.action == nil then
						return log:schema("ddapi", "    Missing Action Sequence")
					end

					-- Get the action sequence
					local sequence = utils:getTypeIndex(moduleManager:get("actionSequence").types, tbl.action, "Action Sequence")
					if sequence ~= nil then

						-- Cancel if a tool is stated but doesn't exist
						if tbl.tool ~= nil and #tbl.tool > 0 and utils:getTypeIndex(moduleManager:get("tool").types, tbl.tool, "Tool") == nil then
							return
						end

						-- Return the standard build sequence constructor
						return moduleManager:get("craftable"):createStandardBuildSequence(sequence, tbl.tool)
					end
				end
			end
		}),
		requiredResources = utils:getTable(build_sequence, "resource_sequence", {
			-- Runs for each item and replaces item with return result
			map = function(e)

				-- Get the resource
				local res = utils:getTypeIndex(moduleManager:get("resource").types, e.resource, "Resource")
				if (res == nil) then return end -- Cancel if resource does not exist

				-- Get the count
				local count = e.count or 1
				if (not utils:isType(count, "number")) then
					return log:schema("ddapi", "    Resource count for " .. e.resource .. " is not a number")
				end

				if e.action ~= nil then

					-- Return if action is invalid
					local actionType = utils:getTypeIndex(moduleManager:get("action").types, e.action.action_type, "Action")
					if (actionType == nil) then return end

					-- Return if duration is invalid
					local duration = e.action.duration
					if (not utils:isType(duration, "number")) then
						return log:schema("ddapi", "    Duration for " .. e.action.action_type .. " is not a number")
					end

					-- Return if duration without skill is invalid
					local durationWithoutSkill = e.action.duration_without_skill or duration
					if (not utils:isType(durationWithoutSkill, "number")) then
						return log:schema("ddapi", "    Duration without skill for " .. e.action.action_type .. " is not a number")
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
		moduleManager:get("craftable"):addCraftable(identifier, data)

		-- Add items in crafting panels
		for _, group in ipairs(data.requiredCraftAreaGroups) do
			local key = moduleManager:get("gameObject").typeIndexMap[moduleManager:get("craftAreaGroup").types[group].key]
			if objectManager.inspectCraftPanelData[key] == nil then
				objectManager.inspectCraftPanelData[key] = {}
			end
			table.insert(objectManager.inspectCraftPanelData[key], moduleManager:get("constructable").types[identifier].index)
		end
	end
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

--- Generates material definitions based on the loaded config, and registers them.
function objectManager:generateMaterialDefinitions()
	if runOnceGuard("material") then return end
	log:schema("ddapi", "\nGenerating Material definitions:")

	if objectDB.materialConfigs ~= nil and #objectDB.materialConfigs ~= 0 then
		for i, config in ipairs(objectDB.materialConfigs) do
			objectManager:generateMaterialDefinition(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateMaterialDefinition(config)
	local materialDefinition = config["hammerstone:material_definition"]
	local materials = materialDefinition["materials"]

	for _, mat in pairs(materials) do

		log:schema("ddapi", "  " .. mat["identifier"])

		local required = {
			identifier = true,
			color = true,
			roughness = true,
			metal = false,
		}

		local data = utils:compile(required, {

			identifier = utils:getField(mat, "identifier", {
				notInTypeTable = moduleManager:get("material").types
			}),

			color = utils:getVec3(mat, "color"),
			
			roughness = utils:getField(mat, "roughness", {
				type = "number"
			}),

			metal = utils:getField(mat, "metal", {
				type = "number"
			})
		})

		if data ~= nil then
			moduleManager:get("material"):addMaterial(data.identifier, data.color, data.roughness, data.metal)
		end
	end
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

--- Generates skill definitions based on the loaded config, and registers them.
function objectManager:generateSkillDefinitions()
	if runOnceGuard("skill") then return end
	log:schema("ddapi", "\nGenerating Skill definitions:")

	if objectDB.skillConfigs ~= nil and #objectDB.skillConfigs ~= 0 then
		for i, config in ipairs(objectDB.skillConfigs) do
			objectManager:generateSkillDefinition(config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateSkillDefinition(config)

	if config == nil then
		log:schema("ddapi", "  Warning! Attempting to generate a skill definition that is nil.")
		return
	end
	
	local skillDefinition = config["hammerstone:skill_definition"]
	local skills = skillDefinition["skills"]

	for _, s in pairs(skills) do

		local desc = s["description"]
		local skil = s["skill"]

		log:schema("ddapi", "  " .. desc["identifier"])

		local required = {
			identifier = true,
			name = true,
			description = true,
			icon = true,

			row = true,
			column = true,
			requiredSkillTypes = false,
			startLearned = false,
			partialCapacityWithLimitedGeneralAbility = false,
		}

		local data = utils:compile(required, {

			identifier = utils:getField(desc, "identifier", {
				notInTypeTable = moduleManager:get("skill").types
			}),
			name = utils:getField(desc, "name"),
			description = utils:getField(desc, "description"),
			icon = utils:getField(desc, "icon"),

			row = utils:getField(skil, "row", {
				type = "number"
			}),
			column = utils:getField(skil, "column", {
				type = "number"
			}),
			requiredSkillTypes = utils:getTable(skil, "requiredSkills", {
				-- Make sure each skill exists and transform skill name to index
				map = function(e) return utils:getTypeIndex(moduleManager:get("skill").types, e, "Skill") end
			}),
			startLearned = utils:getField(skil, "startLearned", {
				type = "boolean"
			}),
			partialCapacityWithLimitedGeneralAbility = utils:getField(skil, "impactedByLimitedGeneralAbility", {
				type = "boolean"
			}),
		})

		if data ~= nil then
			moduleManager:get("skill"):addSkill(data.identifier, data)
		end
	end
end

return objectManager