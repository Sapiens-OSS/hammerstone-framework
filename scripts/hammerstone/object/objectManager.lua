--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich, earmuffs

local objectManager = {
	inspectCraftPanelData = {},
	constructableIndexes = {},
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
local utils = mjrequire "hammerstone/object/objectUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local configLoader = mjrequire "hammerstone/object/configLoader"
local hammerAPI = mjrequire "hammerAPI"

hammerAPI:test()

---------------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------------

-- Whether to crash (for development), or attempt to recover (for release).
local crashes = true


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
				xpcall(objectData.loadFunction, errorhandler, self, config)
			end

		else
			log:schema("ddapi", "WARNING: Attempting to generate nil " .. objectName)
		end
	end
end

---------------------------------------------------------------------------------
-- Model Placeholder
---------------------------------------------------------------------------------


-- Example remap structure
-- local chairLegRemaps = {
--     bone = "bone_chairLeg",
--     foo = "bar"
-- }

-- Takes in a remap table, and returns the 'placeholderModelIndexForObjectTypeFunction' that can handle this data.
--- @param remaps table string->string mapping
local function createIndexFunction(remaps)
	-- Modules
	local gameObjectModule =  moduleManager:get("gameObject")
	local typeMapsModule = moduleManager:get("typeMaps")
	local modelModule = moduleManager:get("model")

    local function inner(placeholderInfo, objectTypeIndex, placeholderContext)
        local objectKey = typeMapsModule:indexToKey(objectTypeIndex, gameObjectModule.validTypes)
        local remap = remaps[objectKey]

        -- Return a remap if exists
        if remap ~= nil then
            return modelModule:modelIndexForName(remap)
        end

        -- Else, return the default model associated with this resource
        local defaultModel = gameObjectModule.types[objectKey].modelName


        return modelModule:modelIndexForName(defaultModel)
    end

    return inner
end

function objectManager:generateModelPlaceholder(config)
	-- Modules
	local modelPlaceholderModule = moduleManager:get("modelPlaceholder")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")

	local components = config:get("components")
	local buildableComponent = components:getOptional("hs_buildable")
	local objectComponent = components:getOptional("hs_object")
	
	--- Don't generate for non-buildables
	if buildableComponent == nil then
		return
	end
	
	-- Otherwise, give warning on potential ill configuration
	if buildableComponent.model_placeholder == nil then
		log:schema("ddapi", string.format("   Warning: %s is being created without a model placeholder. In this case, you are responsible for creating one yourself.", identifier))
		return
	end

	local modelName = utils:getField(objectComponent, "model")
	log:schema("ddapi", string.format("  %s (%s)", identifier, modelName))
	
	local modelPlaceholderData = utils:getTable(buildableComponent, "model_placeholder", {
		map = function(data)

			local isStore = utils:getField(data, "is_store", {default=false})
			
			if isStore then
				return {
					key = utils:getField(data, "key"),
					offsetToStorageBoxWalkableHeight = true
				}
			else
				local default_model = utils:getField(data, "default_model")
				local resource_type = utils:getFieldAsIndex(data, "resource", resourceModule.types)
				local resource_name = utils:getField(data, "resource")

				local remap_data = utils:getField(data, "remaps", {
					default = {
						[resource_name] = default_model
					}
				})
					
				return {
					key = utils:getField(data, "key"),
					defaultModelName = default_model,
					resourceTypeIndex = resource_type,

					-- TODO
					additionalIndexCount = utils:getField(data, "additional_index_count", {optional = true}),
					placeholderModelIndexForObjectTypeFunction = createIndexFunction(remap_data)
				}
			end

		end
	})

	if config.debug == true then
		mj:log(string.format("DEBUGGING '%s'", identifier))
		mj:log(config)
		mj:log(modelPlaceholderData)
	end
	modelPlaceholderModule:addModel(modelName, modelPlaceholderData)
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
		default = {}
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

local function getSummaryLocKey(identifier)
	return "object_" .. identifier .. "_summary"
end

local function getBuildModelName(objectComponent, craftableComponent)
	local modelName = objectComponent:getOptional("model")
	if modelName then
		return modelName
	end
	
	-- TODO
	return false
end

function objectManager:generateBuildableDefinition(config)
	-- Modules
	local buildableModule = moduleManager:get("buildable")
	local constructableModule = moduleManager:get("constructable")
	local planModule = moduleManager:get("plan")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")

	-- Components
	local components = config:get("components")

	-- Optional Components
	local objectComponent = components:getOptional("hs_object")
	local buildableComponent = components:getOptional("hs_buildable")

	-- Not everything is a buildable. Expected soft return.
	if buildableComponent == nil then
		return
	end

	log:schema("ddapi", "  " .. identifier)

	local newBuildable = objectManager:getCraftableBase(description, buildableComponent)

	-- Buildable Specific Stuff
	newBuildable.classification = utils:getFieldAsIndex(buildableComponent, "classification", constructableModule.classifications, {default = "build"})
	newBuildable.modelName = getBuildModelName(objectComponent, buildableComponent)
	newBuildable.inProgressGameObjectTypeKey = getBuildIdentifier(identifier)
	newBuildable.finalGameObjectTypeKey = identifier
	newBuildable.buildCompletionPlanIndex = utils:getFieldAsIndex(buildableComponent, "build_completion_plan", planModule.types, {optional=true})

	utils:addProps(newBuildable, buildableComponent, "props", {
		allowBuildEvenWhenDark = false,
		allowYTranslation = true,
		allowXZRotation = true,
		noBuildUnderWater = true,
		canAttachToAnyObjectWithoutTestingForCollisions = false
	})

	utils:debug(identifier, config, newBuildable)
	buildableModule:addBuildable(identifier, newBuildable)
	
	-- Cached, and handled later in buildUI.lua
	table.insert(objectManager.constructableIndexes, constructableModule.types[identifier].index)
end

function objectManager:generateCraftableDefinition(config)
	-- Modules
	local constructableModule = moduleManager:get("constructable")
	local gameObjectModule =  moduleManager:get("gameObject")
	local craftAreaGroupModule = moduleManager:get("craftAreaGroup")
	local craftableModule = moduleManager:get("craftable")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")

	-- Components
	local components = config:get("components")

	-- Optional Components
	local craftableComponent = components:getOptional("hs_craftable")

	-- Not everything is a craftable. Expected soft return.
	if craftableComponent == nil then
		return
	end

	-- TODO
	local outputComponent = craftableComponent:getOptional("hs_output")

	log:schema("ddapi", "  " .. identifier)

	local newCraftable = objectManager:getCraftableBase(description, craftableComponent)

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

	local craftArea = utils:getFieldAsIndex(craftableComponent, "craft_area", craftAreaGroupModule.types, {optional = true})
	local requiredCraftAreaGroups = nil
	if craftArea then
		requiredCraftAreaGroups = {
			craftArea
		}
	end

	-- Craftable Specific Stuff
	newCraftable.classification = utils:getFieldAsIndex(craftableComponent, "classification", constructableModule.classifications, {default = "craft"})
	newCraftable.hasNoOutput = hasNoOutput
	newCraftable.outputObjectInfo = outputObjectInfo
	newCraftable.requiredCraftAreaGroups = requiredCraftAreaGroups
	newCraftable.inProgressBuildModel = utils:getField(craftableComponent, "build_model", {default = "craftSimple"})

	utils:addProps(newCraftable, craftableComponent, "props", {
		-- No defaults, that's OK
	})

	if newCraftable ~= nil then


		-- Debug
		local debug = config:get("debug", {default = false})
		if debug then
			log:schema("ddapi", "Debugging: " .. identifier)
			log:schema("ddapi", "Config:")
			log:schema("ddapi", config)
			log:schema("ddapi", "Output:")
			log:schema("ddapi", newCraftable)
		end


		-- Add recipe
		craftableModule:addCraftable(identifier, newCraftable)
		
		-- Add items in crafting panels
		if newCraftable.requiredCraftAreaGroups then
			for _, group in ipairs(newCraftable.requiredCraftAreaGroups) do
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
-- Resource
---------------------------------------------------------------------------------

function objectManager:generateResourceDefinition(config)
	-- Modules
	local typeMapsModule = moduleManager:get("typeMaps")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = config:get("description")
	local identifier = description:get("identifier")
	local name = utils:getLocalizedString(description, "name", getNameLocKey(identifier))
	local plural = utils:getLocalizedString(description, "plural", getNameLocKey(identifier))

	-- Components
	local components = config:get("components")
	local resourceComponent = components:getOptional("hs_resource")
	local foodComponent = components:getOptional("hs_food")

	-- Nil Resources aren't created
	if resourceComponent == nil  then
		return
	end

	log:schema("ddapi", "  " .. identifier)
	
	local displayObject = resourceComponent:get("display_object", {default = identifier})

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = typeMapsModule.types.gameObject[displayObject]
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
-- Eat By Products
---------------------------------------------------------------------------------

function objectManager:handleEatByProducts(config)
	-- Modules
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local description = utils:getField(config, "description")
	local identifier = utils:getField(description, "identifier")

	-- Components
	local components = config:get("components")
	local foodComponent = components:getOptional("hs_food")

	if foodComponent == nil then
		return
	end

	local eatByProducts = utils:getTable(foodComponent, "items_when_eaten", {
		map = function(value)
			return utils:getTypeIndex(gameObjectModule.types, value, "Game Object")
		end
	})

	-- Inject into the object
	gameObjectModule.types[identifier].eatByProducts = eatByProducts
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
		local storageIdentifier = utils:getField(resourceComponent, "storage_identifier")

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

	local carryCounts = utils:getTable(carryComponent, "hs_carry_count", {
		default = {} -- Allow this field to be undefined, but don't use nil, since we will pull props from here later, with their *own* defaults
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
			
			rotationFunction = function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)
				local baseRotation = mat3Rotate(
					mat3Identity,
					math.pi * storageComponent:get("base_rotation_weight", {default = 0}),
					utils:getVec3(storageComponent, "base_rotation", {default = vec3(1.0, 0.0, 0.0)})
				)

				return mat3Rotate(
					baseRotation,
					randomValue * storageComponent:get("random_rotation_weight", {default = 2.0}),
					utils:getVec3(storageComponent, "random_rotation", {default = vec3(1, 0.0, 0.0)})
				)
			end,
			
			placeObjectOffset = mj:mToP(utils:getVec3(storageComponent, "place_offset", {
				default = vec3(0.0, 0.0, 0.0)
			})),

			placeObjectRotation = mat3Rotate(
				mat3Identity,
				math.pi * storageComponent:get("place_rotation_weight", {default = 0.0}),
				utils:getVec3(storageComponent, "place_rotation", {default = vec3(0.0, 0.0, 1)})
			),
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
			utils:getVec3(carryComponent, "rotation", { default = vec3(0.0, 0.0, 1.0)})
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
	local components = config:get("components")
	local description = config:get("description")
	local plansComponent = components:getOptional("hs_plans")

	if plansComponent == nil then
		return
	end


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
	local components = config:get("components")
	local evolvingObjectComponent = components:getOptional("hs_evolving_object")
	local description = config:get("description")
	local identifier = description:get("identifier")
	
	-- If the component doesn't exist, then simply don't registerf an evolving object.
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
	end

	-- Default
	local time = 1 * evolvingObjectModule.yearLength
	local yearTime = evolvingObjectComponent:getOptional("time_years")
	if yearTime then
		time = yearTime * evolvingObjectModule.yearLength
	end

	local dayTime = evolvingObjectComponent:getOptional("time_days")
	if dayTime then
		time = yearTime * evolvingObjectModule.dayLength
	end

	if dayTime and yearTime then
		log:schema("ddapi", "   WARNING: Evolving defines both 'time_years' and 'time_days'. You can only define one.")

	end

	local newEvolvingObject = {
		minTime = time,
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

--- Returns a lua table, containing the shared keys between craftables and buildables
function objectManager:getCraftableBase(description, craftableComponent)
	
	-- Modules
	local skillModule = moduleManager:get("skill")
	local craftableModule = moduleManager:get("craftable")
	local toolModule = moduleManager:get("tool")
	local constructableModule = moduleManager:get("constructable")
	local actionSequenceModule = moduleManager:get("actionSequence")
	local gameObjectModule = moduleManager:get("gameObject")

	-- Setup
	local identifier = description:get("identifier")

	local tool = utils:getFieldAsIndex(craftableComponent, "tool", toolModule.types, {optional = true})
	local requiredTools = nil
	if tool then
		requiredTools = {
			tool
		}
	end

	-- TODO: copy/pasted
	local buildSequenceData
	if craftableComponent.custom_build_sequence ~= nil then
		utils:logNotImplemented("Custom Build Sequence")
	else
		local actionSequence = utils:getField(craftableComponent, "action_sequence", {
			optional = true,
			with = function (value)
				return utils:getTypeIndex(actionSequenceModule.types, value, "Action Sequence")
			end
		})
		if actionSequence then
			buildSequenceData = craftableModule:createStandardBuildSequence(actionSequence, tool)
		else
			buildSequenceData = craftableModule[utils:getField(craftableComponent, "build_sequence")]
		end
	end

	local craftableBase = {
		name = utils:getLocalizedString(description, "name", getNameLocKey(identifier)),
		plural = utils:getLocalizedString(description, "plural", getPluralLocKey(identifier)),
		summary = utils:getLocalizedString(description, "summary", getSummaryLocKey(identifier)),

		buildSequence = buildSequenceData,

		skills = {
			required = utils:getFieldAsIndex(craftableComponent, "skill", skillModule.types, {optional = true})
		},

		iconGameObjectType = utils:getFieldAsIndex(craftableComponent, "display_object", gameObjectModule.types, {
			default = identifier
		}),

		requiredTools = requiredTools,

		requiredResources = utils:getTable(craftableComponent, "resources", {
			map = getResources
		})

	}

	return craftableBase
end


-- TODO: selectionGroupTypeIndexes
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
	local craftAreaGroupModule = moduleManager:get("craftAreaGroup")

	-- Setup
	local description = utils:getField(config, "description")
	local identifier = utils:getField(description, "identifier")

	local nameKey = identifier
	if isBuildVariant then
		identifier = getBuildIdentifier(identifier)
	end

	-- Components
	local components = utils:getField(config, "components")
	local objectComponent = utils:getField(components, "hs_object", {optional = true})
	local toolComponent = utils:getField(components, "hs_tool", {optional = true})
	local harvestableComponent = utils:getField(components, "hs_harvestable", {optional = true})
	local resourceComponent = utils:getField(components, "hs_resource", {optional = true})
	local buildableComponent = utils:getField(components, "hs_buildable", {optional = true})

	if objectComponent == nil then
		log:schema("ddapi", "  WARNING:  " .. identifier .. " is being created without 'hs_object'. This is only acceptable for resources and so forth.")
		return
	end
	if isBuildVariant then
		log:schema("ddapi", string.format("%s  (build variant)", identifier))
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

	if resourceIdentifier then
		resourceTypeIndex = utils:getTypeIndex(resourceModule.types, resourceIdentifier, "Resource")
		if resourceTypeIndex == nil then
			log:schema("ddapi", "    Note: Object is being created without any associated resource. This is only acceptable for things like corpses etc.")
		end
	end

	-- Handle tools
	local toolUsage = {}
	if toolComponent then
		for key, config in pairs(toolComponent) do
			local toolTypeIndex = utils:getTypeIndex(toolModule.types, key, "Tool Type")
			toolUsage[toolTypeIndex] = {
				[toolModule.propertyTypes.damage.index] = utils:getField(config, "damage", {optional = true}),
				[toolModule.propertyTypes.durability.index] = utils:getField(config, "durability", {optional = true}),
				[toolModule.propertyTypes.speed.index] = utils:getField(config, "speed", {optional = true}),
			}
		end
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
			ignoreBuildRay = utils:getField(buildableComponent, "ignore_build_ray", { default = true}),
			isPathFindingCollider = utils:getField(buildableComponent, "has_collisions", { default = true}),
			preventGrassAndSnow = utils:getField(buildableComponent, "clear_ground", { default = true}),
			disallowAnyCollisionsOnPlacement = utils:getField(buildableComponent, "allow_placement_collisions", {
				default = true,
				with = function (value)
					return not value
				end
			}),
			
			isBuiltObject = not isBuildVariant,
			isInProgressBuildObject = isBuildVariant
		}

		-- Build variant doesnt get seats
		if not isBuildVariant then
			newBuildableKeys.seatTypeIndex = utils:getFieldAsIndex(buildableComponent, "seat_type", seatModule.types, {optional=true})
		end
	end
	
	local newGameObject = {
		name = utils:getLocalizedString(description, "name", getNameLocKey(nameKey)),
		plural = utils:getLocalizedString(description, "plural", getPluralLocKey(nameKey)),
		modelName = modelName,
		scale = utils:getField(objectComponent, "scale", {default = 1}),
		hasPhysics = utils:getField(objectComponent, "physics", {default = true}),
		resourceTypeIndex = resourceTypeIndex,
		harvestableTypeIndex = harvestableTypeIndex,
		toolUsages = toolUsage,
		craftAreaGroupTypeIndex = utils:getFieldAsIndex(buildableComponent, "craft_area", craftAreaGroupModule.types, {
			optional = true
		}),

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	utils:addProps(newGameObject, buildableComponent, "props", {
		-- No defaults, that's OK
	})

	-- Combine keys
	local outObject = utils:merge(newGameObject, newBuildableKeys)

	-- Actually register the game object
	gameObjectModule:addGameObject(identifier, outObject)
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
		loadFunction = objectManager.generateStorageObject
	},

	-- Special one: This handles injecting the resources into storage zones
	storageLinkHandler = {
		configType = configLoader.configTypes.object,
		dependencies = {
			"storage"
		},
		loadFunction = objectManager.handleStorageLinks
	},

	-- Special one: This handles injecting the eat products, after all objects have been created.
	eatByProductsHandler = {
		configType = configLoader.configTypes.object,
		waitingForStart = true, -- triggered in gameObject.lua
		moduleDependencies = {
			"gameObject"
		},
		loadFunction = objectManager.handleEatByProducts
	},

	evolvingObject = {
		configType = configLoader.configTypes.object,
		waitingForStart = true,
		moduleDependencies = {
			"evolvingObject",
			"gameObject"
		},
		loadFunction = objectManager.generateEvolvingObject
	},

	resource = {
		configType = configLoader.configTypes.object,
		moduleDependencies = {
			"typeMaps",
			"resource"
		},
		loadFunction = objectManager.generateResourceDefinition
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
			"craftable",
			"tool",
			"actionSequence",
			"gameObject"
		},
		loadFunction = objectManager.generateBuildableDefinition
	},

	craftable = {
		configType = configLoader.configTypes.object,
		waitingForStart = true,
		moduleDependencies = {
			"gameObject",
			"constructable",
			"craftAreaGroup",
			"skill",
			"resource",
			"action",
			"craftable",
			"tool",
			"actionSequence"
		},
		loadFunction = objectManager.generateCraftableDefinition
	},

	modelPlaceholder = {
		configType = configLoader.configTypes.object,
		moduleDependencies = {
			"modelPlaceholder",
			"resource",
			"gameObject",
			"model"
		},
		dependencies = {
			"gameObject"
		},
		loadFunction = objectManager.generateModelPlaceholder
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
		loadFunction = objectManager.generateGameObject
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
		loadFunction = objectManager.generateHarvestableObject
	},

	planHelper = {
		configType = configLoader.configTypes.object,
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		dependencies = {
			"gameObject"
		},
		moduleDependencies = {
			"planHelper"
		},
		loadFunction = objectManager.generatePlanHelperObject
	},

	skill = {
		configType = configLoader.configTypes.skill,
		disabled = true,
		moduleDependencies = {
			"skill"
		},
		loadFunction = objectManager.generateSkillDefinition
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
		loadFunction = objectManager.generateObjectSets
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
		loadFunction = objectManager.generateResourceGroup
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
		loadFunction = objectManager.generateSeatDefinition
	},

	material = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_materials",
		shared_getter = "getMaterials",
		moduleDependencies = {
			"material"
		},
		loadFunction = objectManager.generateMaterialDefinition
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
		loadFunction = objectManager.generateCustomModelDefinition
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
return objectManager