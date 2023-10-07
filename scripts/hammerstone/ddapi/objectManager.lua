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
local utils = mjrequire "hammerstone/ddapi/objectUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local configLoader = mjrequire "hammerstone/ddapi/configLoader"
local hammerAPI = mjrequire "hammerAPI"
mjrequire "hammerstone/utils/hmTable"

hammerAPI:test()

-- Whether to crash (for development), or attempt to recover (for release).
local crashes = true

----------------------------
-- utils for locale
----------------------------
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

---------------------------------------------------------------------------------
-- Model Placeholder
---------------------------------------------------------------------------------

do
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

	function objectManager:generateModelPlaceholder(objDef)
		-- Modules
		local modelPlaceholderModule = moduleManager:get("modelPlaceholder")
		local resourceModule = moduleManager:get("resource")

		-- Setup
		local description = objDef:getTable("description")
		local identifier = description:getStringValue("identifier")

		-- Components
		local components = objDef:getTable("components")
		local buildableComponent = components:getTableOrNil("hs_buildable")
		local objectComponent = components:getTableOrNil("hs_object")
		
		--- Don't generate for non-buildables
		if buildableComponent:getValue() == nil then
			return
		end
		
		-- Otherwise, give warning on potential ill configuration
		if buildableComponent.model_placeholder == nil then
			log:schema("ddapi", string.format("   Warning: %s is being created without a model placeholder. In this case, you are responsible for creating one yourself.", identifier))
			return
		end

		-- TODO @Lich = You set objectComponent as 'optional'. 
		-- Shouldn't you check if it's nil first?
		-- This code will throw an exception if objectComponent is nil
		local modelName = objectComponent:getStringValue("model")
		log:schema("ddapi", string.format("  %s (%s)", identifier, modelName))
		
		-- TODO @Lich you warned that model_placeholder is nil before but didn't set it as optional
		-- So I use "getTable" instead of "getTableOrNil". Is that the intention?
		-- This will crash
		local modelPlaceholderData = buildableComponent:getTable("model_placeholder"):select(
			function(data)

				local isStore = data:getBooleanOrNil("is_store"):default(false):getValue()
				
				if isStore then
					return {
						key = data:getStringValue("key"),
						offsetToStorageBoxWalkableHeight = true
					}
				else
					local default_model = data:getStringValue("default_model")
					local resource_type = data:getString("resource"):asTypeIndex(resourceModule.types)
					local resource_name = data:getStringValue("resource")
					local remap_data = data:getTableOrNil("remaps"):default( { [resource_name] = default_model } )

						
					return {
						key = data:getStringValue("key"),
						defaultModelName = default_model,
						resourceTypeIndex = resource_type,

						-- TODO
						additionalIndexCount = data:getNumberValueOrNil("additional_index_count"),
						defaultModelShouldOverrideResourceObject = data:getNumberValueOrNil("use_default_model"),
						placeholderModelIndexForObjectTypeFunction = createIndexFunction(remap_data, default_model)
					}
				end

			end
		):clear() -- Calling clear() converts it back to a regular non hmt table

		utils:debug(identifier, objDef, modelPlaceholderData)
		modelPlaceholderModule:addModel(modelName, modelPlaceholderData)

		return modelPlaceholderData
	end
end


---------------------------------------------------------------------------------
-- Custom Model
---------------------------------------------------------------------------------

function objectManager:generateCustomModel(modelRemap)
	-- Modules
	local modelModule = moduleManager:get("model")

	local model = modelRemap:getStringValue("model")
	local baseModel = modelRemap:getStringValue("base_model")
	log:schema("ddapi", baseModel .. " --> " .. model)

	local materialRemaps = modelRemap:getTableOrNil("material_remaps"):default({}):getValue()
	
	-- Ensure exists
	if modelModule.remapModels[baseModel] == nil then
		modelModule.remapModels[baseModel] = {}
	end
	
	-- Inject so it's available
	modelModule.remapModels[baseModel][model] = materialRemaps

	return materialRemaps
end

---------------------------------------------------------------------------------
-- Buildable
---------------------------------------------------------------------------------

local function getResources(e)
	local resourceModule = moduleManager:get("resource")
	local actionModule = moduleManager:get("action")

	-- Get the resource (as group, or resource)
	local resourceType = e:getStringOrNil("resource"):asTypeIndex(resourceModule.types)
	local groupType =  e:getStringOrNil("resource_group"):asTypeIndex(resourceModule.groups)

	-- Get the count
	local count = e:getOrNil("count"):asNumberOrNil():default(1):getValue()

	if e:hasKey("action") then
		
		local action = e:getTable("action")

		-- Return if action is invalid
		local actionType = action:getStringOrNil("action_type"):default("inspect"):asTypeIndex(actionModule.types, "Action")
		if (actionType == nil) then return end

		local duration = action:get("duration"):asNumberValue()
		local durationWithoutSkill = action:get("duration_without_skill"):default(duration):asNumberValue()

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

local function getBuildModelName(objectComponent, craftableComponent)
	local modelName = objectComponent:getStringValueOrNil("model")
	if modelName then
		return modelName
	end
	
	-- TODO @Lich can't you just return objectComponent:getStringValue("model") and let it be nil if it is?
	return false
end

function objectManager:generateBuildable(objDef)
	-- Modules
	local buildableModule = moduleManager:get("buildable")
	local constructableModule = moduleManager:get("constructable")
	local planModule = moduleManager:get("plan")
	local researchModule = moduleManager:get("research")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")

	-- Optional Components
	local objectComponent = components:getTableOrNil("hs_object"):default({})
	local buildableComponent = components:getTableOrNil("hs_buildable")

	-- Not everything is a buildable. Expected soft return.
	if buildableComponent:getValue() == nil then
		return
	end

	log:schema("ddapi", "  " .. identifier)

	local newBuildable = objectManager:getCraftableBase(description, buildableComponent)

	-- Buildable Specific Stuff
	newBuildable.classification =buildableComponent:getStringOrNil("classification"):default("build"):asTypeIndex(constructableModule.classifications)
	newBuildable.modelName = getBuildModelName(objectComponent, buildableComponent)
	newBuildable.inProgressGameObjectTypeKey = getBuildIdentifier(identifier)
	newBuildable.finalGameObjectTypeKey = identifier
	newBuildable.buildCompletionPlanIndex =buildableComponent:getStringOrNil("build_completion_plan"):asTypeIndex(planModule.types)

	local research = buildableComponent:getStringValueOrNil("research")
	if research ~= nil then
		newBuildable.disabledUntilAdditionalResearchDiscovered = researchModule.typeIndexMap[research]
	end

	local defaultValues = hmt{
		allowBuildEvenWhenDark = false,
		allowYTranslation = true,
		allowXZRotation = true,
		noBuildUnderWater = true,
		canAttachToAnyObjectWithoutTestingForCollisions = false
	}

	newBuildable = defaultValues:mergeWith(buildableComponent:getTableOrNil("props")):default({}):mergeWith(newBuildable):clear()
	
	utils:debug(identifier, objDef, newBuildable)
	buildableModule:addBuildable(identifier, newBuildable)
	
	-- Cached, and handled later in buildUI.lua
	table.insert(objectManager.constructableIndexes, constructableModule.types[identifier].index)
end

function objectManager:generateCraftable(objDef)
	-- Modules
	local constructableModule = moduleManager:get("constructable")
	local gameObjectModule =  moduleManager:get("gameObject")
	local craftAreaGroupModule = moduleManager:get("craftAreaGroup")
	local craftableModule = moduleManager:get("craftable")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")

	-- Optional Components
	local craftableComponent = components:getTableOrNil("hs_craftable")

	-- Not everything is a craftable. Expected soft return.
	if craftableComponent:getValue() == nil then
		return
	end

	-- TODO
	local outputComponent = craftableComponent:getTableOrNil("hs_output")

	log:schema("ddapi", "  " .. identifier)

	local newCraftable = objectManager:getCraftableBase(description, craftableComponent)

	local outputObjectInfo = nil
	local hasNoOutput = outputComponent:getValue() == nil

	local function mapIndexes(key, value)
		-- Get the input's resource index
		local index = key:asTypeIndex(gameObjectModule.types, "Game Object")

		-- Convert from schema format to vanilla format
		-- If the predicate returns nil for any element, map returns nil
		-- In this case, log an error and return if any output item does not exist in gameObject.types
		local indexTbl = value:asTypeIndex(gameObjectModule.types, "Game Object")

		
		return index, indexTbl
	end

	if outputComponent:getValue() then
		outputObjectInfo = {
			objectTypesArray = outputComponent:getTableOrNil("simple_output"):asTypeIndex(gameObjectModule.types),
			outputArraysByResourceObjectType = outputComponent:getTableOrNil("output_by_object"):with(
				function(value)
					if value then
						return hmt(value):selectPairs(mapIndexes, hmtPairsMode.KeysAndValues)
					end
				end
			):getValue()				
		}

		if type(outputObjectInfo.outputArraysByResourceObjectType) == "table" then
			outputObjectInfo.outputArraysByResourceObjectType:clear()
		end
	end

	local craftArea = craftableComponent:getStringOrNil("craft_area"):asTypeIndex(craftAreaGroupModule.types)
	local requiredCraftAreaGroups = nil
	if craftArea then
		requiredCraftAreaGroups = {
			craftArea
		}
	end

	-- Craftable Specific Stuff
	newCraftable.classification = craftableComponent:getStringOrNil("classification"):default("craft"):asTypeIndex(constructableModule.classifications)
	newCraftable.hasNoOutput = hasNoOutput
	newCraftable.outputObjectInfo = outputObjectInfo
	newCraftable.requiredCraftAreaGroups = requiredCraftAreaGroups
	newCraftable.inProgressBuildModel = craftableComponent:getStringOrNil("build_model"):default("craftSimple"):getValue()

	if craftableComponent:hasKey("props") then
		newCraftable = craftableComponent:getTable("props"):mergeWith(newCraftable):clear()
	end

	-- TODO : @Lich: it can't be nil... you just put stuff in it
	if newCraftable ~= nil then


		-- Debug
		local debug = objDef:getBooleanValueOrNil("debug")
		if debug then
			log:schema("ddapi", "Debugging: " .. identifier)
			log:schema("ddapi", "Config:")
			log:schema("ddapi", objDef)
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

function objectManager:generateResource(objDef)
	-- Modules
	local typeMapsModule = moduleManager:get("typeMaps")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")
	local name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier))
	local plural = description:getStringOrNil("plural"):asLocalizedString(getNameLocKey(identifier))

	-- Components
	local components = objDef:getTable("components")
	local resourceComponent = components:getTableOrNil("hs_resource")
	local foodComponent = components:getTableOrNil("hs_food")

	-- Nil Resources aren't created
	if resourceComponent:getValue() == nil  then
		return
	end

	log:schema("ddapi", "  " .. identifier)
	
	local displayObject = resourceComponent:getStringOrNil("display_object"):default(identifier):getValue()

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = typeMapsModule.types.gameObject[displayObject] 
	}

	-- TODO: Missing Properties
	-- placeBuildableMaleSnapPoints

	-- Handle Food
	if foodComponent:getValue() ~= nil then
		newResource.foodValue = foodComponent:getNumberOrNil("value"):default(0.5):getValue()
		newResource.foodPortionCount = foodComponent:getNumberOrNil("portions"):default(1):getValue()
		newResource.foodPoisoningChance = foodComponent:getNumberOrNil("food_poison_chance"):default(0):getValue()
		newResource.defaultToEatingDisabled = foodComponent:getBooleanOrNil("default_disabled"):default(false):getValue()
	end

	if resourceComponent:hasKey("props") then
		newResource = resourceComponent:getTable("props"):mergeWith(newResource).clear()
	end

	resourceModule:addResource(identifier, newResource)
end

---------------------------------------------------------------------------------
-- Eat By Products Handler
---------------------------------------------------------------------------------

function objectManager:handleEatByProducts(objDef)
	-- Modules
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")
	local foodComponent = components:getTableOrNil("hs_food")

	if foodComponent:getValue() == nil then
		return
	end
	
	local eatByProducts = foodComponent:getTable("items_when_eaten"):asTypeIndex(gameObjectModule.types, "Game Object")

	log:schema("ddapi", string.format("  Adding  eatByProducts to '%s'", identifier))

	-- Inject into the object
	gameObjectModule.types[identifier].eatByProducts = eatByProducts

	return eatByProducts
end

---------------------------------------------------------------------------------
-- storageDisplayGameObjectTypeIndex
---------------------------------------------------------------------------------

function objectManager:handleStorageDisplayGameObjectTypeIndex(objDef)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")
	local storageComponent = components:getTableOrNil("hs_storage")

	if storageComponent:getValue() == nil then
		return
	end

	local displayObject = storageComponent:getStringOrNil("display_object"):default(identifier):getValue()
	local displayIndex = typeMapsModule.types.gameObject[displayObject]

	-- Inject into the object
	log:schema("ddapi", string.format("  Adding display_object '%s' to storage '%s', with index '%s'", displayObject, identifier, displayIndex))
	storageModule.types[identifier].displayGameObjectTypeIndex = displayIndex
	storageModule:mjInit()
end

---------------------------------------------------------------------------------
-- Storage Links
---------------------------------------------------------------------------------

function objectManager:handleStorageLinks(objDef)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")
	local resourceComponent = components:getTableOrNil("hs_resource")

	if resourceComponent:getValue() ~= nil then
		local storageIdentifier = resourceComponent:getStringValue("storage_identifier")

		log:schema("ddapi", string.format("  Adding resource '%s' to storage '%s'", identifier, storageIdentifier))
		table.insert(utils:getType(storageModule.types, storageIdentifier, "storage").resources, utils:getTypeIndex(resourceModule.types, identifier))

		storageModule:mjInit()
	end
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

function objectManager:generateStorageObject(objDef)
	-- Modules
	local storageModule = moduleManager:get("storage")
	local resourceModule = moduleManager:get("resource")
	local typeMapsModule = moduleManager:get("typeMaps")

	-- Load structured information
	local description = objDef:getTable("description")

	-- Components
	local components = objDef:getTable("components")
	local carryComponent = components:getTable("hs_carry")
	local storageComponent = components:getTable("hs_storage")

	-- Print
	local identifier = description:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	-- Allow this field to be undefined, but don't use nil, since we will pull props from here later, with their *own* defaults
	local carryCounts = carryComponent:getTableOrNil("hs_carry_count"):default({})

	local displayObject = storageComponent:getStringOrNil("display_object"):default(identifier):getValue()
	local displayIndex = typeMapsModule.types.gameObject[displayObject]
	log:schema("ddapi", string.format("  Adding display_object '%s' to storage '%s', with index '%s'", displayObject, identifier, displayIndex))

	-- The new storage item

	local baseRotationWeight = storageComponent:getNumberOrNil("base_rotation_weight"):default(0):getValue()
	local baseRotationValue = storageComponent:getTableOrNil("base_rotation"):default(vec3(1.0, 0.0, 0.0)):asVec3()
	local randomRotationWeight = storageComponent:getNumberOrNil("random_rotation_weight"):default(2.0):getValue()
	local randomRotation = storageComponent:getTableOrNil("random_rotation"):default(vec3(1, 0.0, 0.0)):asVec3()

	local newStorage = {
		key = identifier,
		name = description:getStringOrNil("name"):asLocalizedString(getNameKey("storage", identifier)),

		displayGameObjectTypeIndex = displayIndex,
		
		resources = storageComponent:getTableOrNil("resources"):default({}):asTypeIndex(resourceModule.types, "Resource"),

		storageBox = {
			size =  storageComponent:getTableOrNil("item_size"):default(vec3(0.5, 0.5, 0.5)):asVec3(),
			

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
			
			placeObjectOffset = mj:mToP(storageComponent:getTableOrNil("place_offset"):default(vec3(0.0, 0.0, 0.0)):asVec3()),

			placeObjectRotation = mat3Rotate(
				mat3Identity,
				math.pi * storageComponent:getNumberOrNil("place_rotation_weight"):default(0.0):getValue(),
				storageComponent:getTableOrNil("place_rotation"):default(vec3(0.0, 0.0, 1)):asVec3()
			),
		},

		maxCarryCount = carryCounts:getNumberOrNil("normal"):default(1):getValue(),
		maxCarryCountLimitedAbility = carryCounts:getNumberOrNil("limited_ability"):default(1):getValue(),
		maxCarryCountForRunning = carryCounts:getNumberOrNil("running"):default(1):getValue(),


		carryStackType = storageModule.stackTypes[carryComponent:getStringOrNil("stack_type"):default("standard"):getValue()],
		carryType = storageModule.carryTypes[carryComponent:getStringOrNil("carry_type"):default("standard"):getValue()],

		carryOffset = carryComponent:getTableOrNil("offset"):default(vec3(0.0, 0.0, 0.0)):asVec3(),

		carryRotation = mat3Rotate(mat3Identity,
			carryComponent:getNumberOrNil("rotation_constant"):default(1):getValue(),
			carryComponent:getTableOrNil("rotation"):default(vec3(0.0, 0.0, 1.0)):asVec3()
		),
	}
	
	if storageComponent:hasKey("props") then
		newStorage = storageComponent:getTable("props"):mergeWith(newStorage):clear()
	end

	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Plan Helper
---------------------------------------------------------------------------------

function objectManager:generatePlanHelperObject(objDef)
	-- Modules
	local planHelperModule = moduleManager:get("planHelper")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local components = objDef:getTable("components")
	local description = objDef:getTable("description")
	local plansComponent = components:getTableOrNil("hs_plans")

	if plansComponent:getValue() == nil then
		return
	end


	local objectIndex = description:getString("identifier"):asTypeIndex(gameObjectModule.types)
	local availablePlansFunction = plansComponent:getStringOrNil("available_plans"):with(
		function (value)
			return planHelperModule[value]
		end
	):getValue()

	-- Nil plans would override desired vanilla plans
	if availablePlansFunction ~= nil then
		planHelperModule:setPlansForObject(objectIndex, availablePlansFunction)
	end
end

---------------------------------------------------------------------------------
-- Mob Object
---------------------------------------------------------------------------------

function objectManager:generateMobObject(objDef)
	-- Modules
	local mobModule = moduleManager:get("mob")
	local gameObjectModule = moduleManager:get("gameObject")
	local animationGroupsModule = moduleManager:get("animationGroups")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")
	local name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier))
	local components = objDef:getTable("components")
	local mobComponent = components:getTableOrNil("hs_mob")
	local objectComponent = components:getTableOrNil("hs_object")

	if mobComponent:getValue() == nil then
		return
	end
	log:schema("ddapi", "  " .. identifier)

	local mobObject = {
		name = name,
		gameObjectTypeIndex = gameObjectModule.types[identifier].index,
		deadObjectTypeIndex = mobComponent:getString("dead_object"):asTypeIndex(gameObjectModule.types),
		animationGroupIndex = mobComponent:getString("animation_group"):asTypeIndex(animationGroupsModule),
	}

	if mobComponent:hasKey("props") then
		mobObject = mobComponent:getTable("props"):mergeWith(mobObject):clear()
	end

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

function objectManager:generateHarvestableObject(objDef)
	-- Modules
	local harvestableModule = moduleManager:get("harvestable")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local identifier = objDef:getTable("description"):getStringValue("identifier")
	local components = objDef:getTable("components")
	local harvestableComponent = components:getTableOrNil("hs_harvestable")

	if harvestableComponent:getValue() == nil then
		return -- This is allowed
	end
	
	log:schema("ddapi", "  " .. identifier)

	local resourcesToHarvest = harvestableComponent:getTable("resources_to_harvest"):asTypeMapType(gameObjectModule.typeIndexMap)

	local finishedHarvestIndex = harvestableComponent:getNumberOrNil("finish_harvest_index"):default(#resourcesToHarvest):getValue()
	harvestableModule:addHarvestableSimple(identifier, resourcesToHarvest, finishedHarvestIndex)
end

---------------------------------------------------------------------------------
-- Object Sets
---------------------------------------------------------------------------------

function objectManager:generateObjectSets(key)
	local serverGOMModule = moduleManager:get("serverGOM")

	local value = key:getValue()
	log:schema("ddapi", "  " .. value)
	serverGOMModule:addObjectSet(value)
end

---------------------------------------------------------------------------------
-- Animation Groups
---------------------------------------------------------------------------------

function objectManager:generateAnimationGroups(key)
	local animationGroupsModule = moduleManager:get("animationGroups")

	local value = key:getValue()
	log:schema("ddapi", "  " .. value)
	animationGroupsModule:addAnimationGroup(value)
end

---------------------------------------------------------------------------------
-- Resource Groups
---------------------------------------------------------------------------------

function objectManager:generateResourceGroup(groupDefinition)
	-- Modules
	local resourceModule = moduleManager:get("resource")
	local gameObjectModule  = moduleManager:get("gameObject")

	local identifier = groupDefinition:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local name = groupDefinition:getStringOrNil("name"):asLocalizedString(getNameKey("group", identifier))
	local plural = groupDefinition:getStringOrNil("plural"):asLocalizedString(getPluralKey("group", identifier))

	local newResourceGroup = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = groupDefinition:getString("display_object"):asTypeIndex(gameObjectModule.types),
		resourceTypes = groupDefinition:getTable("resources"):asTypeIndex(resourceModule.types, "Resource Types")
	}

	resourceModule:addResourceGroup(identifier, newResourceGroup)
end

-- Special handler which allows resources to inject themselves into existing resource groups. Runs
-- after resource groups are already created
function objectManager:handleResourceGroups(objDef)
	-- Modules
	local resourceModule = moduleManager:get("resource")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	-- Components
	local components = objDef:getTable("components")
	local resourceComponent = components:getTableOrNil("hs_resource")
	if resourceComponent:getValue() == nil then
		return
	end

	local resourceGroups = resourceComponent:getTableValueOrNil("resource_groups")
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

function objectManager:generateSeat(seatType)
	-- Modules
	local seatModule = moduleManager:get("seat")
	local typeMapsModule = moduleManager:get("typeMaps")
	
	local identifier = seatType:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local newSeat = {
		key = identifier,
		comfort = seatType:getNumberOrNil("comfort"):default(0.5):getValue(),
		nodes = seatType:getTable("nodes"):select(
			function(node)
				return {
					placeholderKey = node:getStringValue("key"),
					nodeTypeIndex = node:getString("type"):asTypeIndex(seatModule.nodeTypes)
				}
			end
		,true):clear()
	}

	typeMapsModule:insert("seat", seatModule.types, newSeat)
end

---------------------------------------------------------------------------------
-- Object Snapping
---------------------------------------------------------------------------------

function objectManager:generateObjectSnapping(def)
	-- Modules
	local sapienObjectSnappingModule = moduleManager:get("sapienObjectSnapping")
	local gameObjectModule = moduleManager:get("gameObject")

	-- Setup
	local identifier = def:getTable("description"):getString("identifier")
	local objectIndex = identifier:asTypeIndex(gameObjectModule.types)
	local snappingPreset = def:getTable("components"):getTableOrNil("hs_object"):getStringOrNil("snapping_preset")

	if snappingPreset:getValue() ~= nil  then
		local snappingPresetIndex = snappingPreset:asTypeIndex(gameObjectModule.types)

		local snappingPresetFunction = sapienObjectSnappingModule.snapObjectFunctions[snappingPresetIndex]

		if snappingPresetFunction ~= nil then
			log:schema("ddapi", string.format("  Object '%s' is using snapping preset '%s' (index='%s')", identifier:getValue(), snappingPreset:getValue(), snappingPresetIndex))
			sapienObjectSnappingModule.snapObjectFunctions[objectIndex] = snappingPresetFunction
		else
			log:schema("ddapi", string.format("  Warning: Object '%s' is using trying to use snapping preset '%s' (index='%s'), which doesn't exist!", identifier:getValue(), snappingPreset:getValue(), snappingPresetIndex))
		end
	end
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

--- Generates evolving object definitions. For example an orange rotting into a rotten orange.
function objectManager:generateEvolvingObject(objDef)
	-- Modules
	local evolvingObjectModule = moduleManager:get("evolvingObject")
	local gameObjectModule =  moduleManager:get("gameObject")

	-- Setup
	local components = objDef:getTable("components")
	local evolvingObjectComponent = components:getTableOrNil("hs_evolving_object")
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")
	
	-- If the component doesn't exist, then simply don't register an evolving object.
	if evolvingObjectComponent:getValue() == nil then
		return -- This is allowed	
	else
		log:schema("ddapi", "  " .. identifier)
	end

	-- Default
	local time = 1 * evolvingObjectModule.yearLength
	local yearTime = evolvingObjectComponent:getNumberValueOrNil("time_years")
	if yearTime then
		time = yearTime * evolvingObjectModule.yearLength
	end

	local dayTime = evolvingObjectComponent:getNumberValueOrNil("time_days")
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
			for i, id in ipairs(transform_to) do
				table.insert(newResource, gameObjectModule.types[id].index)
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
	local identifier = description:getStringValue("identifier")

	local tool = craftableComponent:getStringOrNil("tool"):asTypeIndex(toolModule.types)
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
		local actionSequence = craftableComponent:getStringOrNil("action_sequence"):asTypeIndex(actionSequenceModule.types, "Action Sequence")
		if actionSequence then
			buildSequenceData = craftableModule:createStandardBuildSequence(actionSequence, tool)
		else
			buildSequenceData = craftableModule[craftableComponent:getStringValue("build_sequence")]
		end
	end

	local craftableBase = {
		name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier)),
		plural = description:getStringOrNil("plural"):asLocalizedString(getPluralLocKey(identifier)),
		summary = description:getStringOrNil("summary"):asLocalizedString(getSummaryLocKey(identifier)),

		buildSequence = buildSequenceData,

		skills = {
			required = craftableComponent:getStringOrNil("skill"):asTypeIndex(skillModule.types)
		},

		-- TODO throw a warning here
		iconGameObjectType = craftableComponent:getStringOrNil("display_object"):default(identifier):asTypeIndex(gameObjectModule.types),

		requiredTools = requiredTools,

		requiredResources = craftableComponent:getTable("resources"):select(getResources, true):clear()
	}

	return craftableBase
end

-- TODO: selectionGroupTypeIndexes
function objectManager:generateGameObject(objDef)
	return objectManager:generateGameObjectInternal(objDef, false)
end

function objectManager:generateGameObjectInternal(objDef, isBuildVariant)
	-- Modules
	local gameObjectModule = moduleManager:get("gameObject")
	local resourceModule = moduleManager:get("resource")
	local toolModule = moduleManager:get("tool")
	local harvestableModule = moduleManager:get("harvestable")
	local seatModule = moduleManager:get("seat")
	local craftAreaGroupModule = moduleManager:get("craftAreaGroup")
	--local mobModule = moduleManager:get("mob")

	-- Setup
	local description = objDef:getTable("description")
	local identifier = description:getStringValue("identifier")

	local nameKey = identifier
	if isBuildVariant then
		identifier = getBuildIdentifier(identifier)
	end

	-- Components
	local components = objDef:getTable("components")
	local objectComponent = components:getTableOrNil("hs_object")
	local toolComponent = components:getTableOrNil("hs_tool")
	local harvestableComponent = components:getTableOrNil("hs_harvestable")
	local resourceComponent = components:getTableOrNil("hs_resource")
	local buildableComponent = components:getTableOrNil("hs_buildable")

	if objectComponent:getValue() == nil then
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
	if resourceComponent:getValue() ~= nil then
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
	if toolComponent:getValue() then
		for key, tool in pairs(toolComponent) do
			tool = hmt(tool)
			local toolTypeIndex = utils:getTypeIndex(toolModule.types, key, "Tool Type")
			toolUsage[toolTypeIndex] = {
				[toolModule.propertyTypes.damage.index] = tool:getOrNil("damage"):getValue(),
				[toolModule.propertyTypes.durability.index] = tool:getOrNil("durability"):getValue(),
				[toolModule.propertyTypes.speed.index] = tool:getOrNil("speed"):getValue(),
			}
		end
	end


	local harvestableTypeIndex = description:getString("identifier"):with(
		function (value)
			if harvestableComponent:getValue() ~= nil then
				return harvestableModule.typeIndexMap[value]
			end
		end
	):getValue()

	local modelName = objectComponent:getStringValue("model")
	
	-- Handle Buildable
	local newBuildableKeys = {}
	if buildableComponent:getValue() then
		-- If build variant... recurse!
		if not isBuildVariant then
			objectManager:generateGameObjectInternal(objDef, true)
		end

		-- Inject data
		newBuildableKeys = {
			ignoreBuildRay = buildableComponent:getBooleanOrNil("ignore_build_ray"):default(true):getValue(),
			isPathFindingCollider = buildableComponent:getBooleanOrNil("has_collisions"):default(true):getValue(),
			preventGrassAndSnow = buildableComponent:getBooleanOrNil("clear_ground"):default(true):getValue(),
			disallowAnyCollisionsOnPlacement = not buildableComponent:getBooleanOrNil("allow_placement_collisions"):default(false):getValue(),
			
			isBuiltObject = not isBuildVariant,
			isInProgressBuildObject = isBuildVariant
		}

		-- Build variant doesnt get seats
		if not isBuildVariant then
			newBuildableKeys.seatTypeIndex = buildableComponent:getStringOrNil("seat_type"):asTypeIndex(seatModule.types)
		end
	end

	local newGameObject = {
		name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(nameKey)),
		plural = description:getStringOrNil("plural"):asLocalizedString(getPluralLocKey(nameKey)),
		modelName = modelName,
		scale = objectComponent:getNumberOrNil("scale"):default(1):getValue(),
		hasPhysics = objectComponent:getBooleanOrNil("physics"):default(true):getValue(),
		resourceTypeIndex = resourceTypeIndex,
		-- mobTypeIndex = mobModule.typeIndexMap[identifier], Injected Later
		harvestableTypeIndex = harvestableTypeIndex,
		toolUsages = toolUsage,
		craftAreaGroupTypeIndex = buildableComponent:getValue() and buildableComponent:getStringOrNil("craft_area"):asTypeIndex(craftAreaGroupModule.types),

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	if objectComponent:hasKey("props") then
		newGameObject = objectComponent:getTable("props"):mergeWith(newGameObject):clear()
	end

	-- Combine keys
	local outObject = hmt(newGameObject):mergeWith(newBuildableKeys):clear()

	-- Debug
	local debug = objDef:getOrNil("debug"):default(false):getValue()
	if debug then
		log:schema("ddapi", "[GameObject] Debugging: " .. identifier)
		log:schema("ddapi", "Config:")
		log:schema("ddapi", objDef)
		log:schema("ddapi", "Output:")
		log:schema("ddapi", outObject)
	end

	-- Actually register the game object
	gameObjectModule:addGameObject(identifier, outObject)
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

function objectManager:generateMaterial(material)
	-- Modules
	local materialModule = moduleManager:get("material")

	local function loadMaterialFromTbl(tbl)
		-- Allowed
		if tbl == nil then
			return nil
		end

		return {
			color = tbl:getTable("color"):asVec3(),		
			roughness = tbl:getNumberOrNil("roughness"):default(1):getValue(), 
			metal = tbl:getNumberOrNil("metal"):default(0):getValue(),
		}
	end

	local identifier = material:getString("identifier"):isNotInTypeTable(moduleManager:get("material").types):getValue()

	log:schema("ddapi", "  " .. identifier)
	
	local materialData = loadMaterialFromTbl(material)
	local materialDataB = loadMaterialFromTbl(material:getStringValueOrNil("b_material"))
	materialModule:addMaterial(identifier, materialData.color, materialData.roughness, materialData.metal, materialDataB)
end

---------------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------

function objectManager:generateSkill(objDef)
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
do
	function objectManager:generatePlan(objDef)
		
		-- Modules
		local planModule = moduleManager:get("plan")
		local typeMapsModule = moduleManager:get("typeMaps")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		local identifier = description:getStringValue("identifier")
		log:schema("ddapi", "  " .. identifier)

		-- Components
		local planComponent = components:getTableOrNil("hs_plan")

		if planComponent:isNil() then
			return
		end

		local newPlan = {
			key = identifier,
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("plan", identifier)),
			inProgress = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("plan", identifier)),
			icon = description:getStringValue("icon"),

			checkCanCompleteForRadialUI = planComponent:getBooleanOrNil("showsOnWheel"):default(true):getValue(), 
			allowsDespiteStatusEffectSleepRequirements = planComponent:getBooleanValueOrNil("skipSleepRequirement"),  
			shouldRunWherePossible = planComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "run" end):getValue(), 
			shouldJogWherePossible = planComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "job" end):getValue(), 
			skipFinalReachableCollisionPathCheck = planComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skip" end):getValue(), 
			skipFinalReachableCollisionAndVerticalityPathCheck = planComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skipVertical" end):getValue(),
			allowOtherPlanTypesToBeAssignedSimultaneously = planComponent:getTableOrNil("simultaneousPlans"):with(
				function(value)
					if value then 
						return hmt(value):selectPairs( 
							function(index, planKey)
								return utils:getTypeIndex(planModule.types, planKey), true
							end
						)
					end
				end
			):getValue()
		}

		if type(newPlan.allowOtherPlanTypesToBeAssignedSimultaneously) == "table" then
			newPlan.allowOtherPlanTypesToBeAssignedSimultaneously:clear()
		end
			
		local defaultValues = hmt{
			requiresLight = true
		}

		newPlan = defaultValues:mergeWith(planComponent:getTableOrNil("props"):default({})):mergeWith(newPlan):clear()

		typeMapsModule:insert("plan", planModule.types, newPlan)
	end

	function objectManager:generateAction(objDef)
		-- Modules
		local actionModule = moduleManager:get("action")
		local typeMapsModule = moduleManager:get("typeMaps")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		local identifier = description:getStringValue("identifier")
		log:schema("ddapi", "  " .. identifier)

		-- Components
		local actionComponent = components:getTableOrNil("hs_action")
		
		if not actionComponent:getValue() then return end

		local newAction = {
			key = identifier, 
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("action", identifier)), 
			inProgress = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("action", identifier)), 
			restNeedModifier = actionComponent:getNumberValue("restNeedModifier"), 
		}

		if actionComponent:hasKey("props") then
			newAction = actionComponent:getTable("props"):mergeWith(newAction):clear()
		end

		typeMapsModule:insert("action", actionModule.types, newAction)
	end

	function objectManager:generateActiveOrder(objDef)
		-- Modules
		local actionModule = moduleManager:get("action")
		local skillModule = moduleManager:get("skill")
		local toolModule = moduleManager:get("tool")
		local activeOrderAI = moduleManager:get("activeOrderAI")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		-- Components
		local activeOrderComponent = components:getTableOrNil("hs_activeOrder")

		if activeOrderComponent:isNil() then
			return 
		end 

		local updateInfos = {
			actionTypeIndex = description:getString("identifier"):asTypeIndex(actionModule.types, "Action"),
			checkFrequency = activeOrderComponent:getNumberValue("checkFrequency"), 
			completeFunction = activeOrderComponent:get("completeFunction"):ofType("function"):value(), 
			defaultSkillIndex = activeOrderComponent:getStringOrNil("defaultSkill"):asTypeIndex(skillModule.types, "Skill"),
			toolMultiplierTypeIndex = activeOrderComponent:getStringOrNil("toolMultiplier"):asTypeIndex(toolModule.types, "Tool")
		}

		if activeOrderComponent:hasKey("props") then
			updateInfos = activeOrderComponent:getTable("props"):mergeWith(updateInfos):clear()
		end

		activeOrderAI.updateInfos[updateInfos.actionTypeIndex] = updateInfos
	end

	function objectManager:generateActionModifier(objDef)
		-- Modules
		local actionModule = moduleManager:get("action")
		local typeMapsModule = moduleManager:get("typeMaps")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		local identifier = description:getStringValue("identifier")
		log:schema("ddapi", "  " .. identifier)

		-- Components
		local actionModifierTypeComponent = components:getTableOrNil("hs_actionModifierType")

		if not actionModifierTypeComponent:getValue() then return end 

		local newActionModifier = {
			key = identifier, 
			name = description:get("name"):asLocalizedString(getNameKey("action", identifier)), 
			inProgress = description:get("inProgress"):asLocalizedString(getInProgressKey("action", identifier)), 
		}

		if actionModifierTypeComponent:hasKey("props") then
			newActionModifier = actionModifierTypeComponent:getTable("props"):mergeWith(newActionModifier):clear()
		end

		typeMapsModule:insert("actionModifier", actionModule.modifierTypes, newActionModifier)
	end

	function objectManager:generateActionSequence(objDef)
		-- Modules
		local actionModule = moduleManager:get("action")
		local actionSequenceModule = moduleManager:get("actionSequence")
		local typeMapsModule = moduleManager:get("typeMaps")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		local identifier = description:getStringValue("identifier")
		log:schema("ddapi", "  " .. identifier)

		-- Components
		local actionSequenceComponent = components:getTableOrNil("hs_actionSequence")

		if not actionSequenceComponent:getValue() then return end

		local newActionSequence = {
			key = identifier, 
			actions = actionSequenceComponent:getTable("actions"):asTypeIndex(actionModule.types, "Action"),
			assignedTriggerIndex = actionSequenceComponent:getNumberValue("assignedTriggerIndex"), 
			assignModifierTypeIndex = actionSequenceComponent:getStringOrNil("modifier"):asTypeIndex(actionModule.modifierTypes)
		}

		if actionSequenceComponent:hasKey("props") then
			newActionSequence = actionSequenceComponent:getTable("props"):mergeWith(newActionSequence):clear()
		end

		typeMapsModule:insert("actionSequence", actionSequenceModule.types, newActionSequence)
	end

	function objectManager:generateOrder(objDef)
		-- Modules
		local orderModule = moduleManager:get("order")
		local typeMapsModule = moduleManager:get("typeMaps")

		-- Setup
		local description = objDef:getTable("description")
		local components = objDef:getTable("components")

		local identifier = description:getStringValue("identifier")
		log:schema("ddapi", "  " .. identifier)

		-- Components
		local orderComponent = components:getTableOrNil("hs_order")

		if not orderComponent:getValue() then return end

		local newOrder = {
			key = identifier, 
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("order", identifier)), 
			inProgressName = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("order", identifier)),  
			icon = description:getStringValue("icon"), 
		}

		if orderComponent:hasKey("props") then
			newOrder = orderComponent:getTable("props"):mergeWith(newOrder):clear()
		end

		typeMapsModule:insert("order", orderModule.types, newOrder)

		
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
-- @field configType - The configType for which to load configs/objectDefinitions
local objectLoaders = {

	storage = {
		configType = configLoader.configTypes.storage,
		moduleDependencies = {
			"storage",
			"resource", 
			"gameObject"
		},
		loadFunction = objectManager.generateStorageObject
	},

	-- Special one: This handles injecting the resources into storage zones
	storageLinkHandler = {
		configType = configLoader.configTypes.object,
		dependencies = {
			"storage", 
			"resource"
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

	objectSnapping = {
		configType = configLoader.configTypes.object,
		moduleDependencies = {
			"sapienObjectSnapping",
			"gameObject"
		},
		loadFunction = objectManager.generateObjectSnapping
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
			"resource", 
			"gameObject"
		},
		loadFunction = objectManager.generateResource
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
		loadFunction = objectManager.generateBuildable
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
		loadFunction = objectManager.generateCraftable
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
		dependencies = {
			"seats"
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
			-- "plan",
			"gameObject"
		},
		moduleDependencies = {
			"planHelper",
			"plan",
			-- "skill", 
			-- "tool", 
			-- "research"
		},
		loadFunction = objectManager.generatePlanHelperObject
	},

	skill = {
		configType = configLoader.configTypes.skill,
		disabled = true,
		moduleDependencies = {
			"skill"
		},
		loadFunction = objectManager.generateSkill
	},
	
	resourceGroupHandler = {
		configType = configLoader.configTypes.object,
		dependencies = {
			"resourceGroups",
			"resource"
		},
		loadFunction = objectManager.handleResourceGroups
	},

	--[[

	plan = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"plan",
			"typeMaps", 
		}, 
		loadFunction = objectManager.generatePlan
	},

	order = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"order",
			"typeMaps",
		},
		loadFunction = objectManager.generateOrder
	}, 

	activeOrder = {
		configType = configLoader.configTypes.plannableAction,
		moduleDependencies = {
			"action", 
			"tool",
			"skill", 
			"activeOrderAI"
		}, 
		dependencies = {
			"action"
		}, 
		loadFunction = objectManager.generateActiveOrder
	},

	action = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"action",
			"typeMaps",
		}, 
		dependencies = {
			"gameObject"
		},
		loadFunction = objectManager.generateAction
	}, 

	actionSequence = {
		configType = configLoader.configTypes.plannableAction,
		moduleDependencies = {
			"actionSequence", 
			"action",
			"typeMaps"
		},
		dependencies = {
			"action", 
			"actionModifier"
		}, 
		loadFunction = objectManager.generateActionSequence
	},

	actionModifier = {
		configType = configLoader.configTypes.plannableAction, 
		moduleDependencies = {
			"action", 
			"typeMaps"
		}, 
		loadFunction = objectManager.generateActionModifier
	},
]]
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

	animationGroups = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_animation_groups",
		shared_getter = "getAnimationGroups",
		moduleDependencies = {
			"animationGroups"
		},
		loadFunction = objectManager.generateAnimationGroups
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
		loadFunction = objectManager.generateSeat
	},

	material = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_materials",
		shared_getter = "getMaterials",
		moduleDependencies = {
			"material"
		},
		loadFunction = objectManager.generateMaterial
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
		loadFunction = objectManager.generateCustomModel
	}, 
}

local function newModuleAdded(module)
	objectManager:tryLoadObjectDefinitions()
end

moduleManager:bind(newModuleAdded)

-- Initialize the full Data Driven API (DDAPI).
function objectManager:init()
	if utils:runOnceGuard("ddapi") then return end

	log:schema("ddapi", os.date() .. "\n")

	log:schema("ddapi", "Initializing DDAPI...")

	-- Find config files from FS
	configLoader:findConfigFiles()
end


--- Function which tracks whether a particular object type is ready to be loaded. There
--- are numerious reasons why this might not be the case.
local function canLoadObjectType(objectLoader)
	-- Wait for configs to be loaded from the FS
	if configLoader.isInitialized == false then
		return false
	end

	-- Some routes wait for custom start logic. Don't start these until triggered!
	if objectLoader.waitingForStart == true then
		return false
	end
	
	-- Don't enable disabled modules
	if objectLoader.disabled then
		return false
	end

	-- Don't double-load objects
	if objectLoader.loaded == true then
		return false
	end

	-- Don't load until all moduleDependencies are satisfied.
	if objectLoader.moduleDependencies ~= nil then
		for i, moduleDependency in pairs(objectLoader.moduleDependencies) do
			if moduleManager.modules[moduleDependency] == nil then
				return false
			end
		end
	end

	-- Don't load until all dependencies are satisfied (dependent types loaded first!)
	if objectLoader.dependencies ~= nil then
		for i, dependency in pairs(objectLoader.dependencies) do
			if objectLoaders[dependency].loaded ~= true then
				return false
			end
		end
	end

	-- If checks pass, then we can load the object
	objectLoader.loaded = true
	return true
end

--- Marks an object type as ready to load. 
-- @param objectType the name of the config which is being marked as ready to load
function objectManager:markObjectAsReadyToLoad(objectType)
	log:schema("ddapi", "Object has been marked for load: " .. objectType)
	objectLoaders[objectType].waitingForStart = false
	objectManager:tryLoadObjectDefinitions() -- Re-trigger start logic, in case no more modules will be loaded.
end

--- Attempts to load object definitions from the objectLoaders
function objectManager:tryLoadObjectDefinitions()
	for objectType, objectLoader in pairs(objectLoaders) do
		if canLoadObjectType(objectLoader) then
			objectManager:loadObjectDefinition(objectType, objectLoader)
		end
	end
end

-- Error handler for hmTables
local function ddapiErrorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)

	local arg = {...}

	switch(errorCode) : caseof {
		[hmtErrors.ofLengthFailed] = function()
			local requiredLength = arg[1]
			log:schema("ddapi", "    ERROR: Value of key '" .. fieldKey .. "' requires " .. requiredLength .. " elements")
		end,

		[hmtErrors.ofTypeFailed] = function() log:schema("ddapi", "    ERROR: key='" .. fieldKey .. "' should be of type '" .. arg[1] .. "', not '" .. type(fieldKey) .. "'") end,

		[hmtErrors.ofTypeTableFailed] = function() return log:schema("ddapi", "    ERROR: Value type of key '" .. fieldKey .. "' is a table") end,

		[hmtErrors.RequiredFailed] = function()
			log:schema("ddapi", "    ERROR: Missing required field: " .. fieldKey .. " in table: ")
			log:schema("ddapi", parentTable)
			os.exit(1)
		end,

		[hmtErrors.isNotInTypeTableFailed] = function() 
			local displayAlias = arg[2]
			log:schema("ddapi", "    WARNING: " .. displayAlias .. " already exists with key '" .. parentTable[fieldKey] .. "'") 
		end,

		[hmtErrors.isInTypeTableFailed] = function()
			local tbl = arg[1]
			local displayAlias = arg[2]

			utils:logMissing(displayAlias, parentTable[fieldKey], tbl)
		end,

		[hmtErrors.VectorWrongElementsCount] = function() 
			local vecType = arg[1]
			log:schema("ddapi", "    ERROR: Not enough elements in table to make vec"..vecType.." for table with key '"..fieldKey.."'")
			log:schema("ddapi", "Table: ",  parentTable)
		end,

		[hmtErrors.NotVector] = function()
			local vecType = arg[1]
			log:schema("ddapi", "    ERROR: Not able to convert to vec"..vecType.." with infos from table with key '"..fieldKey.."'")
			log:schema("ddapi", "Table: ", parentTable)
		end,

		default = function() log:schema("ddapi", "ERROR: ", msg) end
	}
end

-- Loads all objects for a given objectType
-- @param objectType - The type of object to load
-- @param objectLoader - A table, containing fields from 'objectLoaders'
function objectManager:loadObjectDefinition(objectType, objectLoader)

	if objectLoader.disabled then
		log:schema("ddapi", "WARNING: Object is disabled, skipping: " .. objectType)
		return
	end

	log:schema("ddapi", string.format("\n\nGenerating %s definitions:", objectType))

	local objDefinitions = configLoader:fetchRuntimeCompatibleDefinitions(objectLoader)
	log:schema("ddapi", "Available Definitions: " .. #objDefinitions)

	if objDefinitions == nil or #objDefinitions == 0 then
		log:schema("ddapi", "  (no objects of this type created)")
		return
	end

	local function errorhandler(errorMsg)
		log:schema("ddapi", "WARNING: Object failed to generate, discarding: " .. objectType)
		log:schema("ddapi", errorMsg)
		log:schema("ddapi", "--------")
		log:schema("ddapi", debug.traceback())
		
		if crashes then
			os.exit()
		end
	end

	for i, objDef in ipairs(objDefinitions) do
		objDef = hmt(objDef, ddapiErrorHandler)
		objectLoader:loadFunction(objDef)
		-- xpcall(objectLoader.loadFunction, errorhandler, self, objDef)
		objDef:clear()
	end

	-- Frees up memory now that the configs are cached
	local configTypeDone, allDone = objectManager:isProcessDone(objectLoader.configType)
	if configTypeDone then
		objectLoader.configType.cachedConfigs = nil
	end
	if allDone then
		configLoader.cachedSharedGlobalDefinitions = nil
	end
end

function objectManager:isProcessDone(configType)
	local allLoaded = true 

	for _, objectLoader in pairs(objectLoaders) do 
		if objectLoader.configType == configType and not objectLoader.loaded then
			return false, false
		elseif not objectLoader.loaded then 
			allLoaded = false
		end
	end

	return true, allLoaded
end

return objectManager
