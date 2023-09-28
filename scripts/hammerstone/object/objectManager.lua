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
local logicManager = mjrequire "hammerstone/logic/logicManager"

hammerAPI:test()

---------------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------------

-- Whether to crash (for development), or attempt to recover (for release).
local crashes = true


-- Loads a single object
-- @param objectData - A table, containing fields from 'objectLoader'
function objectManager:loadObjectDefinition(objectName, objectData)
	log:schema("ddapi", string.format("\n\nGenerating %s definitions:", objectName))
	local configs = configLoader:fetchRuntimeCompatibleConfigs(objectData)
	log:schema("ddapi", "Available Configs: " .. #configs)


	if configs == nil or #configs == 0 then
		log:schema("ddapi", "  (no objects of this type created)")
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
local function createIndexFunction(remaps, default)
	local function inner(placeholderInfo, objectTypeIndex, placeholderContext)
		-- Modules
		local gameObjectModule =  moduleManager:get("gameObject")
		local typeMapsModule = moduleManager:get("typeMaps")
		local modelModule = moduleManager:get("model")

		local objectKey = typeMapsModule:indexToKey(objectTypeIndex, gameObjectModule.validTypes)


		local remap = remaps[objectKey]

		-- Return a remap if exists
		if remap ~= nil then
			return modelModule:modelIndexForName(remap)
		end

		-- TODO: We should probbaly re-handle this old default type
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
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()
	local buildableComponent = components:get("hs_buildable"):value()
	local objectComponent = components:get("hs_object"):value()
	
	--- Don't generate for non-buildables
	if buildableComponent == nil then
		return
	end
	
	-- Otherwise, give warning on potential ill configuration
	if buildableComponent.model_placeholder == nil then
		log:schema("ddapi", string.format("   Warning: %s is being created without a model placeholder. In this case, you are responsible for creating one yourself.", identifier))
		return
	end

	local modelName = objectComponent:get("model"):required():value()
	log:schema("ddapi", string.format("  %s (%s)", identifier, modelName))
	
	local modelPlaceholderData = buildableComponent:get("model_placeholder"):required():map(
		function(data)

			local isStore = data:get("is_store"):default(false):value()
			
			if isStore then
				return {
					key = data:get("key"):required():value(),
					offsetToStorageBoxWalkableHeight = true
				}
			else
				local default_model = data:get("default_model"):required():value()
				local resource_type = data:get("resource"):required():asTypeIndex(resourceModule.types):value()
				local resource_name = data:get("resource"):required():value()
				local remap_data = data:get("remaps"):default( { [resource_name] = default_model } ):value()

					
				return {
					key = data:get("key"):required():value(),
					defaultModelName = default_model,
					resourceTypeIndex = resource_type,

					-- TODO
					additionalIndexCount = data:get("additional_index_count"):value(),
					defaultModelShouldOverrideResourceObject = data:get("use_default_model"):value(),
					placeholderModelIndexForObjectTypeFunction = createIndexFunction(remap_data, default_model)
				}
			end

		end
	):value()

	utils:debug(identifier, config, modelPlaceholderData)
	modelPlaceholderModule:addModel(modelName, modelPlaceholderData)
end


---------------------------------------------------------------------------------
-- Custom Model
---------------------------------------------------------------------------------

function objectManager:generateCustomModelDefinition(modelRemap)
	-- Modules
	local modelModule = moduleManager:get("model")

	local model = modelRemap:get("model"):required():value()
	local baseModel = modelRemap:get("base_model"):required():value()
	log:schema("ddapi", baseModel .. " --> " .. model)

	local materialRemaps = modelRemap:get("material_remaps"):default({}):value()
	
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
	local resourceType = e:get("resource"):asTypeIndex(resourceModule.types):value()
	local groupType =  e:get("resource_group"):asTypeIndex(resourceModule.groups):value()

	-- Get the count
	local count = e:get("count"):default(1):asType("number"):value()

	if e:hasKey("action") then
		
		local action = e:get("action")

		-- Return if action is invalid
		local actionType = utils:getTypeIndex(actionModule.types, action:get("action_type"):default("inspect"):value(), "Action")
		if (actionType == nil) then return end

		-- Return if duration is invalid
		local duration = action:get("duration"):required():ofType("number"):value()
		if (not duration) then
			log:schema("ddapi", "    Duration for " .. e.action.action_type .. " is not a number")
			return
		end

		-- Return if duration without skill is invalid
		local durationWithoutSkill = action:get("duration_without_skill"):default(duration):ofType("number"):value()
		if (durationWithoutSkill) then
			log:schema("ddapi", "    Duration without skill for " .. e.action.action_type .. " is not a number")
			return
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

local function getNameKey(prefix, identifier)
	return prefix .. "_" .. identifier
end

local function getPluralKey(prefix, identifier)
	return prefix .. "_" .. identifier .. "_plural"
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

local function getInProgressKey(prefix, identifier)
	return prefix .. "_" .. "inProgress"
end

local function getBuildModelName(objectComponent, craftableComponent)
	local modelName = objectComponent:get("model"):value()
	if modelName then
		return modelName
	end
	
	-- TODO @Lich can't you just return objectComponent:get("model"):value() ?
	return false
end

function objectManager:generateBuildableDefinition(config)
	-- Modules
	local buildableModule = moduleManager:get("buildable")
	local constructableModule = moduleManager:get("constructable")
	local planModule = moduleManager:get("plan")
	local researchModule = moduleManager:get("research")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()

	-- Optional Components
	local objectComponent = components:get("hs_object"):value()
	local buildableComponent = components:get("hs_buildable"):value()

	-- Not everything is a buildable. Expected soft return.
	if buildableComponent == nil then
		return
	end

	log:schema("ddapi", "  " .. identifier)

	local newBuildable = objectManager:getCraftableBase(description, buildableComponent)

	-- Buildable Specific Stuff
	newBuildable.classification =buildableComponent:get("classification"):default("build"):asTypeIndex(constructableModule.classifications):value()
	newBuildable.modelName = getBuildModelName(objectComponent, buildableComponent)
	newBuildable.inProgressGameObjectTypeKey = getBuildIdentifier(identifier)
	newBuildable.finalGameObjectTypeKey = identifier
	newBuildable.buildCompletionPlanIndex =buildableComponent:get("build_completion_plan"):asTypeIndex(planModule.types):value()

	local research = buildableComponent:get("research"):value()
	if research ~= nil then
		newBuildable.disabledUntilAdditionalResearchDiscovered = researchModule.typeIndexMap[research]
	end
	
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
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()

	-- Optional Components
	local craftableComponent = components:get("hs_craftable"):value()

	-- Not everything is a craftable. Expected soft return.
	if craftableComponent == nil then
		return
	end

	-- TODO
	local outputComponent = craftableComponent:get("hs_output"):value()

	log:schema("ddapi", "  " .. identifier)

	local newCraftable = objectManager:getCraftableBase(description, craftableComponent)

	local outputObjectInfo = nil
	local hasNoOutput = outputComponent == nil
	if outputComponent then
		outputObjectInfo = {
			objectTypesArray = outputComponent:get("simple_output"):map( 
				function(e)
					return utils:getTypeIndex(gameObjectModule.types, e)
				end
			):value(),
			outputArraysByResourceObjectType = outputComponent:get("output_by_object"):with(
				function(tbl)
					local result = {}
					for key, value in pairs(tbl) do -- Loop through all output objects
			
						-- Get the input's resource index
						local index = utils:getTypeIndex(gameObjectModule.types, key, "Game Object")

						-- Convert from schema format to vanilla format
						-- If the predicate returns nil for any element, map returns nil
						-- In this case, log an error and return if any output item does not exist in gameObject.types
						result[index] = utils:map(value, function(e)
							return utils:getTypeIndex(gameObjectModule.types, e, "Game Object")
						end)
					end
					return result
				end
			):value(),
		}
	end

	local craftArea = craftableComponent:get("craft_area"):asTypeIndex(craftAreaGroupModule.types)
	local requiredCraftAreaGroups = nil
	if craftArea then
		requiredCraftAreaGroups = {
			craftArea
		}
	end

	-- Craftable Specific Stuff
	newCraftable.classification = craftableComponent:get("classification"):default("craft"):asTypeIndex(constructableModule.classifications):value()
	newCraftable.hasNoOutput = hasNoOutput
	newCraftable.outputObjectInfo = outputObjectInfo
	newCraftable.requiredCraftAreaGroups = requiredCraftAreaGroups
	newCraftable.inProgressBuildModel = craftableComponent:get("build_model"):default("craftSimple"):value()

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
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()
	local name = description:get("name"):asLocalizedString(getNameLocKey(identifier)):value()
	local plural = description:get("plural"):asLocalizedString(getNameLocKey(identifier)):value()

	-- Components
	local components = config:get("components"):required():value()
	local resourceComponent = components:get("hs_resource"):value()
	local foodComponent = components:get("hs_food"):value()

	-- Nil Resources aren't created
	if resourceComponent == nil  then
		return
	end

	log:schema("ddapi", "  " .. identifier)
	
	local displayObject = resourceComponent:get("display_object"):default(identifier):value()

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
		newResource.foodValue = foodComponent:get("value"):default(0.5):value()
		newResource.foodPortionCount = foodComponent:get("portions"):default(1):value()
		newResource.foodPoisoningChance = foodComponent:get("food_poison_chance"):default(0):value()
		newResource.defaultToEatingDisabled = foodComponent:get("default_disabled"):default(false):value()
	end
	
	utils:addProps(newResource, resourceComponent, "props", {
		-- Add defaults here, if needed
	})

	resourceModule:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Eat By Products Handler
---------------------------------------------------------------------------------

function objectManager:handleEatByProducts(config)
	-- Modules
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()
	local foodComponent = components:get("hs_food"):value()

	if foodComponent == nil then
		return
	end
	
	local eatByProducts = foodComponent:get("items_when_eaten"):map(
		function(value)
			return utils:getTypeIndex(gameObjectModule.types, value, "Game Object")
		end
	):value()

	log:schema("ddapi", string.format("  Adding  eatByProducts to '%s'", identifier))

	-- Inject into the object
	gameObjectModule.types[identifier].eatByProducts = eatByProducts
end

---------------------------------------------------------------------------------
-- storageDisplayGameObjectTypeIndex
---------------------------------------------------------------------------------

function objectManager:handleStorageDisplayGameObjectTypeIndex(config)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()
	local storageComponent = components:get("hs_storage"):value()

	if storageComponent == nil then
		return
	end

	local displayObject = storageComponent:get("display_object"):default(identifier):value()
	local displayIndex = typeMapsModule.types.gameObject[displayObject]

	-- Inject into the object
	log:schema("ddapi", string.format("  Adding display_object '%s' to storage '%s', with index '%s'", displayObject, identifier, displayIndex))
	storageModule.types[identifier].displayGameObjectTypeIndex = displayIndex
	storageModule:mjInit()
end



---------------------------------------------------------------------------------
-- Storage Links
---------------------------------------------------------------------------------

function objectManager:handleStorageLinks(config)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components")
	local resourceComponent = components:get("hs_resource"):value()

	if resourceComponent ~= nil then
		local storageIdentifier = resourceComponent:get("storage_identifier"):value()

		log:schema("ddapi", string.format("  Adding resource '%s' to storage '%s'", identifier, storageIdentifier))
		table.insert(utils:getType(storageModule.types, storageIdentifier, "storage").resources, utils:getTypeIndex(resourceModule.types, identifier))
	end

	storageModule:mjInit()
end


---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

function objectManager:generateStorageObject(config)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local resourceModule = moduleManager:get("resource")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Load structured information
	local description = config:get("description"):required():value()

	-- Components
	local components = config:get("components"):required():value()
	local carryComponent = components:get("hs_carry"):required():value()
	local storageComponent = components:get("hs_storage"):required():value()

	-- Print
	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Allow this field to be undefined, but don't use nil, since we will pull props from here later, with their *own* defaults
	local carryCounts = carryComponent:get("hs_carry_count"):default({}):value()

	local displayObject = storageComponent:get("display_object"):default(identifier):value()
	local displayIndex = typeMapsModule.types.gameObject[displayObject]
	log:schema("ddapi", string.format("  Adding display_object '%s' to storage '%s', with index '%s'", displayObject, identifier, displayIndex))

	-- The new storage item
	local newStorage = {
		key = identifier,
		name = description:get("name"):asLocalizedString(getNameKey("storage", identifier)):value(),

		displayGameObjectTypeIndex = displayIndex,
		
		resources = storageComponent:get("resources"):default({}):map(
			function(value)
				return utils:getTypeIndex(resourceModule.types, value, "Resource")
			end
		):value(),

		storageBox = {
			size =  storageComponent:get("item_size"):asVec3():default(vec3(0.5, 0.5, 0.5)):value(),
			
			rotationFunction = 
			function(uniqueID, seed)
				local randomValue = rng:valueForUniqueID(uniqueID, seed)

				local baseRotation = mat3Rotate(
					mat3Identity,
					math.pi * storageComponent:get("base_rotation_weight"):default(0):value(),
					storageComponent:get("base_rotation"):asVec3():default(vec3(1.0, 0.0, 0.0)):value()
				)

				return mat3Rotate(
					baseRotation,
					randomValue * storageComponent:get("random_rotation_weight"):default(2.0):value(),
					storageComponent:get("random_rotation"):asVec3():default(vec3(1, 0.0, 0.0)):value()
				)
			end,
			
			placeObjectOffset = mj:mToP(storageComponent:get("place_offset"):asVec3():default(vec3(0.0, 0.0, 0.0)):value()),

			placeObjectRotation = mat3Rotate(
				mat3Identity,
				math.pi * storageComponent:get("place_rotation_weight"):default(0.0):value(),
				storageComponent:get("place_rotation"):asVec3():default(vec3(0.0, 0.0, 1)):value()
			),
		},

		maxCarryCount = carryCounts:get("normal"):default(1):value(),
		maxCarryCountLimitedAbility = carryCounts:get("limited_ability"):default(1):value(),
		maxCarryCountForRunning = carryCounts:get("running"):default(1):value(),


		carryStackType = storageModule.stackTypes[carryComponent:get("stack_type"):default("standard"):value()],
		carryType = storageModule.carryTypes[carryComponent:get("carry_type"):default("standard"):value()],

		carryOffset = carryComponent:get("offset"):asVec3():default(vec3(0.0, 0.0, 0.0)):value(),

		carryRotation = mat3Rotate(mat3Identity,
			carryComponent:get("rotation_constant"):default(1):value(),
			carryComponent:get("rotation"):asVec3():default(vec3(0.0, 0.0, 1.0)):value()
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
	local components = config:get("components"):required():value()
	local description = config:get("description"):required():value()
	local plansComponent = components:get("hs_plans"):value()

	if plansComponent == nil then
		return
	end


	local objectIndex = description:get("identifier"):required():asTypeIndex(gameObjectModule.types):value()
	local availablePlans = plansComponent:get("available_plans"):with(
		function (value)
			return planHelperModule[value]
		end
	):value()

	-- Nil plans would override desired vanilla plans
	if availablePlans ~= nil then
		planHelperModule:setPlansForObject(objectIndex, availablePlans)
	end
end

---------------------------------------------------------------------------------
-- Mob Object
---------------------------------------------------------------------------------

function objectManager:generateMobObject(config)
	-- Modules
	local mobModule = moduleManager:get("mob")
	local gameObjectModule = moduleManager:get("gameObject")
	local animationGroupsModule = moduleManager:get("animationGroups")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()
	local name = description:get("name"):asLocalizedString(getNameLocKey(identifier)):value()
	local components = config:get("components"):required():value()
	local mobComponent = components:get("hs_mob"):value()
	local objectComponent = components:get("hs_object"):value()

	if mobComponent == nil then
		return
	end
	log:schema("ddapi", "  " .. identifier)

	local mobObject = {
		name = name,
		gameObjectTypeIndex = gameObjectModule.types[identifier].index,
		deadObjectTypeIndex = mobComponent:get("dead_object"):asTypeIndex(gameObjectModule.types):value(),
		animationGroupIndex = mobComponent:get("animation_group"):asTypeIndex(animationGroupsModule):value(),
	}

	utils:addProps(mobObject, mobComponent, "props", {
		-- No defaults, that's OK
	})

	-- Insert
	mobModule:addType(identifier, mobObject)

	-- Lastly, inject mob index, if required
	if objectComponent then
		gameObjectModule.types[identifier].mobTypeIndex = mobModule.types[identifier].index
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
	local components = config:get("components"):required():value()
	local harvestableComponent = components:get("hs_harvestable"):value()
	local identifier = config:get(description):required():get("identifier"):required():value()

	if harvestableComponent == nil then
		return -- This is allowed
	end
	
	log:schema("ddapi", "  " .. identifier)

	local resourcesToHarvest = harvestableComponent:get("resources_to_harvest"):map(
		function(value)
			return gameObjectModule.typeIndexMap[value]
		end
	):value()

	local finishedHarvestIndex = harvestableComponent:get("finish_harvest_index"):default(#resourcesToHarvest):value()
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

	
	local identifier = groupDefinition:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	local name = groupDefinition:get("name"):asLocalizedString(getNameKey("group", identifier)):value()
	local plural = groupDefinition:get("plural"):asLocalizedString(getPluralKey("group", identifier)):value()

	local newResourceGroup = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = groupDefinition:get("display_object"):required():asTypeIndex(gameObjectModule.types):value(),
		resourceTypes = groupDefinition:get("resources"):required():map(
			function(resource_id)
				return utils:getTypeIndex(resourceModule.types, resource_id, "Resource Types")
			end
		):value()
	}

	resourceModule:addResourceGroup(identifier, newResourceGroup)
end

-- Special handler which allows resources to inject themselves into existing resource groups. Runs
-- after resource groups are already created
function objectManager:handleResourceGroups(config)
	-- Modules
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	-- Components
	local components = config:get("components"):required():value()
	local resourceComponent = components:get("hs_resource"):value()
	if resourceComponent == nil then
		return
	end

	local resourceGroups = resourceComponent:get("resource_groups"):value()
	if resourceGroups == nil then
		return
	end

	-- Loop over every group this resource wants to add itself to
	for i, resourceGroup in ipairs(resourceGroups) do
		log:schema("ddapi", string.format("  Adding resource '%s' to resourceGroup '%s'", identifier, resourceGroup))
		resourceModule:addResourceToGroup(identifier, resourceGroup)
	end
end

---------------------------------------------------------------------------------
-- Seat
---------------------------------------------------------------------------------

function objectManager:generateSeatDefinition(seatType)
	-- Modules
	local seatModule = moduleManager:get("seat")
	local typeMapsModule = moduleManager:get("typeMaps")
	
	local identifier = seatType:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	local newSeat = {
		key = identifier,
		comfort = seatType:get("comfort"):default(0.5):value(),
		nodes = seatType:get("nodes"):required():map(
			function(node)
				return {
					placeholderKey = node:get("key"):required():value(),
					nodeTypeIndex = node:get("type"):required():asTypeIndex(seatModule.nodeTypes):value()
				}
			end
		):value()
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
	local components = config:get("components"):required():value()
	local evolvingObjectComponent = components:get("hs_evolving_object"):value()
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()
	
	-- If the component doesn't exist, then simply don't registerf an evolving object.
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
	end

	-- Default
	local time = 1 * evolvingObjectModule.yearLength
	local yearTime = evolvingObjectComponent:get("time_years"):value()
	if yearTime then
		time = yearTime * evolvingObjectModule.yearLength
	end

	local dayTime = evolvingObjectComponent:get("time_days"):value()
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
-- Craftable
---------------------------------------------------------------------------------

--- Returns a lua table, containing the shared keys between craftables and buildables
function objectManager:getCraftableBase(description, craftableComponent)
	
	-- Modules
	local skillModule = moduleManager:get("skill")
	local craftableModule = moduleManager:get("craftable")
	local toolModule = moduleManager:get("tool")
	local actionSequenceModule = moduleManager:get("actionSequence")
	local gameObjectModule = moduleManager:get("gameObject")

	-- Setup
	local identifier = description:get("identifier"):required():value()

	local tool = craftableComponent:get("tool"):asTypeIndex(toolModule.types):value()
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
		local actionSequence = craftableComponent:get("action_sequence"):with(
			function (value)
				return utils:getTypeIndex(actionSequenceModule.types, value, "Action Sequence")
			end
		):value()
		if actionSequence then
			buildSequenceData = craftableModule:createStandardBuildSequence(actionSequence, tool)
		else
			buildSequenceData = craftableModule[craftableComponent:get("build_sequence"):required():value()]
		end
	end

	local craftableBase = {
		name = description:get("name"):asLocalizedString(getNameLocKey(identifier)):value(),
		plural = description:get("plural"):asLocalizedString(getPluralLocKey(identifier)):value(),
		summary = description:get("summary"):asLocalizedString(getSummaryLocKey(identifier)):value(),

		buildSequence = buildSequenceData,

		skills = {
			required = craftableComponent:get("skill"):asTypeIndex(skillModule.types):value()
		},

		-- TODO throw a warning here
		iconGameObjectType = craftableComponent:get("display_object"):default(identifier):asTypeIndex(gameObjectModule.types):value(),

		requiredTools = requiredTools,

		-- TODO @Lich if getResources fails and returns nil, what should you do?
		requiredResources = craftableComponent:get("resources"):required():map(getResources):value()
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
	local mobModule = moduleManager:get("mob")

	-- Setup
	local description = config:get("description"):required():value()
	local identifier = description:get("identifier"):required():value()

	local nameKey = identifier
	if isBuildVariant then
		identifier = getBuildIdentifier(identifier)
	end

	-- Components
	local components = config:get("components"):required():value()
	local objectComponent = components:get("hs_object"):value()
	local toolComponent = components:get("hs_tool"):value()
	local harvestableComponent = components:get("hs_harvestable"):value()
	local resourceComponent = components:get("hs_resource"):value()
	local buildableComponent = components:get("hs_buildable"):value()

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
				[toolModule.propertyTypes.damage.index] = config:get("damage"):value(),
				[toolModule.propertyTypes.durability.index] = config:get("durability"):value(),
				[toolModule.propertyTypes.speed.index] = config:get("speed"):value(),
			}
		end
	end


	local harvestableTypeIndex = description:get("identifier"):required():with(
		function (value)
			if harvestableComponent ~= nil then
				return harvestableModule.typeIndexMap[value]
			end
			return nil
		end
	):value()

	local modelName = objectComponent:get("model"):required():value()
	
	-- Handle Buildable
	local newBuildableKeys = {}
	if buildableComponent then
		-- If build variant... recurse!
		if not isBuildVariant then
			objectManager:generateGameObjectInternal(config, true)
		end

		-- Inject data
		newBuildableKeys = {
			ignoreBuildRay = buildableComponent:get("ignore_build_ray"):default(true):value(),
			isPathFindingCollider = buildableComponent:get("has_collisions"):default(true):value(),
			preventGrassAndSnow = buildableComponent:get("clear_ground"):default(true):value(),
			disallowAnyCollisionsOnPlacement = buildableComponent:get("allow_placement_collisions"):default(true):with(
				function (value)
					return not value
				end
			):value(),
			
			isBuiltObject = not isBuildVariant,
			isInProgressBuildObject = isBuildVariant
		}

		-- Build variant doesnt get seats
		if not isBuildVariant then
			newBuildableKeys.seatTypeIndex = buildableComponent:get("seat_type"):asTypeIndex(seatModule.types):value()
		end
	end

	local newGameObject = {
		name = description:get("name"):asLocalizedString(getNameLocKey(nameKey)):value(),
		plural = description:get("plural"):asLocalizedString(getPluralLocKey(nameKey)):value(),
		modelName = modelName,
		scale = objectComponent:get("scale"):default(1):value(),
		hasPhysics = objectComponent:get("physics"):default(true):value(),
		resourceTypeIndex = resourceTypeIndex,
		-- mobTypeIndex = mobModule.typeIndexMap[identifier], Injected Later
		harvestableTypeIndex = harvestableTypeIndex,
		toolUsages = toolUsage,
		craftAreaGroupTypeIndex = buildableComponent:get("craft_area"):asTypeIndex(craftAreaGroupModule.types):value(),

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	utils:addProps(newGameObject, objectComponent, "props", {
		-- No defaults, that's OK
	})

	-- Combine keys
	local outObject = utils:merge(newGameObject, newBuildableKeys)

	-- Debug
	local debug = config:get("debug"):default(false):value()
	if debug then
		log:schema("ddapi", "[GameObject] Debugging: " .. identifier)
		log:schema("ddapi", "Config:")
		log:schema("ddapi", config)
		log:schema("ddapi", "Output:")
		log:schema("ddapi", outObject)
	end

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
			color = tbl:get("color"):required():asVec3(),		
			roughness = tbl:get("roughness"):default(1):ofType("number"):value(), 
			metal = tbl:get("metal"):default(0):ofType("number"):value(),
		}
	end

	local identifier = material:get("identifier"):required():isNotInTable(moduleManager:get("material").types):value()
	-- TODO : @Lich if isNotInTable fails, :value() will return nil. Needs to be handled
	log:schema("ddapi", "  " .. identifier)
	
	local materialData = loadMaterialFromTbl(material)
	local materialDataB = loadMaterialFromTbl(material:get("b_material"):value())
	materialModule:addMaterial(identifier, materialData.color, materialData.roughness, materialData.metal, materialDataB)
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

function objectManager:generateSkillDefinition(config)
	-- TODO : To be redone. Currently disabled

	--[[
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
	]]
end

---------------------------------------------------------------------------------
-- Plannable Actions
---------------------------------------------------------------------------------

function objectManager:generatePlanDefinition(config)
	
	-- Modules
	local planModule = moduleManager:get("plan")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local components = config:get("components"):required():value()

	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Components
	local planComponent = components:get("hs_plan"):value()

	if not planComponent then
		return
	end

	local newPlan = {
		key = identifier,
		name = description:get("name"):asLocalizedString(getNameKey("plan", identifier)):value(),
		inProgress = description:get("inProgress"):asLocalizedString(getInProgressKey("plan", identifier)):value(),
		icon = description:get("icon"):required():ofType("string"):value(),

		checkCanCompleteForRadialUI = planComponent:get("showsOnWheel"):default(true):ofType("boolean"):value(), 
		allowsDespiteStatusEffectSleepRequirements = planComponent:get("skipSleepRequirement"):value(),  
		shouldRunWherePossible = planComponent:get("walkSpeed"):with(function(value) return value == "run" end):value(), 
		shouldJogWherePossible = planComponent:get("walkSpeed"):with(function(value) return value == "job" end):value(), 
		skipFinalReachableCollisionPathCheck = planComponent:get("collisionPathCheck"):with(function(value) return value == "skip" end):value(), 
		skipFinalReachableCollisionAndVerticalityPathCheck = planComponent:get("collisionPathCheck"):with(function(value) return value == "skipVertical" end):value(),
		allowOtherPlanTypesToBeAssignedSimultaneously = planComponent:get("simultaneousPlans"):forEach( 
			function(planKey)
				return utils:getTypeIndex(planModule.types, planKey), true
			end
		):value()
	}
		
	if utils:hasKey(planComponent, "props") then
		utils:addProps(newPlan, planComponent, "props", {
			requiresLight = true
		})
	end

	typeMapsModule:insert("plan", planModule.types, newPlan)
	return planModule.types[identifier].index
end

function objectManager:generateActionDefinition(config)
	-- Modules
	local actionModule = moduleManager:get("action")
	local skillModule = moduleManager:get("skill")
	local toolModule = moduleManager:get("tool")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local components = config:get("components"):required():value()

	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Components
	local actionComponent = components:get("hs_action"):value()
	
	if not actionComponent then return end

	local newAction = {
		key = identifier, 
		name = description:get("name"):asLocalizedString(getNameKey("action", identifier)):value(), 
		inProgress = description:get("inProgress"):asLocalizedString(getInProgressKey("action", identifier)):value(), 
		restNeedModifier = actionComponent:get("restNeedModifier"):required():ofType("number"), 
	}

	if utils:hasKey(actionComponent, "props") then
		utils:addProps(newAction, actionComponent, "props", {
			--No defaults
		})
	end

	typeMapsModule:insert("action", actionModule.types, newAction)
	return actionModule.types[identifier].index
end

function objectManager:generateActionModifierDefinition(config)
	-- Modules
	local actionModule = moduleManager:get("action")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local components = config:get("components"):required():value()

	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Components
	local actionModifierTypeComponent = components:get("hs_actionModifierType"):value()

	if not actionModifierTypeComponent then return end 

	local newActionModifier = {
		key = identifier, 
		name = description:get("name"):asLocalizedString(getNameKey("action", identifier)):value(), 
		inProgress = description:get("inProgress"):asLocalizedString(getInProgressKey("action", identifier)):value(), 
	}

	if utils:hasKey(actionModifierTypeComponent, "props") then
		utils:addProps(newActionModifier, actionModifierTypeComponent, "props", {
			--No defaults
		})
	end

	typeMapsModule:insert("actionModifier", actionModule.modifierTypes, newActionModifier)
	return actionModule.modifierTypes[identifier].index
end

function objectManager:generateActionSequenceDefinition(config)
	-- Modules
	local actionModule = moduleManager:get("action")
	local actionSequenceModule = moduleManager:get("actionSequence")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local components = config:get("components"):required():value()

	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Components
	local actionSequenceComponent = components:get("hs_actionSequence"):value()

	if not actionSequenceComponent then return end

	local newActionSequence = {
		key = identifier, 
		actions = actionSequenceComponent:get("actions"):required():ofType("table"):map(
			function(a)
				return utils:getTypeIndex(actionModule.types, a, "Action")
			end
		):value(), 
		assignedTriggerIndex = actionSequenceComponent:get("assignedTriggerIndex"):required():ofType("number"):value(), 
		assignModifierTypeIndex = actionSequenceComponent:get("modifier"):asTypeIndex(actionModule.modifierTypes):value()
	}

	if utils:hasKey(actionSequenceComponent, "props") then
		utils:addProps(newActionSequence, actionSequenceComponent, "props", {
			--No defaults
		})
	end

	typeMapsModule:insert("actionSequence", actionSequenceModule.types, newActionSequence)
	return actionSequenceModule.types[identifier].index
end

function objectManager:generateOrderDefinition(config)
	-- Modules
	local orderModule = moduleManager:get("order")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = config:get("description"):required():value()
	local components = config:get("components"):required():value()

	local identifier = description:get("identifier"):required():value()
	log:schema("ddapi", "  " .. identifier)

	-- Components
	local orderComponent = components:get("hs_order"):value()

	local newOrder = {
		key = identifier, 
		name = description:get("name"):asLocalizedString(getNameKey("order", identifier)):value(), 
		inProgressName = description:get("inProgress"):asLocalizedString(getInProgressKey("order", identifier)):value(),  
		icon = description:get("icon"):required():ofType("string"):value(), 
	}

	if utils:hasKey(orderComponent, "props") then
		utils:addProps(newOrder, orderComponent, "props", {
			--No defaults
		})
	end

	typeMapsModule:insert("order", orderModule.types, newOrder)
	return orderModule.types[identifier].index
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

	-- Special one: This handles injecting 'displayGameObjectTypeIndex' into the storage, once game objects have been created.
	-- storageDisplayGameObjectTypeIndexHandler = {
	-- 	configType = configLoader.configTypes.storage,
	-- 	dependencies = {
	-- 		"gameObject"
	-- 	},
	-- 	loadFunction = objectManager.handleStorageDisplayGameObjectTypeIndex
	-- },

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
			"gameObject",

			"research" -- TODO: Test to ensure this isn't causing load order issues. See research.lua
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
			-- "resourceGroups", -- Adding this dependency breaks the craftable menu. Why was this originally added?
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

	mob = {
		configType = configLoader.configTypes.object,
		waitingForStart = true, -- Set to true in `mob.lua`
		moduleDependencies = {
			"mob",
			"gameObject",
			"animationGroups"
		},
		loadFunction = objectManager.generateMobObject
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
	
	resourceGroupHandler = {
		configType = configLoader.configTypes.object,
		dependencies = {
			"resourceGroups",
			"resource"
		},
		loadFunction = objectManager.handleResourceGroups
	},

	plan = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"plan",
			"typeMaps"
		}, 
		loadFunction = objectManager.generatePlanDefinition
	},

	order = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"order",
			"typeMaps",
		},
		loadFunction = objectManager.generateOrderDefinition
	}, 

	action = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"action",
			"typeMaps",
			"tool",
			"skill", 
		}, 
		loadFunction = objectManager.generateActionDefinition
	}, 

	actionSequence = {
		configType = configLoader.configTypes.plannableAction,
		moduleDependencies = {
			"actionSequence", 
			"action",
			"typeMaps"
		},
		dependencies = {
			"action"
		}, 
		loadFunction = objectManager.generateActionSequenceDefinition
	},

	actionModifier = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"action", 
			"typeMaps"
		}, 
		loadFunction = objectManager.generateActionModifierDefinition
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
	}, 
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
	log:schema("ddapi", "Object has been marked for load: " .. configName)
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
