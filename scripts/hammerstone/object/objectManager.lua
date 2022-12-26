--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich

local objectManager = {
	modules = {},
	loadedConfigs = {},
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
local utils = mjrequire "hammerstone/object/objectUtils" -- TOOD: Are we happy name-bungling imports?

---------------------------------------------------------------------------------
-- Configuation and Loading
---------------------------------------------------------------------------------

-- Initialize the full Data Driven API (DDAPI).
function objectManager:init()

	-- Only do this once
	if objectManager.loadedConfigs["init"] ~= nil then
		mj:warn("Attempting to re-initialize objectManager DDAPI! Skipping.")
		return
	end
	objectManager.loadedConfigs["init"] = true

	--local now = os.time()
	log:schema("ddapi", os.date())

	log:log("\nInitializing DDAPI...")
	log:schema("ddapi", "\nInitializing DDAPI...")

	-- Load configs from FS
	objectManager:loadConfigs()
	objectManager:generateResourceDefinitions()

	-- generateMaterialDefinitions is called internally, from `material.lua`.
	-- generateResourceDefinitions is called internally, from `resource.lua`.
	-- generateGameObjects is called internally, from `gameObject.lua`.
	-- generateStorageObjects is called internally, from `gameObject.lua`.
	-- generateEvolvingObjects is called internally, from `evolvingObject.lua`.
	-- generateRecipeDefinitions is called internally, from `craftable.lua`.
end

-- Loops over known config locations and attempts to load them
function objectManager:loadConfigs()

	log:schema("ddapi", "Loading configuration files:")

	local routes = {
		{
			path = "/hammerstone/objects/",
			dbTable = objectDB.objectConfigs,
			enabled = true,
		},
		{
			path = "/hammerstone/storage/",
			dbTable = objectDB.storageConfigs,
			enabled = true,
		},
		{
			path = "/hammerstone/recipes/",
			dbTable = objectDB.recipeConfigs,
			enabled = false,
		},
		{
			path = "/hammerstone/materials/",
			dbTable = objectDB.materialConfigs,
			enabled = true,
		},
		{
			path = "/hammerstone/skills/",
			dbTable = objectDB.skillConfigs,
			enabled = false,
		}
	}

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

function objectManager:loadConfig(path, type)
	log:schema("ddapi", "  " .. path)
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
-- Resource
---------------------------------------------------------------------------------

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions(mods)

	-- Only do this once
	if objectManager.loadedConfigs["resource"] ~= nil then return end
	objectManager.loadedConfigs["resource"] = true

	addModules(mods)

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
	modules.resource:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

--- Generates DDAPI storage objects.
function objectManager:generateStorageObjects()

	-- Only do this once
	if objectManager.loadedConfigs["storage"] ~= nil then return end
	objectManager.loadedConfigs["storage"] = true

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
			table.insert(newResource, modules.resource.types[identifier].index)
		end
	else
		log:schema("ddapi", "WARNING: Storage " .. storageIdentifier .. " is being generated with zero items. This is most likely a mistake.")
	end

	return newResource
end

function objectManager:generateStorageObject(config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate nil Storage Object.")
		return
	end

	-- Load structured information
	local storageDefinition = config["hammerstone:storage_definition"]
	local description = storageDefinition["description"]
	local storageComponent = storageDefinition.components["hammerstone:storage"]
	local carryComponent = storageDefinition.components["hammerstone:carry"]

	local gameObjectTypeIndexMap = typeMaps.types.gameObject

	local identifier = utils:getField(description, "identifier")

	-- TODO no local imports
	local storage = mjrequire "common/storage"

	log:schema("ddapi", "  " .. identifier)

	-- Inlined imports. Bad style. I don't care.
	local resource = mjrequire "common/resource";

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

		carryStackType = storage.stackTypes[utils:getField(carryComponent, "stack_type", {default="standard"})],
		carryType = storage.carryTypes[utils:getField(carryComponent, "carry_type", {default="standard"})],

		carryOffset = utils:getVec3(carryComponent, "offset", {
			default = vec3(0.0, 0.0, 0.0)
		}),

		carryRotation = mat3Rotate(mat3Identity,
			utils:getField(carryComponent, "rotation_constant", { default = 1}),
			utils:getVec3(carryComponent, "rotation", { default = vec3(0.0, 0.0, 0.0)})
		),
	}

	-- TODO: No local imports
	local storageModule = mjrequire "common/storage"
	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

function objectManager:generateEvolvingObjects(mods)

	-- Only do this once
	if objectManager.loadedConfigs["evolving"] ~= nil then return end
	objectManager.loadedConfigs["evolving"] = true
	
	addModules(mods)

	log:schema("ddapi", "\nGenerating EvolvingObjects:")

	if objectDB.objectConfigs ~= nil and #objectDB.objectConfigs ~= 0 then
		for i, config in ipairs(objectDB.objectConfigs) do
			objectManager:generateEvolvingObject(evolvingObject, config)
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

function objectManager:generateEvolvingObject(evolvingObject, config)
	if config == nil then
		log:schema("ddapi", "WARNING: Attempting to generate nil EvolvingObject.")
		return
	end

	local evolvingObject = modules.evolvingObject

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

	-- Only do this once
	if objectManager.loadedConfigs["harvestable"] ~= nil then return end
	objectManager.loadedConfigs["harvestable"] = true

	addModules(mods)

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
	local harvestableModule = modules.harvestable -- This will crash until we actuall provide this

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

	-- Only do this once
	if objectManager.loadedConfigs["gameObjects"] ~= nil then return end
	objectManager.loadedConfigs["gameObjects"] = true

	addModules(mods)

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
	--local resourceIndex = utils:getTypeIndex(modules.resource.types, resourceIdentifier, "Resource")
	--if resourceIndex == nil then return end

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
	modules.gameObject:addGameObject(identifier, newObject)
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------

--- Generates recipe definitions based on the loaded config, and registers them.
function objectManager:generateRecipeDefinitions(mods)

	-- Only do this once
	if objectManager.loadedConfigs["recipe"] ~= nil then return end
	objectManager.loadedConfigs["recipe"] = true

	addModules(mods)

	modules.action = mjrequire "common/action"
	modules.actionSequence = mjrequire "common/actionSequence"
	modules.tool = mjrequire "common/tool"
	
	modules.craftAreaGroup = mjrequire "common/craftAreaGroup"
	modules.constructable = mjrequire "common/constructable"
	modules.skill = mjrequire "common/skill"

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
			notInTypeTable = modules.craftable.types
		}),
		name = utils:getField(description, "name"),
		plural = utils:getField(description, "plural"),
		summary = utils:getField(description, "summary"),


		-- Recipe Component
		iconGameObjectType = utils:getField(recipe, "preview_object", {
			inTypeTable = modules.gameObject.types
		}),
		classification = utils:getField(recipe, "classification", {
			inTypeTable = modules.constructable.classifications -- Why is this crashing?
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
						if utils:getTypeIndex(modules.gameObject.types, value.input, "Game Object") == nil then return end

						-- Get the input's resource index
						local index = modules.gameObject.types[value.input].index

						-- Convert from schema format to vanilla format
						-- If the predicate returns nil for any element, map returns nil
						-- In this case, log an error and return if any output item does not exist in gameObject.types
						result[index] = utils:map(value.output, function(e)
							return utils:getTypeIndex(modules.gameObject.types, e, "Game Object")
						end)
					end
					return result
				end
			}),
		},


		-- Requirements Component
		skills = utils:getTable(requirements, "skills", {
			inTypeTable = modules.skill.types,
			with = function(tbl)
				if #tbl > 0 then
					return {
						required = modules.skill.types[tbl[1] ].index
					}
				end
			end
		}),
		disabledUntilAdditionalSkillTypeDiscovered = utils:getTable(requirements, "skills", {
			inTypeTable = modules.skill.types,
			with = function(tbl)
				if #tbl > 1 then
					return modules.skill.types[tbl[2] ].index
				end
			end
		}),
		requiredCraftAreaGroups = utils:getTable(requirements, "craft_area_groups", {
			map = function(e)
				return utils:getTypeIndex(modules.craftAreaGroup.types, e, "Craft Area Group")
			end
		}),
		requiredTools = utils:getTable(requirements, "tools", {
			map = function(e)
				return utils:getTypeIndex(modules.tool.types, e, "Tool")
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
					local sequence = utils:getTypeIndex(modules.actionSequence.types, tbl.action, "Action Sequence")
					if sequence ~= nil then

						-- Cancel if a tool is stated but doesn't exist
						if tbl.tool ~= nil and #tbl.tool > 0 and utils:getTypeIndex(modules.tool.types, tbl.tool, "Tool") == nil then
							return
						end

						-- Return the standard build sequence constructor
						return modules.craftable:createStandardBuildSequence(sequence, tbl.tool)
					end
				end
			end
		}),
		requiredResources = utils:getTable(build_sequence, "resource_sequence", {
			-- Runs for each item and replaces item with return result
			map = function(e)

				-- Get the resource
				local res = utils:getTypeIndex(modules.resource.types, e.resource, "Resource")
				if (res == nil) then return end -- Cancel if resource does not exist

				-- Get the count
				local count = e.count or 1
				if (not utils:isType(count, "number")) then
					return log:schema("ddapi", "    Resource count for " .. e.resource .. " is not a number")
				end

				if e.action ~= nil then

					-- Return if action is invalid
					local actionType = utils:getTypeIndex(modules.action.types, e.action.action_type, "Action")
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
function objectManager:generateMaterialDefinitions(mods)

	-- Only do this once
	if objectManager.loadedConfigs["material"] ~= nil then return end
	objectManager.loadedConfigs["material"] = true

	addModules(mods)

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
				notInTypeTable = modules.material.types
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
			modules.material:addMaterial(data.identifier, data.color, data.roughness, data.metal)
		end
	end
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

--- Generates skill definitions based on the loaded config, and registers them.
function objectManager:generateSkillDefinitions(mods)

	-- Only do this once
	if objectManager.loadedConfigs["skill"] ~= nil then return end
	objectManager.loadedConfigs["skill"] = true

	addModules(mods)

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
				notInTypeTable = modules.skill.types
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
				map = function(e) return utils:getTypeIndex(modules.skill.types, e, "Skill") end
			}),
			startLearned = utils:getField(skil, "startLearned", {
				type = "boolean"
			}),
			partialCapacityWithLimitedGeneralAbility = utils:getField(skil, "impactedByLimitedGeneralAbility", {
				type = "boolean"
			}),
		})

		if data ~= nil then
			modules.skill:addSkill(data.identifier, data)
		end
	end
end

return objectManager