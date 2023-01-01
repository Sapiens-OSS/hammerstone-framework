--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich, earmuffs

local objectManager = {
	inspectCraftPanelData = {},

	-- Map between storage identifiers and object IDENTIFIERS that should use this storage.
	-- Collected when generating objects, and inserted when generating storages (after converting to index)
	-- @format map<string, array<string>>.
	objectsForStorage = {},
}

-- Sapiens
local rng = mjrequire "common/randomNumberGenerator"

-- Math
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/object/objectUtils" -- TOOD: Are we happy name-bungling imports?
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local configLoader = mjrequire "hammerstone/object/configLoader"
local objectDB = configLoader.configs

---------------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------------

local crashes = true

---------------------------------------------------------------------------------
-- Configuation and Loading
---------------------------------------------------------------------------------

--- Data structure which defines how a config is loaded, and in which order. 
-- @field configSource - Table to store loaded config data.
-- @field configPath - Path to the folder where the config files can be read. Multiple objects can be generated from the same file.
-- Each route here maps to a FILE TYPE. The fact that 
-- file type has no impact herre.
-- @field moduleDependencies - Table list of modules which need to be loaded before this type of config is loaded
-- @field loaded - Whether the route has already been loaded
-- @field loadFunction - Function which is called when the config type will be loaded. Must take in a single param: the config to load!
-- @field waitingForStart - Whether this config is waiting for a custom trigger or not.
local objectLoader = {

	storage = {
		configSource = objectDB.storageConfigs,
		configPath = "/hammerstone/storage/",
		moduleDependencies = {
			"storage"
		},
		loadFunction = "generateStorageObject" -- TODO: Find out how to run a function without accessing it via string
	},

	evolvingObject = {
		configSource = objectDB.objectConfigs,
		waitingForStart = true,
		moduleDependencies = {
			"evolvingObject",
			"gameObject"
		},
		loadFunction = "generateEvolvingObject"
	},

	material = {
		configSource = objectDB.materialConfigs,
		configPath = "/hammerstone/materials/",
		moduleDependencies = {
			"material"
		},
		loadFunction = "generateMaterialDefinition"
	},

	resource = {
		configSource = objectDB.objectConfigs,
		moduleDependencies = {
			"typeMaps",
			"resource"
		},
		loadFunction = "generateResourceDefinition"
	},

	gameObject = {
		configSource = objectDB.objectConfigs,
		configPath = "/hammerstone/objects/",
		waitingForStart = true,
		moduleDependencies = {
			"resource",
			"gameObject",
			"tool",
			"harvestable"
		},
		loadFunction = "generateGameObject"
	},

	harvestable = {
		waitingForStart = true,
		configSource = objectDB.objectConfigs,
		dependencies = {
			"gameObject"
		},
		moduleDependencies = {
			"harvestable",
			"gameObject",
			"typeMaps"
		},
		loadFunction = "generateHarvestableObject"
	},

	recipe = {
		configSource = objectDB.recipeConfigs,
		configPath = "/hammerstone/recipes/",
		disabled = false,
		waitingForStart = true,
		moduleDependencies = {
			"gameObject",
			"constructable",
			"craftable",
			"skill",
			"craftAreaGroup",
			"action",
			"actionSequence",
			"tool",
			"resource"
		},
		loadFunction = "generateRecipeDefinition"
	},

	planHelper = {
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		configSource = objectDB.objectConfigs,
		loadFunction = "generatePlanHelperObject",
		dependencies = {
			"gameObject"
		},
		moduleDependencies = {
			"planHelper"
		}
	},

	skill = {
		configSource = objectDB.skillConfigs,
		configPath = "/hammerstone/skills/",
		disabled = true,
		moduleDependencies = {
			"skill"
		},
		loadFunction = "generateSkillDefinition"
	}
}


local function newModuleAdded(modules)
	objectManager:tryLoadObjectDefinitions()
end

moduleManager:bind(newModuleAdded)

-- Initialize the full Data Driven API (DDAPI).
function objectManager:init()
	if utils:runOnceGuard("ddapi") then return end

	log:schema("ddapi", os.date() .. "\n")


	local logID = log:schema("ddapi", "Initializing DDAPI...")
	log:schema(logID, "\nInitialized DDAPI.")
	log:append(logID, "test")
	log:remove(logID)


	-- Load configs from FS
	configLoader:loadConfigs(objectLoader)
end


local function canLoadObjectType(objectName, objectData)
	-- Wait for configs to be loaded from the FS
	if configLoader.isInitialized == false then
		return false
	end

	-- Some routes wait for custom start logic. Don't start these until triggered!
	if objectData.waitingForStart == true then
		return false
	end
	
	-- Don't enable disabled modules
	if objectData.disabled then
		return false
	end

	-- Don't double-load objects
	if objectData.loaded == true then
		return false
	end

	-- Don't load until all moduleDependencies are satisfied.
	for i, moduleDependency in pairs(objectData.moduleDependencies) do
		if moduleManager.modules[moduleDependency] == nil then
			return false
		end
	end

	-- Don't load until all dependencies are satisfied (dependent types loaded first!)
	if objectData.dependencies ~= nil then
		for i, dependency in pairs(objectData.dependencies) do
			if objectLoader[dependency].loaded ~= true then
				return false
			end
		end
	end

	-- If checks pass, then we can load the object
	objectData.loaded = true
	return true
end

--- Marks an object type as ready to load. 
-- @param configName the name of the config which is being marked as ready to load
function objectManager:markObjectAsReadyToLoad(configName)
	-- log:schema("ddapi", "Object is now ready to start loading: " .. configName)
	objectLoader[configName].waitingForStart = false
	objectManager:tryLoadObjectDefinitions() -- Re-trigger start logic, in case no more modules will be loaded.
end

--- Attempts to load object definitions from the objectLoader
function objectManager:tryLoadObjectDefinitions()
	for key, value in pairs(objectLoader) do
		if canLoadObjectType(key, value) then
			objectManager:loadObjectDefinition(key, value)
		end
	end
end

-- Loads a single object
function objectManager:loadObjectDefinition(objectName, objectData)
	log:schema("ddapi", string.format("\nGenerating %s definitions:", objectName))
	local configs = objectData.configSource
	if configs ~= nil and #configs ~= 0 then
		for i, config in ipairs(configs) do
			if config then

				-- Happy path

				local function errorhandler(error)
					log:schema("ddapi", "WARNING: Object failed to generate, discarding: " .. objectName)
					log:schema("ddapi", error)
					log:schema("ddapi", "--------")
					log:schema("ddapi", debug.traceback())
					
					if crashes then
						os.exit()
					end
				end
				
				xpcall(objectManager[objectData.loadFunction], errorhandler, self, config)

			else
				log:schema("ddapi", "WARNING: Attempting to generate nil " .. objectName)
			end
		end
	else
		log:schema("ddapi", "  (none)")
	end
end

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

function objectManager:generateResourceDefinition(config)
	-- Modules
	local typeMapsModule = moduleManager:get("typeMaps")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local objectDefinition = config["hammerstone:object_definition"]
	local description = objectDefinition["description"]
	local components = objectDefinition["components"]
	local identifier = description["identifier"]

	log:schema("ddapi", "  " .. identifier)

	-- Resource links prevent a *new* resource from being generated.
	local resourceComponent = components["hammerstone:resource"]
	if utils:getField(resourceComponent, "create_resource", {optional = true}) ~= true then
		-- log:schema("ddapi", "GameObject " .. identifier .. " linked to resource " .. resourceComponent.identifier .. ". No unique resource created.")
		return -- Abort creation of resource
	end


	local name = description["name"]
	local plural = description["plural"]

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = typeMapsModule.types.gameObject[identifier],
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
	resourceModule:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

--- Special helper function to generate the resource IDs that a storage should use, once they are available.
function objectManager:generateResourceForStorage(storageIdentifier)

	local newResource = {}

	local objectIdentifiers = objectManager.objectsForStorage[storageIdentifier]
	if objectIdentifiers ~= nil then
		for i, identifier in ipairs(objectIdentifiers) do
			table.insert(newResource, moduleManager:get("resource").types[identifier].index)
		end
	else
		log:schema("ddapi", "WARNING: Storage " .. storageIdentifier .. " is being generated with zero items. This is most likely a mistake.")
	end

	return newResource
end

function objectManager:generateStorageObject(config)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Load structured information
	local storageDefinition = config["hammerstone:storage_definition"]
	local description = storageDefinition["description"]
	local storageComponent = storageDefinition.components["hammerstone:storage"]
	local carryComponent = storageDefinition.components["hammerstone:carry"]

	local gameObjectTypeIndexMap = typeMapsModule.types.gameObject

	local identifier = utils:getField(description, "identifier")

	log:schema("ddapi", "  " .. identifier)

	-- Prep
	local random_rotation_weight = utils:getField(storageComponent, "random_rotation_weight", {
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
				local rot = mat3Rotate(mat3Identity, randomValue * random_rotation_weight, rotation)
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
-- Plan Helper
---------------------------------------------------------------------------------

function objectManager:generatePlanHelperObject(config)
	-- Modules
	local planHelperModule = moduleManager:get("planHelper")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local definition = config["hammerstone:object_definition"]
	local description = definition.description
	local plansComponent = definition.components["hammerstone:plans"]

	local objectIndex = utils:getFieldAsIndex(description, "identifier", gameObjectModule.types)
	local availablePlans = utils:getField(plansComponent, "available_plans", {
		optional = true,
		with = function (value)
			return planHelperModule[value]
		end
	})

	-- Nil plans would override desired vanilla plans
	if availablePlans ~= nil then
		planHelperModule:setPlansForObject(objectIndex, availablePlans)
	end

end

---------------------------------------------------------------------------------
-- Harvestable  Object
---------------------------------------------------------------------------------

function objectManager:generateHarvestableObject(config)
	-- Modules
	local harvestableModule = moduleManager:get("harvestable")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local object_definition = config["hammerstone:object_definition"]
	local harvestableComponent = object_definition.components["hammerstone:harvestable"]
	local identifier = object_definition.description.identifier

	if harvestableComponent == nil then
		return -- This is allowed
	else
		log:schema("ddapi", "  " .. identifier)
	end

	local resourcesToHarvest = utils:getTable(harvestableComponent, "resources_to_harvest", {
		map = function(value)
			return gameObjectModule.typeIndexMap[value]
		end
	})
	harvestableModule:addHarvestable(identifier, resourcesToHarvest, 2, 2)
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

--- Generates evolving object definitions. For example an orange rotting into a rotten orange.
function objectManager:generateEvolvingObject(config)
	-- Modules
	local evolvingObjectModule = moduleManager:get("evolvingObject")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:evolving_object"]
	local identifier = object_definition.description.identifier
	
	-- If the component doesn't exist, then simply don't register an evolving object.
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
	end

	-- TODO: Make this smart, and can handle day length OR year length.
	-- It claims it reads it as lua (schema), but it actually just multiplies it by days.
	local newEvolvingObject = {
		minTime = evolvingObjectModule.dayLength * evolvingObjectComponent.min_time,
		categoryIndex = evolvingObjectModule.categories[evolvingObjectComponent.category].index,
	}

	if evolvingObjectComponent.transform_to ~= nil then
		local function generateTransformToTable(transform_to)
			local newResource = {}
			for i, identifier in ipairs(transform_to) do
				table.insert(newResource, gameObjectModule.types[identifier].index)
			end
			return newResource
		end

		newEvolvingObject.toTypes = generateTransformToTable(evolvingObjectComponent.transform_to)
	end

	evolvingObjectModule:addEvolvingObject(identifier, newEvolvingObject)
end

--- Registers an object into a storage.
-- @param identifier - The identifier of the object. e.g., hs:cake
-- @param componentData - The inner-table data for `hammerstone:storage`
function objectManager:registerObjectForStorage(identifier, componentData)

	if componentData == nil then
		return
	end

	-- Initialize this storage container, if this is the first item we're adding.
	local storageIdentifier = componentData.identifier
	if objectManager.objectsForStorage[storageIdentifier] == nil then
		objectManager.objectsForStorage[storageIdentifier] = {}
	end

	-- Insert the object identifier for this storage container
	table.insert(objectManager.objectsForStorage[storageIdentifier], identifier)
end

---------------------------------------------------------------------------------
-- Game Object
---------------------------------------------------------------------------------

-- TODO: selectionGroupTypeIndexes
-- TODO: Implement eatByProducts

-- TODO: These ones are probably for a new component related to world placement.
-- allowsAnyInitialRotation
-- randomMaxScale = 1.5,
-- randomShiftDownMin = -1.0,
-- randomShiftUpMax = 0.5,

function objectManager:generateGameObject(config)
	-- Modules
	local gameObjectModule = moduleManager:get("gameObject")
	local resourceModule = moduleManager:get("resource")
	local toolModule = moduleManager:get("tool")
	local harvestableModule = moduleManager:get("harvestable")

	-- Setup
	local object_definition = config["hammerstone:object_definition"]
	local description = object_definition["description"]
	local identifier = description["identifier"]

	-- Components
	local components = object_definition["components"]
	local objectComponent = components["hammerstone:object"]
	local toolComponent = components["hammerstone:tool"]
	local harvestableComponent = components["hammerstone:harvestable"]
	local resourceComponent = components["hammerstone:resource"]

	log:schema("ddapi", "  " .. identifier)
	
	local resourceIdentifier = nil -- If this stays nil, that just means it's a GOM without a resource, such as animal corpse.
	local resourceTypeIndex = nil
	if resourceComponent ~= nil then

		-- If creating a resource, link ourselves to this identifier
		if resourceComponent.create_resource == true then
			resourceIdentifier = identifier
		end

		-- Otherwise we can link to the requested resource
		if resourceComponent.link_to_resource ~= nil then
			resourceIdentifier = resourceComponent.link_to_resource
		end

		-- Finally, cast to index. This may fail, but that's considered an acceptable error since we can't have both options defined.
		resourceTypeIndex = utils:getTypeIndex(resourceModule.types, resourceIdentifier, "Resource")
	else
		log:schema("ddapi", "    Note: Object is being created without any associated resource. This is only acceptable for things like corpses etc.")
	end

	-- Handle tools
	local toolUsage = {}
	local toolConfigs = utils:getField(toolComponent, "tool_usage", {default = {}})
	for i, config in ipairs(toolConfigs) do
		local toolTypeIndex = utils:getFieldAsIndex(config, "tool_type", toolModule.types)
		toolUsage[toolTypeIndex] = {
			[toolModule.propertyTypes.damage.index] = utils:getField(toolComponent, "damage", {default = 1}),
			[toolModule.propertyTypes.durability.index] = utils:getField(toolComponent, "durability", {default = 1}),
			[toolModule.propertyTypes.speed.index] = utils:getField(toolComponent, "speed", {default = 1}),
		}
	end

	-- TODO: Is this a load order issue?
	-- Handle harvestable
	local harvestableTypeIndex = utils:getField(description, "identifier", {
		with = function (value)
			if harvestableComponent ~= nil then
				return harvestableModule.typeIndexMap[value]
			end
			return nil
		end
	})

	local newGameObject = {
		name = utils:getField(description, "name"),
		plural = utils:getField(description, "plural"),
		modelName = utils:getField(objectComponent, "model"),
		scale = utils:getField(objectComponent, "scale", {default = 1}),
		hasPhysics = utils:getField(objectComponent, "physics", {default = true}),
		resourceTypeIndex = resourceTypeIndex,
		harvestableTypeIndex = harvestableTypeIndex,
		toolUsage = toolUsage,
		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Actually register the game object
	gameObjectModule:addGameObject(identifier, newGameObject)
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------


function objectManager:generateRecipeDefinition(config)
	-- Modules
	local gameObjectModule = moduleManager:get("gameObject")
	local constructableModule = moduleManager:get("constructable")
	local craftableModule = moduleManager:get("craftable")
	local skillModule = moduleManager:get("skill")
	local craftAreaGroupModule = moduleManager:get("craftAreaGroup")
	local actionModule = moduleManager:get("action")
	local actionSequenceModule = moduleManager:get("actionSequence")
	local toolModule = moduleManager:get("tool")
	local resourceModule = moduleManager:get("resource")

	-- Definition
	local objectDefinition = config["hammerstone:recipe_definition"]
	local description = objectDefinition["description"]
	local identifier = description["identifier"]
	local components = objectDefinition["components"]

	-- Components
	local recipeComponent = utils:getTable(components, "hammerstone:recipe")
	local outputComponent =  utils:getTable(components, "hammerstone:output")
	local buildSequenceComponent =  utils:getTable(components, "hammerstone:build_sequence")
	
	-- Optional Components
	local requirementsComponent =  utils:getTable(components, "hammerstone:requirements", {optional = true})


	log:schema("ddapi", "  " .. identifier)

	
	local toolType = utils:getTable(requirementsComponent, "tool_types", {
		optional = true,
		map = function(value)
			return utils:getTypeIndex(toolModule.types, value, "Tool")
		end
	})

	local buildSequenceData
	if buildSequenceComponent.custom_build_sequence ~= nil then
		utils:logNotImplemented("Custom Build Sequence")
	else
		local actionSequence = utils:getField(buildSequenceComponent, "action_sequence", {
			with = function (value)
				return utils:getTypeIndex(actionSequenceModule.types, value, "Action Sequence")
			end
		})

		buildSequenceData = craftableModule:createStandardBuildSequence(actionSequence, toolType)
	end


	local newRecipeDefinition = {
		name = utils:getField(description, "name"),
		plural = utils:getField(description, "plural"),
		summary = utils:getField(description, "summary"),

		-- Recipe Component
		iconGameObjectType = gameObjectModule.typeIndexMap[utils:getField(recipeComponent, "preview_object", { inTypeTable = gameObjectModule.types})],
		classification = constructableModule.classifications[utils:getField(recipeComponent, "classification", { inTypeTable = constructableModule.classifications, default = "craft"})].index,
		isFoodPreperation = utils:getField(recipeComponent, "is_food_prep", { type = "boolean", default = false }),

		-- TODO: If the component doesn't exist, then set `hasNoOutput` instead.
		outputObjectInfo = {
			outputArraysByResourceObjectType = utils:getTable(outputComponent, "output_by_object", {
				with = function(tbl)
					local result = {}
					for _, value in pairs(tbl) do -- Loop through all output objects
						
						-- Return if input isn't a valid gameObject
						if utils:getTypeIndex(gameObjectModule.types, value.input, "Game Object") == nil then return end

						-- Get the input's resource index
						local index = gameObjectModule.types[value.input].index

						-- Convert from schema format to vanilla format
						-- If the predicate returns nil for any element, map returns nil
						-- In this case, log an error and return if any output item does not exist in gameObject.types
						result[index] = utils:map(value.output, function(e)
							return utils:getTypeIndex(gameObjectModule.types, e, "Game Object")
						end)
					end
					return result
				end
			}),
		},

		-- Requirements Component
		skills = utils:getTable(requirementsComponent, "skills", {
			inTypeTable = skillModule.types,
			optional = true,
			with = function(tbl)
				if #tbl > 0 then
					return {
						required = skillModule.types[tbl[1] ].index
					}
				end
			end
		}),
		disabledUntilAdditionalSkillTypeDiscovered = utils:getTable(requirementsComponent, "skills", {
			inTypeTable = skillModule.types,
			optional = true,
			with = function(tbl)
				if #tbl > 1 then
					return skillModule.types[tbl[2] ].index
				end
			end
		}),
		requiredCraftAreaGroups = utils:getTable(requirementsComponent, "craft_area_groups", {
			optional = true, -- Default is the normal crafting zone.
			map = function(e)
				return utils:getTypeIndex(craftAreaGroupModule.types, e, "Craft Area Group")
			end
		}),
		requiredTools = {
			toolType
		},

		-- Build Sequence Component
		inProgressBuildModel = utils:getField(buildSequenceComponent, "build_model", {default = "craftSimple"}),
		buildSequence = buildSequenceData,

		requiredResources = utils:getTable(requirementsComponent, "resources", {
			-- Runs for each item and replaces item with return result
			map = function(e)

				-- Get the resource
				local res = utils:getTypeIndex(resourceModule.types, e.resource, "Resource")
				if (res == nil) then return end -- Cancel if resource does not exist

				-- Get the count
				local count = utils:getField(e, "count", {default=1, type="number"})

				if e.action ~= nil then
					
					-- TODO: This block is VERY CONFUSING since we're not really able to benifit from the `getField` stuff.
					if e.action.action_type == nil then
						e.action.action_type = "inspect"
					end

					-- Return if action is invalid
					local actionType = utils:getTypeIndex(actionModule.types, e.action.action_type, "Action")
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
	}

	if newRecipeDefinition ~= nil then
		-- Add recipe
		craftableModule:addCraftable(identifier, newRecipeDefinition)

		local typeMapsModule = moduleManager:get("typeMaps")
		-- Add items in crafting panels
		if newRecipeDefinition.requiredCraftAreaGroups then
			for _, group in ipairs(newRecipeDefinition.requiredCraftAreaGroups) do
				local key = gameObjectModule.typeIndexMap[craftAreaGroupModule.types[group].key]
				if objectManager.inspectCraftPanelData[key] == nil then
					objectManager.inspectCraftPanelData[key] = {}
				end
				table.insert(objectManager.inspectCraftPanelData[key], constructableModule.types[identifier].index)
			end
		else
			local key = typeMapsModule.types.gameObject.craftGroup
			if objectManager.inspectCraftPanelData[key] == nil then
				objectManager.inspectCraftPanelData[key] = {}
			end
			table.insert(objectManager.inspectCraftPanelData[key], constructableModule.types[identifier].index)
		end
	end
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

function objectManager:generateMaterialDefinition(config)
	-- Modules
	local materialModule = moduleManager:get("material")

	-- Setup
	local materialDefinition = utils:getField(config, "hammerstone:material_definition")
	local materials = utils:getField(materialDefinition, "materials")

	for _, material in pairs(materials) do

		log:schema("ddapi", "  " .. material["identifier"])

		local data = {

			identifier = utils:getField(material, "identifier", {
				notInTypeTable = moduleManager:get("material").types
			}),

			color = utils:getVec3(material, "color"),
			
			roughness = utils:getField(material, "roughness", {
				default = 1,
				type = "number"
			}),

			metal = utils:getField(material, "metal", {
				default = 0,
				type = "number"
			})
		}

		materialModule:addMaterial(data.identifier, data.color, data.roughness, data.metal)
	end
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

--- Generates skill definitions based on the loaded config, and registers them.

function objectManager:generateSkillDefinition(config)
	-- Modules
	local skillModule = moduleManager:get("skill")

	-- Setup
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
				notInTypeTable = skillModule.types
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
				map = function(e) return utils:getTypeIndex(skillModule.types, e, "Skill") end
			}),
			startLearned = utils:getField(skil, "startLearned", {
				type = "boolean"
			}),
			partialCapacityWithLimitedGeneralAbility = utils:getField(skil, "impactedByLimitedGeneralAbility", {
				type = "boolean"
			}),
		})

		if data ~= nil then
			skillModule:addSkill(data.identifier, data)
		end
	end
end

return objectManager