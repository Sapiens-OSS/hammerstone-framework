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
	-- objectsForStorage = {},
}

-- Sapiens
local rng = mjrequire "common/randomNumberGenerator"

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local mat3Identity = mjm.mat3Identity
local mat3Rotate = mjm.mat3Rotate

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/object/objectUtils" -- TOOD: Are we happy name-bungling imports?
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local configLoader = mjrequire "hammerstone/object/configLoader"
local hammerAPI = mjrequire "hammerAPI"

hammerAPI:test()

---------------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------------

-- Whether to crash (for development), or attempt to recover (for release).
local crashes = true
local count = true

---------------------------------------------------------------------------------
-- Configuation and Loading
---------------------------------------------------------------------------------

--- Data structure which defines how a config is loaded, and in which order.
--- It will also be used to HOLD the loaded configs, once they've been read from the FS
--
-- @field configPath - Path to the folder where the config files can be read. Multiple objects can be generated from the same file.
-- Each route here maps to a FILE TYPE. The fact that 
-- file type has no impact herre.
-- @field moduleDependencies - Table list of modules which need to be loaded before this type of config is loaded
-- @field loaded - Whether the route has already been loaded
-- @field loadFunction - Function which is called when the config type will be loaded. Must take in a single param: the config to load!
-- @field waitingForStart - Whether this config is waiting for a custom trigger or not.
-- @field unwrap - The top level data to 'unwrap' when loading from File. This allows some structure to be ommited.
-- @field configType - Never set here, but the path where configs WILL be loaded, when loaded from lua
local objectLoader = {

	storage = {
		configType = configLoader.configTypes.storage,
		moduleDependencies = {
			"storage",
			"resource"
		},
		loadFunction = "generateStorageObject" -- TODO: Find out how to run a function without accessing it via string
	},

	-- Special one: This handles injecting the resources into storage zones
	storageLinkHandler = {
		configType = configLoader.configTypes.object,
		dependencies = {
			"storage"
		},
		loadFunction = "handleStorageLinks"
	},

	evolvingObject = {
		configType = configLoader.configTypes.object,
		waitingForStart = true,
		moduleDependencies = {
			"evolvingObject",
			"gameObject"
		},
		loadFunction = "generateEvolvingObject"
	},

	resource = {
		configType = configLoader.configTypes.object,
		moduleDependencies = {
			"typeMaps",
			"resource"
		},
		loadFunction = "generateResourceDefinition"
	},

	buildable = {
		configType = configLoader.configTypes.object,
		moduleDependencies = {
			"buildable",
			"constructable",
			"plan",
			"skill",
			"resource",
			"action",
			"craftable"
		},
		loadFunction = "generateBuildableDefinition"
	},

	gameObject = {
		configType = configLoader.configTypes.object,
		waitingForStart = true,
		moduleDependencies = {
			"resource",
			"gameObject",
			"tool",
			"harvestable",
			"seat"
		},
		loadFunction = "generateGameObject"
	},

	harvestable = {
		configType = configLoader.configTypes.object,
		waitingForStart = true,
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
		configType = configLoader.configTypes.recipe,
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
		configType = configLoader.configTypes.object,
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		loadFunction = "generatePlanHelperObject",
		dependencies = {
			"gameObject"
		},
		moduleDependencies = {
			"planHelper"
		}
	},

	skill = {
		configType = configLoader.configTypes.skill,
		disabled = true,
		moduleDependencies = {
			"skill"
		},
		loadFunction = "generateSkillDefinition"
	},


	---------------------------------------------------------------------------------
	-- Shared Configs
	---------------------------------------------------------------------------------

	objectSets = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_object_sets",
		shared_getter = "getObjectSets",
		waitingForStart = true, -- Custom start in serverGOM.lua
		moduleDependencies = {
			"serverGOM"
		},
		loadFunction = "generateObjectSets"
	},

	resourceGroups = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_resource_groups",
		shared_getter = "getResourceGroups",
		moduleDependencies = {
			"resource",
			"typeMaps",
			"gameObject"
		},
		dependencies = {
			"gameObject"
		},
		loadFunction = "generateResourceGroup"
	},

	seats = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_seat_types",
		shared_getter = "getSeatTypes",
		moduleDependencies = {
			"seat",
			"typeMaps"
		},
		dependencies = {
			"storage"
		},
		loadFunction = "generateSeatDefinition"
	},

	material = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_materials",
		shared_getter = "getMaterials",
		moduleDependencies = {
			"material"
		},
		loadFunction = "generateMaterialDefinition"
	},

	-- Custom models are esentially handling 
	customModel = {
		configType = configLoader.configTypes.shared,
		waitingForStart = true, -- See model.lua
		shared_unwrap = "hs_model_remaps",
		shared_getter = "getModelRemaps",
		moduleDependencies = {
			"model"
		},
		loadFunction = "generateCustomModelDefinition"
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
	configLoader:loadConfigs()
end


--- Function which tracks whether a particular object type is ready to be loaded. There
--- are numerious reasons why this might not be the case.
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
	if objectData.moduleDependencies ~= nil then
		for i, moduleDependency in pairs(objectData.moduleDependencies) do
			if moduleManager.modules[moduleDependency] == nil then
				return false
			end
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
-- @param objectData - A table, containing fields from 'objectLoader'
function objectManager:loadObjectDefinition(objectName, objectData)
	log:schema("ddapi", string.format("\nGenerating %s definitions:", objectName))
	local configs = configLoader:fetchRuntimeCompatibleConfigs(objectData)
	log:schema("ddapi", "  Available Configs: " .. #configs)


	if configs == nil or #configs == 0 then
		log:schema("ddapi", "  (none)")
		return
	end

	for i, config in ipairs(configs) do
		if config then
			local function errorhandler(error)
				log:schema("ddapi", "WARNING: Object failed to generate, discarding: " .. objectName)
				log:schema("ddapi", error)
				log:schema("ddapi", "--------")
				log:schema("ddapi", debug.traceback())
				
				if crashes then
					os.exit()
				end
			end
			
			if config.disabled == true then
				log:schema("ddapi", "WARNING: Object is disabled, skipping: " .. objectName)
			else
				utils:initConfig(config)
				xpcall(objectManager[objectData.loadFunction], errorhandler, self, config)
			end

		else
			log:schema("ddapi", "WARNING: Attempting to generate nil " .. objectName)
		end
	end
end

---------------------------------------------------------------------------------
-- Custom Model
---------------------------------------------------------------------------------

function objectManager:generateCustomModelDefinition(modelRemap)
	-- Modules
	local modelModule = moduleManager:get("model")


	local model = utils:getField(modelRemap, "model")
	local baseModel = utils:getField(modelRemap, "base_model")
	log:schema("ddapi", baseModel .. " --> " .. model)

	local materialRemaps = utils:getTable(modelRemap, "material_remaps", {
		with = function(tbl)
			local newTbl = {}
			for j, materialRemap in ipairs(tbl) do
				local old_material = utils:getField(materialRemap, "from")
				local new_material = utils:getField(materialRemap, "to")
				newTbl[old_material] = new_material
			end
			return newTbl
		end
	})
	
	-- Ensure exists
	if modelModule.remapModels[baseModel] == nil then
		modelModule.remapModels[baseModel] = {}
	end
	
	-- Inject so it's available
	modelModule.remapModels[baseModel][model] = materialRemaps
end

---------------------------------------------------------------------------------
-- Buildable
---------------------------------------------------------------------------------

local function getResources(e)
	local resourceModule = moduleManager:get("resource")
	local actionModule = moduleManager:get("action")

	-- Get the resource (as group, or resource)
	local resourceType = utils:getFieldAsIndex(e, "resource", resourceModule.types, {optional=true})
	local groupType =  utils:getFieldAsIndex(e, "resource_group", resourceModule.groups, {optional=true})

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
			type = resourceType,
			group = groupType,
			count = count,
			afterAction = {
				actionTypeIndex = actionType,
				duration = duration,
				durationWithoutSkill = durationWithoutSkill,
			}
		}
	end
	return {
		type = resourceType,
		group = groupType,
		count = count,
	}
end

local function getBuildIdentifier(identifier)
	return "build_" .. identifier
end

local function getNameLocKey(identifier)
	return "object_" .. identifier
end

local function getPluralLocKey(identifier)
	return "object_" .. identifier .. "_plural"
end

function objectManager:generateBuildableDefinition(config)
	-- Modules
	local buildableModule = moduleManager:get("buildable")
	local planModule = moduleManager:get("plan")
	local skillModule = moduleManager:get("skill")
	local constructableModule = moduleManager:get("constructable")
	local craftableModule = moduleManager:get("craftable")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")
	local name = description:get("name", {default = getNameLocKey(identifier)})
	local plural = description:get("plural", {default = getPluralLocKey(identifier)})
	local summary = description:getOptional(description, "summary")

	-- Components
	local components = config:get("components")
	local objectComponent = components:get("hs_object")

	-- Optional Components
	local buildableComponent = components:getOptional("hs_buildable")

	if buildableComponent == nil then
		-- Not everything is a buildable. Chill.
		return
	end

	log:schema("ddapi", "  " .. identifier)

	local newBuildable = {
		modelName = objectComponent:get("model"),

		inProgressGameObjectTypeKey = getBuildIdentifier(identifier),
		finalGameObjectTypeKey = identifier,

		name = name,
		plural = plural,
		summary = summary,
		
		buildCompletionPlanIndex = utils:getFieldAsIndex(description, "build_completion_plan", planModule.types, {optional=true}),
		classification = utils:getFieldAsIndex(buildableComponent, "classification", constructableModule.classifications, {default = "craft"}),

		-- This one is interesting: We simly ask people to define a sequence from the craftable. 
		-- In the future we could also check `buildable.lua` if we wanted.
		buildSequence = utils:getField(buildableComponent, "sequence", {
			with = function (value)
				return utils:getField(craftableModule, value)
			end
		}),

		-- TODO: This code is copy/pasted. We can easily abstract it.
		skills = utils:getTable(buildableComponent, "skills", {
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

		requiredResources = utils:getTable(buildableComponent, "resources", {
			-- Runs for each item and replaces item with return result
			map = getResources
		})

	}

	utils:addProps(newBuildable, buildableComponent, "props", {
		allowBuildEvenWhenDark = false,
		allowYTranslation = true,
		allowXZRotation = true,
		noBuildUnderWater = true,
		canAttachToAnyObjectWithoutTestingForCollisions = false
	})

	buildableModule:addBuildable(identifier, newBuildable)
end

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

function objectManager:generateResourceDefinition(config)
	-- Modules
	local typeMapsModule = moduleManager:get("typeMaps")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")
	local name = utils:getLocalizedString(description, "name", {default = getNameLocKey(identifier)})
	local plural = utils:getLocalizedString(description, "plural", {default = getNameLocKey(identifier)})

	-- Components
	local components = config:get("components")
	local resourceComponent = components:getOptional("hs_resource")
	local foodComponent = components:getOptional("hs_food")

	-- Nil Resources aren't created
	if resourceComponent == nil  then
		return
	end

	log:schema("ddapi", "  " .. identifier)
	
	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = typeMapsModule.types.gameObject[identifier]
	}

	-- TODO: Missing Properties
	-- placeBuildableMaleSnapPoints

	-- Handle Food
	if foodComponent ~= nil then
		newResource.foodValue = foodComponent:get("value", {default = 0.5})
		newResource.foodPortionCount = foodComponent:get("portions", {default = 1})
		newResource.foodPoisoningChance = foodComponent:get("food_poison_chance", {default = 0})
		newResource.defaultToEatingDisabled = foodComponent:get("default_disabled", {default = false})
	end
	
	utils:addProps(newResource, resourceComponent, "props", {
		-- No defaults, that's OK :)
	})

	resourceModule:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Storage Links
---------------------------------------------------------------------------------

function objectManager:handleStorageLinks(config)
	-- Modules
	local storageModule = moduleManager:get("storage")

	-- Setup
	local description = utils:getField(config, "description")
	local identifier = utils:getField(description, "identifier")

	-- Components
	local components = utils:getField(config, "components")
	local resourceComponent = utils:getField(components, "hs_resource", {
		optional = true
	})

	if resourceComponent ~= nil then
		local storageIdentifier = utils:getField(resourceComponent, "link_to_storage")

		log:schema("ddapi", string.format("  Adding resource '%s' to storage '%s'", identifier, storageIdentifier))
		table.insert(storageModule.types[storageIdentifier].resources, moduleManager:get("resource").types[identifier].index)
	end

	storageModule:mjInit()
end


---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

function objectManager:generateStorageObject(config)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local typeMapsModule = moduleManager:get("typeMaps")
	local resourceModule = moduleManager:get("resource")

	-- Load structured information
	local description = config:get("description")

	-- Components
	local components = config:get("components")
	local carryComponent = components:get("hs_carry")
	local storageComponent = components:get("hs_storage")

	-- Print
	local identifier = utils:getField(description, "identifier")
	log:schema("ddapi", "  " .. identifier)

	-- Prep
	local random_rotation_weight = storageComponent:get("random_rotation_weight", {
		default = 2.0
	})
	local rotation = utils:getVec3(storageComponent, "rotation", {
		default = vec3(0.0, 0.0, 0.0)
	})

	local carryCounts = utils:getTable(carryComponent, "hs_carry_count", {
		default = {} -- Allow this field to be undefined, but don't use nil
	})
	
	-- The new storage item
	local newStorage = {
		key = identifier,
		name = utils:getField(description, "name", {default = "storage_" .. identifier}),
		displayGameObjectTypeIndex = typeMapsModule.types.gameObject[storageComponent:get("display_object")],
		resources = utils:getTable(storageComponent, "resources", {
			default = {},
			map = function(value)
				return utils:getTypeIndex(resourceModule.types, value, "Resource")
			end
		}),

		storageBox = {
			size =  utils:getVec3(storageComponent, "item_size", {
				default = vec3(0.5, 0.5, 0.5)
			}),
			
			-- TODO consider giving more control here
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local rot = mat3Rotate(mat3Identity, randomValue * random_rotation_weight, rotation)
				return rot
			end,
			
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

	utils:addProps(newStorage, storageComponent, "props", {
		-- No defaults, that's OK
	})

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
	local components = config.components
	local description = config.description
	local plansComponent = config.components.hs_plans

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
	local harvestableComponent = config.components.hs_harvestable
	local identifier = config.description.identifier

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

	local finishedHarvestIndex = utils:getField(harvestableComponent, "finish_harvest_index", {
		default = #resourcesToHarvest
	})
	harvestableModule:addHarvestableSimple(identifier, resourcesToHarvest, finishedHarvestIndex)
end

---------------------------------------------------------------------------------
-- Object Sets
---------------------------------------------------------------------------------

function objectManager:generateObjectSets(key)
	local serverGOMModule = moduleManager:get("serverGOM")
	serverGOMModule:addObjectSet(key)
end

---------------------------------------------------------------------------------
-- Resource Groups
---------------------------------------------------------------------------------

function objectManager:generateResourceGroup(groupDefinition)
	-- Modules
	local resourceModule = moduleManager:get("resource")
	local gameObjectModule  = moduleManager:get("gameObject")

	
	local identifier = utils:getField(groupDefinition, "identifier")
	log:schema("ddapi", "  " .. identifier)

	local name = utils:getField(groupDefinition, "name", {default = "group_" .. identifier})
	local plural = utils:getField(groupDefinition, "plural", {default = "group_" .. identifier .. "_plural"})

	local newResourceGroup = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = utils:getFieldAsIndex(groupDefinition, "display_object", gameObjectModule.types),
		resourceTypes = utils:getTable(groupDefinition, "resources", {
			map = function(resource_id)
				return utils:getTypeIndex(resourceModule.types, resource_id, "Resource Types")
			end
		})
	}

	resourceModule:addResourceGroup(identifier, newResourceGroup)
end

---------------------------------------------------------------------------------
-- Seat
---------------------------------------------------------------------------------

function objectManager:generateSeatDefinition(seatType)
	-- Modules
	local seatModule = moduleManager:get("seat")
	local typeMapsModule = moduleManager:get("typeMaps")
	
	local identifier = utils:getField(seatType, "identifier")
	log:schema("ddapi", "  " .. identifier)

	local newSeat = {
		key = identifier,
		comfort = utils:getField(seatType, "comfort", {default = 0.5}),
		nodes = utils:getTable(seatType, "nodes", {
			map = function(node)
				return {
					placeholderKey = utils:getField(node, "key"),
					nodeTypeIndex = utils:getFieldAsIndex(node, "type", seatModule.nodeTypes)
				}
			end
		})
	}

	typeMapsModule:insert("seat", seatModule.types, newSeat)
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
	local evolvingObjectComponent = config.components.hs_evolving_object
	local identifier = config.description.identifier
	
	-- If the component doesn't exist, then simply don't registerf an evolving object.
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

---------------------------------------------------------------------------------
-- Game Object
---------------------------------------------------------------------------------

-- TODO: selectionGroupTypeIndexes
-- TODO: Implement eatByProducts

function objectManager:generateGameObject(config)
	objectManager:generateGameObjectInternal(config, false)
end

function objectManager:generateGameObjectInternal(config, isBuildVariant)
	-- Modules
	local gameObjectModule = moduleManager:get("gameObject")
	local resourceModule = moduleManager:get("resource")
	local toolModule = moduleManager:get("tool")
	local harvestableModule = moduleManager:get("harvestable")
	local seatModule = moduleManager:get("seat")

	-- Setup
	local description = utils:getField(config, "description")
	local identifier = utils:getField(description, "identifier")

	if isBuildVariant then
		identifier = getBuildIdentifier(identifier)
	end

	-- Components
	local components = utils:getField(config, "components")
	local objectComponent = utils:getField(components, "hs_object")
	local toolComponent = utils:getField(components, "hs_tool", {optional = true})
	local harvestableComponent = utils:getField(components, "hs_harvestable", {optional = true})
	local resourceComponent = utils:getField(components, "hs_resource", {optional = true})
	local buildableComponent = utils:getField(components, "hs_buildable", {optional = true})

	if isBuildVariant then
		log:schema("ddapi", "  " .. identifier .. "(build variant)")

	else
		log:schema("ddapi", "  " .. identifier)
	end
	
	local resourceIdentifier = nil -- If this stays nil, that just means it's a GOM without a resource, such as animal corpse.
	local resourceTypeIndex = nil
	if resourceComponent ~= nil then
		-- If creating a resource, link ourselves here
		resourceIdentifier = identifier

		-- Finally, cast to index. This may fail, but that's considered an acceptable error since we can't have both options defined.
	else
		-- Otherwise we can link to the requested resource
		if objectComponent.link_to_resource ~= nil then
			resourceIdentifier = objectComponent.link_to_resource
		end
	end

	resourceTypeIndex = utils:getTypeIndex(resourceModule.types, resourceIdentifier, "Resource")
	if resourceTypeIndex == nil then
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

	local harvestableTypeIndex = utils:getField(description, "identifier", {
		with = function (value)
			if harvestableComponent ~= nil then
				return harvestableModule.typeIndexMap[value]
			end
			return nil
		end
	})

	local modelName = utils:getField(objectComponent, "model")
	
	-- Handle Buildable
	local newBuildableKeys = {}
	if buildableComponent then
		-- If build variant... recurse!
		if not isBuildVariant then
			objectManager:generateGameObjectInternal(config, true)
		end

		-- Inject data
		newBuildableKeys = {
			seatTypeIndex = utils:getFieldAsIndex(buildableComponent, "seat_type", seatModule.types, {optional=true}),
			isBuiltObject = utils:getField(buildableComponent, "is_built_object", { default = true}),
			ignoreBuildRay = utils:getField(buildableComponent, "ignore_build_ray", { default = true}),
			isPathFindingCollider = utils:getField(buildableComponent, "has_collisions", { default = true}),
			preventGrassAndSnow = utils:getField(buildableComponent, "clear_ground", { default = true}),
			disallowAnyCollisionsOnPlacement = utils:getField(buildableComponent, "allow_placement_collisions", {
				default = true,
				with = function (value)
					return not value
				end
			}),
			isInProgressBuildObject = isBuildVariant
		}
	end
	
	local newGameObject = {
		name = utils:getLocalizedString(description, "name", {default = getNameLocKey(identifier)}),
		plural = utils:getLocalizedString(description, "plural", {default = getPluralLocKey(identifier)}),
		modelName = modelName,
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

	-- Combine keys
	local outObject = utils:merge(newGameObject, newBuildableKeys)

	-- Actually register the game object
	gameObjectModule:addGameObject(identifier, outObject)
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
	local description = config:get("description")
	local identifier = description:get("identifier")

	log:schema("ddapi", "  " .. identifier)


	-- Components
	local components = config:get("components")
	local recipeComponent = components:get("hs_recipe")
	local buildSequenceComponent =  components:get("hs_build_sequence")
	
	-- Optional Components
	local requirementsComponent =  components:getOptional("hs_requirements")
	local outputComponent =  components:getOptional("hs_output")

	
	local toolTypes = utils:getTable(requirementsComponent, "tools", {
		optional = true,
		map = function(value)
			return toolModule.types[value].index
		end
	})
	local toolType = nil
	if toolTypes ~= nil and #toolTypes > 0 then
		toolType = toolTypes[1]
	end

	local buildSequenceData
	if buildSequenceComponent.custom_build_sequence ~= nil then
		utils:logNotImplemented("Custom Build Sequence")
	else
		local actionSequence = utils:getField(buildSequenceComponent, "action_sequence", {
			optional = true,
			with = function (value)
				return utils:getTypeIndex(actionSequenceModule.types, value, "Action Sequence")
			end
		})
		if actionSequence then
			buildSequenceData = craftableModule:createStandardBuildSequence(actionSequence, toolType)
		else
			buildSequenceData = craftableModule[utils:getField(buildSequenceComponent, "build_sequence")]
		end
	end


	local outputObjectInfo = nil
	local hasNoOutput = outputComponent == nil
	if outputComponent then
		outputObjectInfo = {
			objectTypesArray = utils:getTable(outputComponent, "simple_output", {
				optional = true, -- Can also define with 'outputArraysByResourceObjectType'
				map = function(e)
					return utils:getTypeIndex(gameObjectModule.types, e)
				end
			}),
			outputArraysByResourceObjectType = outputComponent:get("output_by_object", {
				optional = true, -- Can also define with 'objectTypesArray'
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
		}
	end


	local newRecipeDefinition = {
		name = utils:getField(description, "name", {default = "recipe_" .. identifier}),
		plural = utils:getField(description, "plural", {default = "recipe_" .. identifier .. "plural"}),
		summary = utils:getField(description, "summary", {default = "recipe_" .. identifier .. "summary"}),

		-- Recipe Component
		-- TODO: Clean these up
		iconGameObjectType = gameObjectModule.typeIndexMap[utils:getField(recipeComponent, "preview_object", { inTypeTable = gameObjectModule.types})],
		classification = constructableModule.classifications[utils:getField(recipeComponent, "classification", { inTypeTable = constructableModule.classifications, default = "craft"})].index,	

		-- Output
		outputObjectInfo = outputObjectInfo,
		hasNoOutput = hasNoOutput,

		-- TODO: `skills` can be simplified to `skill` and `disabledUntilAdditionalSkillTypeDiscovered` could be a prop?
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
		requiredTools = toolTypes,

		-- Build Sequence Component
		inProgressBuildModel = utils:getField(buildSequenceComponent, "build_model", {default = "craftSimple"}),
		buildSequence = buildSequenceData,

		requiredResources = utils:getTable(requirementsComponent, "resources", {
			-- Runs for each item and replaces item with return result
			map = getResources
		})
	}

	utils:addProps(newRecipeDefinition, recipeComponent, "props", {
		-- No defaults, that's OK
	})

	

	if newRecipeDefinition ~= nil then


		-- Debug
		local debug = config:get("debug", {default = false})
		if debug then
			log:schema("ddapi", "Debugging: " .. identifier)
			log:schema("ddapi", "Config:")
			log:schema("ddapi", config)
			log:schema("ddapi", "Output:")
			log:schema("ddapi", newRecipeDefinition)
		end


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
			local key = gameObjectModule.typeIndexMap.craftArea
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

function objectManager:generateMaterialDefinition(material)
	-- Modules
	local materialModule = moduleManager:get("material")

	local function loadMaterialFromTbl(tbl)
		-- Allowed
		if tbl == nil then
			return nil
		end

		return {
			color = utils:getVec3(tbl, "color"),
		
			roughness = utils:getField(tbl, "roughness", {
				default = 1,
				type = "number"
			}),

			metal = utils:getField(tbl, "metal", {
				default = 0,
				type = "number"
			})
		}
	end

	local identifier = utils:getField(material, "identifier", { notInTypeTable = moduleManager:get("material").types })
	log:schema("ddapi", "  " .. identifier)
	
	local materialData = loadMaterialFromTbl(material)
	local materialDataB = loadMaterialFromTbl(utils:getField(material, "b_material", {optional = true}))
	materialModule:addMaterial(identifier, materialData.color, materialData.roughness, materialData.metal, materialDataB)
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

function objectManager:generateSkillDefinition(config)
	-- Modules
	local skillModule = moduleManager:get("skill")

	-- Setup
	local skills = config["skills"]

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