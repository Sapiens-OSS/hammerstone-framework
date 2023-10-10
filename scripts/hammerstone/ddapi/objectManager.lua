--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich, earmuffs

local objectManager = {
	inspectCraftPanelData = {},
	constructableIndexes = {},
	addPlansFunctions = {}
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

local modules = moduleManager.modules
hammerAPI:test()

----------------------------
-- Modules
----------------------------

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
	return prefix .. "_" .. identifier .. "_inProgress"
end

local function getDescriptionKey(prefix, identifier)
	return prefix .. "_" ..identifier .. "_description"
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
			local objectKey = modules["typeMaps"]:indexToKey(objectTypeIndex, modules["gameObject"].validTypes)

			local remap = remaps[objectKey]

			-- Return a remap if exists
			if remap ~= nil then
				return modules["model"]:modelIndexForName(remap)
			end

			-- TODO: We should probbaly re-handle this old default type
			-- Else, return the default model associated with this resource
			local defaultModel = modules["gameObject"].types[objectKey].modelName

			return modules["model"]:modelIndexForName(defaultModel)
		end

		return inner
	end

	function objectManager:generateModelPlaceholder(objDef, description, components, identifier, rootComponent)
		-- Components
		local objectComponent = components:getTableOrNil("hs_object")
					
		-- Otherwise, give warning on potential ill configuration
		if rootComponent.model_placeholder == nil then
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
		local modelPlaceholderData = rootComponent:getTable("model_placeholder"):select(
			function(data)

				local isStore = data:getBooleanOrNil("is_store"):default(false):getValue()
				
				if isStore then
					return {
						key = data:getStringValue("key"),
						offsetToStorageBoxWalkableHeight = true
					}
				else
					local default_model = data:getStringValue("default_model")
					local resource_type = data:getString("resource"):asTypeIndex(modules["resource"].types)
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
		modules["modelPlaceholder"]:addModel(modelName, modelPlaceholderData)

		return modelPlaceholderData
	end
end


---------------------------------------------------------------------------------
-- Custom Model
---------------------------------------------------------------------------------

function objectManager:generateCustomModel(modelRemap)
	local model = modelRemap:getStringValue("model")
	local baseModel = modelRemap:getStringValue("base_model")
	log:schema("ddapi", baseModel .. " --> " .. model)

	local materialRemaps = modelRemap:getTableOrNil("material_remaps"):default({}):getValue()
	
	-- Ensure exists
	if modules["model"].remapModels[baseModel] == nil then
		modules["model"].remapModels[baseModel] = {}
	end
	
	-- Inject so it's available
	modules["model"].remapModels[baseModel][model] = materialRemaps

	return materialRemaps
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------
local function getResources(e)
	-- Get the resource (as group, or resource)
	local resourceType = e:getStringOrNil("resource"):asTypeIndex(modules["resource"].types)
	local groupType =  e:getStringOrNil("resource_group"):asTypeIndex(modules["resource"].groups)

	-- Get the count
	local count = e:getOrNil("count"):asNumberOrNil():default(1):getValue()

	if e:hasKey("action") then
		
		local action = e:getTable("action")

		-- Return if action is invalid
		local actionType = action:getStringOrNil("action_type"):default("inspect"):asTypeIndex(modules["action"].types, "Action")
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

--- Returns a lua table, containing the shared keys between craftables and buildables
function objectManager:getCraftableBase(description, craftableComponent)
	-- Setup
	local identifier = description:getStringValue("identifier")

	local tool = craftableComponent:getStringOrNil("tool"):asTypeIndex(modules["tool"].types)
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
		local actionSequence = craftableComponent:getStringOrNil("action_sequence"):asTypeIndex(modules["actionSequence"].types, "Action Sequence")
		if actionSequence then
			buildSequenceData = modules["craftable"]:createStandardBuildSequence(actionSequence, tool)
		else
			buildSequenceData = modules["craftable"][craftableComponent:getStringValue("build_sequence")]
		end
	end

	local craftableBase = {
		name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier)),
		plural = description:getStringOrNil("plural"):asLocalizedString(getPluralLocKey(identifier)),
		summary = description:getStringOrNil("summary"):asLocalizedString(getSummaryLocKey(identifier)),

		buildSequence = buildSequenceData,

		skills = {
			required = craftableComponent:getStringOrNil("skill"):asTypeIndex(modules["skill"].types)
		},

		-- TODO throw a warning here
		iconGameObjectType = craftableComponent:getStringOrNil("display_object"):default(identifier)
			:asTypeIndexMap(modules["gameObject"].typeIndexMap), -- We use typeIndexMap because of circular references. Vanilla code does the same

		requiredTools = requiredTools,

		requiredResources = craftableComponent:getTable("resources"):select(getResources, true):clear()
	}

	return craftableBase
end

---------------------------------------------------------------------------------
-- Buildable
---------------------------------------------------------------------------------

local function getBuildModelName(objectComponent, craftableComponent)
	local modelName = objectComponent:getStringValueOrNil("model")
	if modelName then
		return modelName
	end
	
	-- TODO @Lich can't you just return objectComponent:getStringValue("model") and let it be nil if it is?
	return false
end

function objectManager:generateBuildable(objDef, description, components, identifier, rootComponent)
	-- Optional Components
	local objectComponent = components:getTableOrNil("hs_object"):default({})

	local newBuildable = objectManager:getCraftableBase(description, rootComponent)

	-- Buildable Specific Stuff
	newBuildable.classification = rootComponent:getStringOrNil("classification"):default("build"):asTypeIndex(modules["constructable"].classifications)
	newBuildable.modelName = getBuildModelName(objectComponent, rootComponent)
	newBuildable.inProgressGameObjectTypeKey = getBuildIdentifier(identifier)
	newBuildable.finalGameObjectTypeKey = identifier
	newBuildable.buildCompletionPlanIndex = rootComponent:getStringOrNil("build_completion_plan"):asTypeIndex(modules["plan"].types)

	objectManager:tryAsTypeIndex("research", "buildable", identifier, rootComponent, "research", true, modules["research"].types, "research", 
		function(researchTypeIndex)
			newBuildable.disabledUntilAdditionalResearchDiscovered = researchTypeIndex
		end
	)

	local defaultValues = hmt{
		allowBuildEvenWhenDark = false,
		allowYTranslation = true,
		allowXZRotation = true,
		noBuildUnderWater = true,
		canAttachToAnyObjectWithoutTestingForCollisions = false
	}

	newBuildable = defaultValues:mergeWith(rootComponent:getTableOrNil("props")):default({}):mergeWith(newBuildable):clear()
	
	utils:debug(identifier, objDef, newBuildable)
	modules["buildable"]:addBuildable(identifier, newBuildable)
	
	-- Cached, and handled later in buildUI.lua
	table.insert(objectManager.constructableIndexes, newBuildable.index)
end

function objectManager:generateCraftable(objDef, description, components, identifier, rootComponent)
	-- TODO
	local outputComponent = rootComponent:getTableOrNil("hs_output")

	local newCraftable = objectManager:getCraftableBase(description, rootComponent)

	local outputObjectInfo = nil
	local hasNoOutput = outputComponent:getValue() == nil

	local function mapIndexes(key, value)
		-- Get the input's resource index
		local index = key:asTypeIndexMap(modules["gameObject"].typeIndexMap, "Game Object")

		-- Convert from schema format to vanilla format
		-- If the predicate returns nil for any element, map returns nil
		-- In this case, log an error and return if any output item does not exist in gameObject.types
		local indexTbl = value:asTypeIndexMap(modules["gameObject"].typeIndexMap, "Game Object")

		
		return index, indexTbl
	end

	if outputComponent:getValue() then
		outputObjectInfo = {
			objectTypesArray = outputComponent:getTableOrNil("simple_output"):asTypeIndexMap(modules["gameObject"].typeIndexMap),
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

	local craftArea = rootComponent:getStringOrNil("craft_area"):asTypeIndex(modules["craftAreaGroup"].types)
	local requiredCraftAreaGroups = nil
	if craftArea then
		requiredCraftAreaGroups = {
			craftArea
		}
	end

	-- Craftable Specific Stuff
	newCraftable.classification = rootComponent:getStringOrNil("classification"):default("craft"):asTypeIndex(modules["constructable"].classifications)
	newCraftable.hasNoOutput = hasNoOutput
	newCraftable.outputObjectInfo = outputObjectInfo
	newCraftable.requiredCraftAreaGroups = requiredCraftAreaGroups
	newCraftable.inProgressBuildModel = rootComponent:getStringOrNil("build_model"):default("craftSimple"):getValue()

	if rootComponent:hasKey("props") then
		newCraftable = rootComponent:getTable("props"):mergeWith(newCraftable):clear()
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
		modules["craftable"]:addCraftable(identifier, newCraftable)
		
		-- Add items in crafting panels
		if newCraftable.requiredCraftAreaGroups then
			for _, group in ipairs(newCraftable.requiredCraftAreaGroups) do
				local key = modules["gameObject"].typeIndexMap[modules["craftAreaGroup"].types[group].key]
				if objectManager.inspectCraftPanelData[key] == nil then
					objectManager.inspectCraftPanelData[key] = {}
				end
				table.insert(objectManager.inspectCraftPanelData[key], newCraftable.index)
			end
		else
			local key = modules["gameObject"].typeIndexMap.craftArea
			if objectManager.inspectCraftPanelData[key] == nil then
				objectManager.inspectCraftPanelData[key] = {}
			end
			table.insert(objectManager.inspectCraftPanelData[key], newCraftable.index)
		end
	end
end

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

function objectManager:generateResource(objDef, description, components, identifier, rootComponent)
	-- Setup
	local name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier))
	local plural = description:getStringOrNil("plural"):asLocalizedString(getNameLocKey(identifier))

	-- Components
	local foodComponent = components:getTableOrNil("hs_food")
	
	local displayObject = rootComponent:getStringOrNil("display_object"):default(identifier):getValue()

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = modules["gameObject"].typeIndexMap[displayObject]
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

	if rootComponent:hasKey("props") then
		newResource = rootComponent:getTable("props"):mergeWith(newResource).clear()
	end

	modules["resource"]:addResource(identifier, newResource)

	objectManager:tryAsTypeIndex("storage", "resource", identifier, rootComponent, "storage_identifier", false, modules["storage"].types, "storage", 
		function(storageTypeIndex)
			local storageObject = modules["storage"].types[storageTypeIndex]

			log:schema("ddapi", string.format("  Adding resource '%s' to storage '%s'", identifier, storageObject.key))
			table.insert(storageObject.resources, newResource.index) 
			modules["storage"]:mjInit()
		end
	)

	objectManager:tryAsTypeIndex("resourceGroup", "resource", identifier, rootComponent, "resource_groups", true, modules["resource"].groups, "resourceGroup", 
			function(result) 
				for _, resourceGroup in ipairs(result) do 
					modules["resource"]:addResourceToGroup(identifier, resourceGroup)
				end
			end)
end

---------------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------------

function objectManager:generateStorageObject(objDef, description, components, identifier, rootComponent)
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
		name = description:getStringOrNil("name"):asLocalizedString(getNameKey("storage", identifier)),

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

---------------------------------------------------------------------------------
-- Plan Helper
---------------------------------------------------------------------------------

function objectManager:generatePlanHelperObject(objDef, description, components, identifier, rootComponent)
	local objectIndex = description:getString("identifier"):asTypeIndex(modules["gameObject"].types)
	local availablePlansFunction = rootComponent:getStringOrNil("available_plans"):with(
		function (value)
			return modules["planHelper"][value]
		end
	):getValue()

	-- Nil plans would override desired vanilla plans
	if availablePlansFunction ~= nil then
		modules["planHelper"]:setPlansForObject(objectIndex, availablePlansFunction)
	end
end

---------------------------------------------------------------------------------
-- Mob Object
---------------------------------------------------------------------------------

function objectManager:generateMobObject(objDef, description, components, identifier, rootComponent)
	-- Setup
	local name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(identifier))
	local objectComponent = components:getTableOrNil("hs_object")

	local mobObject = {
		name = name,
		gameObjectTypeIndex = modules["gameObject"].types[identifier].index,
		deadObjectTypeIndex = rootComponent:getString("dead_object"):asTypeIndex(modules["gameObject"].types),
		animationGroupIndex = rootComponent:getString("animation_group"):asTypeIndex(modules["animationGroups"]),
	}

	if rootComponent:hasKey("props") then
		mobObject = rootComponent:getTable("props"):mergeWith(mobObject):clear()
	end

	-- Insert
	modules["mob"]:addType(identifier, mobObject)

	-- Lastly, inject mob index, if required
	if objectComponent then
		modules["gameObject"].types[identifier].mobTypeIndex = mobObject.index
	end
end

---------------------------------------------------------------------------------
-- Harvestable  Object
---------------------------------------------------------------------------------

function objectManager:generateHarvestableObject(objDef, description, components, identifier, rootComponent)
	-- Note: We use typeIndexMap here because of the circular dependency.
	-- The vanilla code uses this trick so why can't we?
	local resourcesToHarvest = rootComponent:getTable("resources_to_harvest"):asTypeIndexMap(modules["gameObject"].typeIndexMap)

	local finishedHarvestIndex = rootComponent:getNumberOrNil("finish_harvest_index"):default(#resourcesToHarvest):getValue()
	modules["harvestable"]:addHarvestableSimple(identifier, resourcesToHarvest, finishedHarvestIndex)
end

---------------------------------------------------------------------------------
-- Object Sets
---------------------------------------------------------------------------------

function objectManager:generateObjectSets(key)
	modules["serverGOM"]:addObjectSet(key:getValue())
end

---------------------------------------------------------------------------------
-- Resource Groups
---------------------------------------------------------------------------------

function objectManager:generateResourceGroup(groupDefinition)	
	local identifier = groupDefinition:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local name = groupDefinition:getStringOrNil("name"):asLocalizedString(getNameKey("group", identifier))
	local plural = groupDefinition:getStringOrNil("plural"):asLocalizedString(getPluralKey("group", identifier))

	local newResourceGroup = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = groupDefinition:getString("display_object"):asTypeIndexMap(modules["gameObject"].typeIndexMap),
		resourceTypes = groupDefinition:getTable("resources"):asTypeIndex(modules["resource"].types, "Resource Types")
	}

	modules["resource"]:addResourceGroup(identifier, newResourceGroup)
end

---------------------------------------------------------------------------------
-- Seat
---------------------------------------------------------------------------------

function objectManager:generateSeat(seatType)
	local identifier = seatType:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local newSeat = {
		key = identifier,
		comfort = seatType:getNumberOrNil("comfort"):default(0.5):getValue(),
		nodes = seatType:getTable("nodes"):select(
			function(node)
				return {
					placeholderKey = node:getStringValue("key"),
					nodeTypeIndex = node:getString("type"):asTypeIndex(modules["seat"].nodeTypes)
				}
			end
		,true):clear()
	}

	modules["typeMaps"]:insert("seat", modules["seat"].types, newSeat)
end


---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

--- Generates evolving object definitions. For example an orange rotting into a rotten orange.
function objectManager:generateEvolvingObject(objDef, description, components, identifier, rootComponent)
	-- Default
	local time = 1 * modules["evolvingObject"].yearLength
	local yearTime = rootComponent:getNumberValueOrNil("time_years")
	if yearTime then
		time = yearTime * modules["evolvingObject"].yearLength
	end

	local dayTime = rootComponent:getNumberValueOrNil("time_days")
	if dayTime then
		time = yearTime * modules["evolvingObject"].dayLength
	end

	if dayTime and yearTime then
		log:schema("ddapi", "   WARNING: Evolving defines both 'time_years' and 'time_days'. You can only define one.")

	end

	local newEvolvingObject = {
		minTime = time,
		categoryIndex = modules["evolvingObject"].categories[rootComponent.category].index,
	}

	if rootComponent:hasKey("transform_to")  then
		newEvolvingObject.toTypes = rootComponent:getTable("transform_to"):asTypeIndex(modules["gameObject"].types)
	end

	modules["evolvingObject"]:addEvolvingObject(identifier, newEvolvingObject)
end

-- TODO: selectionGroupTypeIndexes
function objectManager:generateGameObject(objDef, description, components, identifier, rootComponent)
	return objectManager:generateGameObjectInternal(objDef, description, components, identifier, rootComponent, false)
end

function objectManager:generateGameObjectInternal(objDef, description, components, identifier, rootComponent, isBuildVariant)
	local nameKey = identifier
	if isBuildVariant then
		identifier = getBuildIdentifier(identifier)
	end

	-- Components
	local toolComponent = components:getTableOrNil("hs_tool")
	local harvestableComponent = components:getTableOrNil("hs_harvestable")
	local resourceComponent = components:getTableOrNil("hs_resource")
	local buildableComponent = components:getTableOrNil("hs_buildable")
	local foodComponent = components:getTableOrNil("hs_food")

	if rootComponent:getValue() == nil then
		log:schema("ddapi", "  WARNING:  %s is being created without 'hs_object'. This is only acceptable for resources and so forth.")
		return
	end
	if isBuildVariant then
		log:schema("ddapi", string.format("%s  (build variant)", identifier))
	end
	
	local resourceIdentifier = nil -- If this stays nil, that just means it's a GOM without a resource, such as animal corpse.
	local resourceTypeIndex = nil
	if resourceComponent:getValue() ~= nil then
		-- If creating a resource, link ourselves here
		resourceIdentifier = identifier

		-- Finally, cast to index. This may fail, but that's considered an acceptable error since we can't have both options defined.
	else
		-- Otherwise we can link to the requested resource
		if rootComponent.link_to_resource ~= nil then
			resourceIdentifier = rootComponent.link_to_resource
		end
	end

	if resourceIdentifier then
		resourceTypeIndex = utils:getTypeIndex(modules["resource"].types, resourceIdentifier, "Resource")
		if resourceTypeIndex == nil then
			log:schema("ddapi", "    Note: Object is being created without any associated resource. This is only acceptable for things like corpses etc.")
		end
	end

	-- Handle tools
	local toolUsage = {}
	if toolComponent:getValue() then
		for key, tool in pairs(toolComponent) do
			tool = hmt(tool)
			local toolTypeIndex = utils:getTypeIndex(modules["tool"].types, key, "Tool Type")
			toolUsage[toolTypeIndex] = {
				[modules["tool"].propertyTypes.damage.index] = tool:getOrNil("damage"):getValue(),
				[modules["tool"].propertyTypes.durability.index] = tool:getOrNil("durability"):getValue(),
				[modules["tool"].propertyTypes.speed.index] = tool:getOrNil("speed"):getValue(),
			}
		end
	end

	local modelName = rootComponent:getStringValue("model")
	
	-- Handle Buildable
	local newBuildableKeys = {}
	if buildableComponent:getValue() then
		-- If build variant... recurse!
		if not isBuildVariant then
			objectManager:generateGameObjectInternal(objDef, description, components, identifier, rootComponent, true)
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
			newBuildableKeys.seatTypeIndex = buildableComponent:getStringOrNil("seat_type"):asTypeIndex(modules["seat"].types)
		end
	end

	local newGameObject = {
		name = description:getStringOrNil("name"):asLocalizedString(getNameLocKey(nameKey)),
		plural = description:getStringOrNil("plural"):asLocalizedString(getPluralLocKey(nameKey)),
		modelName = modelName,
		scale = rootComponent:getNumberOrNil("scale"):default(1):getValue(),
		hasPhysics = rootComponent:getBooleanOrNil("physics"):default(true):getValue(),
		resourceTypeIndex = resourceTypeIndex,
		toolUsages = toolUsage,
		craftAreaGroupTypeIndex = buildableComponent:getValue() and buildableComponent:getStringOrNil("craft_area"):asTypeIndex(modules["craftAreaGroup"].types),

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	if not harvestableComponent:isNil() then
		newGameObject.harvestableTypeIndex = description:getString("identifier"):asTypeIndex(modules["harvestable"].types)
	end

	if not foodComponent:isNil() then
		objectManager:tryAsTypeIndex("gameObject", "gameObject", identifier, foodComponent, "items_when_eaten", false, modules["gameObject"].types, "gameObject for eatByProducts", 
			function(result) newGameObject.eatByProducts = result end)
	end

	if rootComponent:hasKey("props") then
		newGameObject = rootComponent:getTable("props"):mergeWith(newGameObject):clear()
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
	modules["gameObject"]:addGameObject(identifier, outObject)
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

function objectManager:generateMaterial(material)
	local function loadMaterialFromTbl(tbl)
		-- Allowed
		if tbl:isNil() then
			return nil
		end

		return {
			color = tbl:getTable("color"):asVec3(),		
			roughness = tbl:getNumberOrNil("roughness"):default(1):getValue(), 
			metal = tbl:getNumberOrNil("metal"):default(0):getValue(),
		}
	end

	local identifier = material:getString("identifier"):isNotInTypeTable(modules["material"].types):getValue()

	log:schema("ddapi", "  " .. identifier)
	
	local materialData = loadMaterialFromTbl(material)
	local materialDataB = loadMaterialFromTbl(material:getTableOrNil("b_material"))
	modules["material"]:addMaterial(identifier, materialData.color, materialData.roughness, materialData.metal, materialDataB)
end

---------------------------------------------------------------------------------
-- Behavior
---------------------------------------------------------------------------------
do
	function objectManager:generatePlan(objDef, description, components, identifier, rootComponent)

		local newPlan = {
			key = identifier,
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("plan", identifier)),
			inProgress = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("plan", identifier)),
			icon = description:getStringValue("icon"),

			checkCanCompleteForRadialUI = rootComponent:getBooleanOrNil("showsOnWheel"):default(true):getValue(), 
			allowsDespiteStatusEffectSleepRequirements = rootComponent:getBooleanValueOrNil("skipSleepRequirement"),  
			shouldRunWherePossible = rootComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "run" end):getValue(), 
			shouldJogWherePossible = rootComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "job" end):getValue(), 
			skipFinalReachableCollisionPathCheck = rootComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skip" end):getValue(), 
			skipFinalReachableCollisionAndVerticalityPathCheck = rootComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skipVertical" end):getValue(),
			allowOtherPlanTypesToBeAssignedSimultaneously = rootComponent:getTableOrNil("simultaneousPlans"):with(
				function(value)
					if value then 
						return hmt(value):selectPairs( 
							function(index, planKey)
								return utils:getTypeIndex(modules["plan"].types, planKey), true
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

		newPlan = defaultValues:mergeWith(rootComponent:getTableOrNil("props"):default({})):mergeWith(newPlan):clear()

		local addPlanFunction = rootComponent:get("addPlanFunction"):ofType("function"):getValue()

		modules["typeMaps"]:insert("plan", modules["plan"].types, newPlan)
		objectManager.addPlansFunctions[newPlan.index] = addPlanFunction
	end

	function objectManager:generatePlanHelperBehavior(objDef, description, components, identifier, rootComponent)

		local targetObjects = rootComponent:getTableOrNil("targets")

		if not targetObjects:isNil() then
			local availablePlansFunction = rootComponent:get("available_plans_function"):getValue()

			if type(availablePlansFunction) == "string" then
				availablePlansFunction = modules["planHelper"][availablePlansFunction]

			elseif type(availablePlansFunction) ~= "function" then
				log:schema("ddapi", "availablePlansFunction must be a string or a function")
				return
			end

			targetObjects:forEach(
				function(targetObject)
					local objectTypeIndex = targetObject:asTypeIndex(modules["gameObject"].types)
					modules["planHelper"]:setPlansForObject(objectTypeIndex, availablePlansFunction)
				end, true)
		else
			-- If it's not a plan for an object, it's for terrain

			-- requiredToolTypeIndex is special. It can be the real index or a function
			local requiredTool = rootComponent:getOrNil("tool")

			local ok, requiredToolTypeIndex = 
				switch(type(requiredTool:getValue())) : caseof {
					["string"] = function() return true, requiredTool:asTypeIndex(modules["tool"].types) end, 
					["function"] = function() return true, requiredTool:getValue() end, 
					["nil"] = function() return true, nil end, 
					default = function() 
						return false, "ERROR: The required tool for planHelper must be a string or a function"
						end
				}
			
			if not ok then 
				log:schema("ddapi", requiredToolTypeIndex)
				return
			end
				
			local terrainPlanSettings = {
				planTypeIndex = description:getString("identifier"):asTypeIndex(modules["plan"].types), 
				requiredToolTypeIndex = requiredToolTypeIndex,
				requiredSkillIndex = rootComponent:getString("skill"):asTypeIndex(modules["skill"].types), 
				checkForDiscovery = rootComponent:getBooleanOrNil("needsDiscovery"):default(true):getValue(), 
				researchTypeIndex = rootComponent:getStringOrNil("research"):asTypeIndex(modules["research"].types),
				addMissingResearchInfo = rootComponent:getBooleanOrNil("addMissingResearchInfo"):default(true):getValue(), 
				canAddResearchPlanFunction = rootComponent:getOrNil("canResearchFunction"):ofTypeOrNil("function"):getValue(), 
				getCountFunction = rootComponent:get("getCountFunction"):ofType("function"):getValue(), 
				initFunction = rootComponent:getOrNil("initFunction"):asTypeOrNil("function"):getValue(), 
				affectedPlanIndexes = rootComponent:getTable("affectedPlans"):asTypeIndex(modules["plan"].types)
			}

			modules["planHelper"]:addTerrainPlan(terrainPlanSettings)
		end
	end

	function objectManager:generateAction(objDef, description, components, identifier, rootComponent)

		local newAction = {
			key = identifier, 
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("action", identifier)), 
			inProgress = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("action", identifier)), 
			restNeedModifier = rootComponent:getNumberValue("restNeedModifier"), 
		}

		if rootComponent:hasKey("props") then
			newAction = rootComponent:getTable("props"):mergeWith(newAction):clear()
		end

		modules["typeMaps"]:insert("action", modules["action"].types, newAction)
	end

	function objectManager:generateActiveOrder(objDef, description, components, identifier, rootComponent)

		local updateInfos = {
			actionTypeIndex = description:getString("identifier"):asTypeIndex(modules["action"].types, "Action"),
			checkFrequency = rootComponent:getNumberValue("checkFrequency"), 
			completeFunction = rootComponent:get("completeFunction"):ofType("function"):value(), 
			defaultSkillIndex = rootComponent:getStringOrNil("defaultSkill"):asTypeIndex(modules["skill"].types, "Skill"),
			toolMultiplierTypeIndex = rootComponent:getStringOrNil("toolMultiplier"):asTypeIndex(modules["tool"].types, "Tool")
		}

		if rootComponent:hasKey("props") then
			updateInfos = rootComponent:getTable("props"):mergeWith(updateInfos):clear()
		end

		modules["activeOrderAI"].updateInfos[updateInfos.actionTypeIndex] = updateInfos
	end

	function objectManager:generateActionModifier(objDef, description, components, identifier, rootComponent)

		local newActionModifier = {
			key = identifier, 
			name = description:get("name"):asLocalizedString(getNameKey("action", identifier)), 
			inProgress = description:get("inProgress"):asLocalizedString(getInProgressKey("action", identifier)), 
		}

		if rootComponent:hasKey("props") then
			newActionModifier = rootComponent:getTable("props"):mergeWith(newActionModifier):clear()
		end

		modules["typeMaps"]:insert("actionModifier", modules["action"].modifierTypes, newActionModifier)
	end

	function objectManager:generateActionSequence(objDef, description, components, identifier, rootComponent)
		local newActionSequence = {
			key = identifier, 
			actions = rootComponent:getTable("actions"):asTypeIndex(modules["action"].types, "Action"),
			assignedTriggerIndex = rootComponent:getNumberValue("assignedTriggerIndex"), 
			assignModifierTypeIndex = rootComponent:getStringOrNil("modifier"):asTypeIndex(modules["action"].modifierTypes)
		}

		if rootComponent:hasKey("props") then
			newActionSequence = rootComponent:getTable("props"):mergeWith(newActionSequence):clear()
		end

		modules["typeMaps"]:insert("actionSequence", modules["actionSequence"].types, newActionSequence)
	end

	function objectManager:generateOrder(objDef, description, components, identifier, rootComponent)
		local newOrder = {
			key = identifier, 
			name = description:getStringOrNil("name"):asLocalizedString(getNameKey("order", identifier)), 
			inProgressName = description:getStringOrNil("inProgress"):asLocalizedString(getInProgressKey("order", identifier)),  
			icon = description:getStringValue("icon"), 
		}

		if rootComponent:hasKey("props") then
			newOrder = rootComponent:getTable("props"):mergeWith(newOrder):clear()
		end

		modules["typeMaps"]:insert("order", modules["order"].types, newOrder)		
	end
end
---------------------------------------------------------------------------------
-- Knowledge
---------------------------------------------------------------------------------
function objectManager:generateSkill(objDef, description, components, identifier, rootComponent)
	local newSkill = {
		name = description:getString("identifier"):asLocalizedString(getNameKey("skill", identifier)), 
		description = description:getStringOrNil("description"):asLocalizedString(getDescriptionKey("skill", identifier)),
		icon = description:getString("icon"), 
		noCapacityWithLimitedGeneralAbility = rootComponent:getBooleanOrNil("limiting"):default(true):getValue(), 
		isDefault = rootComponent:getBooleanOrNil("start_learned"):default(false):getValue(), 
		parentSkills = rootComponent:getTableOrNil("parents"):asTypeIndex(modules["skill"].types), 
		childSkills = rootComponent:getTableOrNil("children"):asTypeIndex(modules["skill"].types)
	}

	if rootComponent:hasKey("props") then
		newSkill = rootComponent:getTable("props"):mergeWith(newSkill):clear()
	end

	modules["skill"]:addSkill(newSkill)
end

function objectManager:generateResearch(objDef, description, components, identifier, rootComponent)
	local newResearch = {
		skillTypeIndex = rootComponent:getStringOrNil("skill"):asTypeIndex(modules["skill"].types), 
		requiredToolTypeIndex = rootComponent:getStringOrNil("tool"):asTypeIndex(modules["tool"].types),
		orderTypeIndex = rootComponent:getStringOrNil("order"):asTypeIndex(modules["order"].types), 
		heldObjectOrderTypeIndex = rootComponent:getStringOrNil("order_object"):asTypeIndex(modules["order"].types),
		constructableTypeIndex = rootComponent:getStringOrNil("constructable"):asTypeIndex(modules["constructable"].types),
		allowResearchEvenWhenDark = rootComponent:getBooleanOrNil("need_light"):default(false):with(function (value) return not value end):getValue(), 
		disallowsLimitedAbilitySapiens = rootComponent:getBooleanOrNil("limited"):default(true):getValue(), 
		initialResearchSpeedLearnMultiplier = rootComponent:getNumberValueOrNil("speed"), 
		researchRequiredForVisibilityDiscoverySkillTypeIndexes = rootComponent:getTableOrNil("needed_skills"):asTypeIndex(modules["skill"].types), 
		shouldRunWherePossibleWhileResearching = rootComponent:getBooleanValueOrNil("should_run"), 
	}

	if rootComponent:hasKey("resources") then
		local addConstructables = rootComponent:getBooleanValueOrNil("add_constructables")
		if addConstructables then
			newResearch.resourceTypeIndexes = rootComponent:getTable("resources"):selectKeys(function(key) return key:asTypeIndex(modules["resource"].types) end, true)
			newResearch.constructableTypeIndexArraysByBaseResourceTypeIndex = rootComponent:selectPairs(
				function(key, value)
					return 	key:asTypeIndex(modules["resource"].types), 
							value:asTypeIndex(modules["constructable"].types)
				end, hmtPairsMode.KeysAndValues)
		else
			newResearch.resourceTypeIndexes = rootComponent:getTable("resources"):asTypeIndex(modules["resource"].types)
		end
	end

	if rootComponent:hasKey("props") then
		newResearch = rootComponent:getTable("props"):mergeWith(newResearch):clear()
	end

	modules["research"]:addResearch(identifier, newResearch)
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
local sortedObjectLoaders = {}
local objectLoaders = {

	storage = {
		configType = configLoader.configTypes.storage,
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
		loadFunction = objectManager.generateStorageObject
	},

	evolvingObject = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_evolving_object",
		waitingForStart = true,
		moduleDependencies = {
			"evolvingObject",
			"typeMaps",
			"gameObject"
		},
		dependencies = {
			"gameObject"
		},
		loadFunction = objectManager.generateEvolvingObject
	},

	resource = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_resource",
		moduleDependencies = {
			"resource", 
			"typeMaps",
			"storage", 
			"gameObject" -- Lich mjrequires it from a config
		},
		dependencies = {
			--"storage", handled by callback
			--"resourceGroup", handled by callback
		},
		loadFunction = objectManager.generateResource
	},

	buildable = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_buildable",
		moduleDependencies = {
			"buildable",
			"typeMaps",
			"constructable",
			"plan",
			"research", 
			"skill",
			"tool",
			"actionSequence",
			"gameObject",
			"resource",
			"action",
			"craftable",
		},
		dependencies = {
			"plan", 
			"skill",
			"resource",
			"craftable",
			--"gameObject", -> handled through typeIndexMap
			--"research" -> handled through callback
		},
		loadFunction = objectManager.generateBuildable
	},

	craftable = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_craftable",
		waitingForStart = true,
		minimalModuleDependencies = {
			"craftable",
			"typeMaps",
		},
		moduleDependencies = {
			"craftable",
			"typeMaps",
			"gameObject",
			"constructable",
			"craftAreaGroup",
			"skill",
			"tool",
			"actionSequence",
			"resource",
			"action"
		},
		dependencies = {
			--"gameObject", -> handled through typeIndexMap
			"skill", 
			"resource", 
			"action", 
			"actionSequence"
		},
		loadFunction = objectManager.generateCraftable
	},

	modelPlaceholder = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_buildable",
		moduleDependencies = {
			"modelPlaceholder",
			"typeMaps",
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
		rootComponent = "hs_object",
		waitingForStart = true,
		moduleDependencies = {
			"gameObject",
			"resource",			
			"tool",
			"harvestable",
			"seat",
			"craftAreaGroup"
		},
		dependencies = {
			"seats", 
			"buildable",
			"craftable",
			"harvestable"
		},
		loadFunction = objectManager.generateGameObject
	},

	mob = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_mob",
		moduleDependencies = {
			"mob",
			"gameObject",
			"animationGroups"
		},
		dependencies = {
			"gameObject",
		},
		loadFunction = objectManager.generateMobObject
	},

	harvestable = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_harvestable",
		waitingForStart = true,
		moduleDependencies = {
			"harvestable",
			"gameObject",
		},
		dependencies = {
			--"gameObject" -> handled by typeIndexMap
		},
		loadFunction = objectManager.generateHarvestableObject
	},

	planHelper_object = {
		configType = configLoader.configTypes.object,
		rootComponent = "hs_plans",
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		moduleDependencies = {
			"planHelper", 
			"gameObject"
		},
		dependencies = {
			"gameObject"
		},
		loadFunction = objectManager.generatePlanHelperObject
	},
	
	---------------------------------------------------------------------------------
	-- Behavior
	---------------------------------------------------------------------------------
	plan = {
		configType = configLoader.configTypes.behavior, 
		rootComponent = "hs_plan",
		moduleDependencies = {
			"plan"
		}, 
		loadFunction = objectManager.generatePlan
	},

	planHelper_behavior = {
		configType = configLoader.configTypes.behavior, 
		rootComponent = "hs_plan_availability",
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		moduleDependencies = {
			"planHelper", 
			"plan", 
			"tool", 
			"skill", 
			"research", 
			"gameObject"
		}, 
		dependencies = {
			"plan", 
			"skill", 
			"research", 
			"gameObject"
		}, 
		loadFunction = objectManager.generatePlanHelperBehavior
	},

	order = {
		configType = configLoader.configTypes.behavior, 
		rootComponent = "hs_order",
		moduleDependencies = {
			"order",
		},
		loadFunction = objectManager.generateOrder
	}, 

	activeOrder = {
		configType = configLoader.configTypes.behavior,
		rootComponent = "hs_activeOrder",
		moduleDependencies = {
			"action", 
			"tool",
			"skill", 
			"activeOrderAI"
		}, 
		dependencies = {
			"action", 
			"skill"
		}, 
		loadFunction = objectManager.generateActiveOrder
	},

	action = {
		configType = configLoader.configTypes.behavior, 
		rootComponent = "hs_action",
		moduleDependencies = {
			"action"		
		}, 
		loadFunction = objectManager.generateAction
	}, 

	actionSequence = {
		configType = configLoader.configTypes.behavior,
		rootComponent = "hs_actionSequence",
		moduleDependencies = {
			"actionSequence", 
			"action"
		},
		dependencies = {
			"action", 
			"actionModifier"
		}, 
		loadFunction = objectManager.generateActionSequence
	},

	actionModifier = {
		configType = configLoader.configTypes.behavior, 
		rootComponent = "hs_actionModifierType",
		moduleDependencies = {
			"action", 
		}, 
		loadFunction = objectManager.generateActionModifier
	},

	---------------------------------------------------------------------------------
	-- Knowledge
	---------------------------------------------------------------------------------
	skill = {
		configType = configLoader.configTypes.knowledge,
		rootComponent = "hs_skill",
		moduleDependencies = {
			"skill", 
			"typeMaps"
		},
		loadFunction = objectManager.generateSkill
	},
	research = {
		configType = configLoader.configTypes.knowledge, 
		rootComponent = "hs_research",
		moduleDependencies = {
			"research", 
			"typeMaps",
			"skill", 
			"resource", 
			"order", 
			"constructable", 
			"tool"
		}, 
		dependencies = {
			"skill", 
			"resource", 
			"order", 
			"buildable"
		}, 
		loadFunction = objectManager.generateResearch
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
			"gameObject"
		},
		dependencies = {
			"resource",
			--"gameObject" -> Handled through typeIndexMap
		},
		loadFunction = objectManager.generateResourceGroup
	},


	seats = {
		configType = configLoader.configTypes.shared,
		shared_unwrap = "hs_seat_types",
		shared_getter = "getSeatTypes",
		moduleDependencies = {
			"seat"
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

	-- checks if we have circular dependencies and sorts the loaders
	objectManager:checkAndSortLoaders()

	-- Find config files from FS
	configLoader:findConfigFiles()
end


--- Function which tracks whether a particular object type is ready to be loaded. There
--- are numerious reasons why this might not be the case.
local function canLoadObjectType(objectLoader)
	-- Wait for configs to be loaded from the FS
	if configLoader.isInitialized == false then
		return false, "Not initialized"
	end

	-- Some routes wait for custom start logic. Don't start these until triggered!
	if objectLoader.waitingForStart == true then
		return false, "Waiting for start"
	end
	
	-- Don't enable disabled modules
	if objectLoader.disabled then
		return false, "Disabled"
	end

	-- Don't double-load objects
	if objectLoader.loaded == true then
		return false, "Already loaded"
	end

	-- Don't load until all moduleDependencies are satisfied.
	if objectLoader.moduleDependencies ~= nil then
		for i, moduleDependency in pairs(objectLoader.moduleDependencies) do
			if moduleManager.modules[moduleDependency] == nil then
				return false, "Waiting on module dependency " .. moduleDependency
			end
		end
	end

	-- Don't load until all dependencies are satisfied (dependent types loaded first!)
	if objectLoader.dependencies ~= nil then
		for i, dependency in pairs(objectLoader.dependencies) do
			if not objectLoaders[dependency] then
				mj:error("Dependency ", dependency, " does not exist")
			else
				if objectLoaders[dependency].loaded ~= true then
					local canDependencyLoad, dependencyReason = canLoadObjectType(objectLoaders[dependency])
					if canDependencyLoad then
						return false, "Waiting on dependency "..dependency.. " This dependency can load. Please revise load orders"
					else
						return false, "Waiting on dependency "..dependency.. "\r\n\t\t\tThis dependency cannot load because: " .. dependencyReason
					end
				end
			end
		end
	end

	-- If checks pass, then we can load the object
	return true
end

--- Marks an object type as ready to load. 
-- @param objectType the name of the config which is being marked as ready to load
function objectManager:markObjectAsReadyToLoad(objectType, callbackFunction)
	log:schema("ddapi", "Object has been marked for load: " .. objectType)
	objectLoaders[objectType].waitingForStart = false

	local canLoad, reason = canLoadObjectType(objectLoaders[objectType])
	if not canLoad then
		log:schema("ddapi", "  ERROR: ", objectType, " has been marked for ready to load but cannot load yet. Reason: ", reason)
	end

	objectManager:tryLoadObjectDefinitions() -- Re-trigger start logic, in case no more modules will be loaded.
end

--- Attempts to load object definitions from the objectLoaders
function objectManager:tryLoadObjectDefinitions()
	for _, objectType in ipairs(sortedObjectLoaders) do
		local objectLoader = objectLoaders[objectType]
		if  canLoadObjectType(objectLoader) then
			objectManager:loadObjectDefinitions(objectType, objectLoader)
		end
	end
end

--- In cases where we might have a circular reference, we can try to get indexes later
--- Attempts to retrieve the index. If it fails, creates a callback 
--- @param objectType: 			The objectType which will create the missing type if retrieval fails
--- @param sourceObjectType:	The objectType which requested the index (for logging purposes)
--- @param identifier:			The identifier of the definition which requested the index (for logging purposes)
--- @param hmTable:				The hmt which contains the typeTableKey or table of typeTableKeys to map to an index
--- @param key:					The key of the field to retrive from the hmt
--- @param optional:			Wether or not the value of the field is allowed to be nil
--- @param typeTable:			The typeTable from which to retrieve the index or indexes
--- @param typeTableName		Name of the typeTable (for logging purposes)
--- @param onSuccess			The function which to execute once the index or indexes have all been found
function objectManager:tryAsTypeIndex(objectType, sourceObjectType, identifier, hmTable, key, optional, typeTable, typeTableName, onSuccess)

	local value = (optional and hmTable:getOrNil(key) or hmTable:get(key)):getValue()

	if not value then return end 

	local function addCallback(typeMapKey, setIndexFunction)
		objectManager:registerCallback(objectType, typeMapKey, typeTable, setIndexFunction, 
				typeTableName .. " with key " .. typeMapKey .. " was never created for " .. sourceObjectType .. " with identifier ".. identifier)
	end

	if type(value) == "table" then
		local resultTable = {}

		-- Note: This might create bugs if the order in the table is important
		local function onSuccessForTable(typeMapIndex)
			table.insert(resultTable, typeMapIndex)
			
			if #resultTable == #value then
				onSuccess(resultTable)
			end
		end

		for _, typeMapKey in ipairs(value) do 
			if typeTable[typeMapKey] then
				onSuccessForTable(typeTable[typeMapKey].index)
			else
				addCallback(typeMapKey, onSuccessForTable)
			end
		end
	elseif type(value) == "string" then
		local typeMapKey = value

		if typeTable[typeMapKey] then
			onSuccess(typeTable[typeMapKey].index)
		else
			addCallback(typeMapKey, onSuccess)
		end
	else
		hmTable:getString(key) -- This is a bit of a hack to let the ddapi error handler log the "wrong type" error
	end	
end

function objectManager:registerCallback(objectType, typeMapKey, typeTable, setIndexFunction, errorMessage)
	local loader = objectLoaders[objectType]

	if not loader.callbacks then
		loader.callbacks = {}
	end

	if not loader.callbacks[typeMapKey] then
		loader.callbacks[typeMapKey] = {}
	end

	table.insert(loader.callbacks[typeMapKey], {setIndexFunction = setIndexFunction, typeTable = typeTable, errorMessage = errorMessage})
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

		[hmtErrors.NotInTypeTable] = function()
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

	log:schema("ddapi", debug.traceback())
	os.exit(1)
end

-- Loads all objects for a given objectType
-- @param objectType - The type of object to load
-- @param objectLoader - A table, containing fields from 'objectLoaders'
function objectManager:loadObjectDefinitions(objectType, objectLoader)
	objectLoader.loaded = true

	if objectLoader.disabled then
		log:schema("ddapi", "WARNING: Object is disabled, skipping: " .. objectType)
		return
	end

	log:schema("ddapi", string.format("\r\n\r\nGenerating %s definitions:", objectType))

	local objDefinitions = configLoader:fetchRuntimeCompatibleDefinitions(objectLoader)

	if objDefinitions == nil or #objDefinitions == 0 then
		log:schema("ddapi", "  (no objects of this type created)")
		return
	end

	log:schema("ddapi", "Available Possible Definitions: " .. #objDefinitions)

	for i, objDef in ipairs(objDefinitions) do
		objectManager:loadObjectDefinition(objDef, objectLoader, objectType)
	end

	-- Check for callbacks
	if objectLoader.callbacks and next(objectLoader.callbacks) then
		for missingKey, callbackInfos in pairs(objectLoader.callbacks) do 
			for _, callbackInfo in ipairs(callbackInfos) do 
				-- Retry in case some other process added the type
				-- Note: This is the case for eatByProducts. gameObject has a self reference
				local index = callbackInfo.typeTable[missingKey]

				if index then
					callbackInfo.setIndexFunction(index)
				else
					log:schema("ddapi", "  ERROR: " .. callbackInfo.errorMessage)
					log:schema("ddapi", "Available types: ", callbackInfo.typeTable)
					os.exit(1)
				end
			end
		end
	end

	-- Frees up memory now that the configs are cached
	local configTypeDone, allDone = objectManager:isProcessDone(objectLoader.configType)
	if configTypeDone then
		objectLoader.configType.cachedConfigs = nil
	end
	if allDone then
		configLoader.cachedSharedGlobalDefinitions = nil
	end

	log:schema("ddapi", "\r\n")
end

function objectManager:loadObjectDefinition(objDef, objectLoader, objectType)
	objDef = hmt(objDef, ddapiErrorHandler)

	if objectLoader.shared_unwrap then
		objectLoader.loadFunction(self, objDef)
	else
		local components = objDef:getTable("components")

		if objectLoader.rootComponent and not components:hasKey(objectLoader.rootComponent) then 
			return
		end

		local description = objDef:getTable("description")
		local identifier = description:getStringValue("identifier")
		local rootComponent = components:getTable(objectLoader.rootComponent)

		log:schema("ddapi", "  " .. identifier)

		objectLoader.loadFunction(self, objDef, description, components, identifier, rootComponent)

		if objectLoader.callbacks and objectLoader.callbacks[identifier] then
			local moduleName = objectLoader.moduleName or objectType
			local typeTable = objectLoader.typeTable or "types"

			local typeTableType = moduleManager:get(moduleName)[typeTable][identifier]

			if not typeTableType then
				log:schema("ddapi", "  ERROR: Object was created but could not find identifier '", identifier, "' in '", moduleName, ".", typeTable, "'")
				os.exit(1)
			else
				for _ , callbackInfos in ipairs(objectLoader.callbacks[identifier]) do 
					callbackInfos.setIndexFunction(typeTableType.index)
				end

				objectLoader.callbacks[identifier] = nil
			end
		end
	end

	objDef:clear()
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


function objectManager:checkAndSortLoaders()
	local dependencies = {}

	for objectType, loader in pairs(objectLoaders) do 
		dependencies[objectType] = {}

		if loader.dependencies then
			for _, dep in ipairs(loader.dependencies) do 
				if not objectLoaders[dep] then
					log:schema("ddapi", "ERROR. ObjectType ", dep, " does not exist")
					os.exit(1)
				end

				table.insert(dependencies[objectType], dep)
			end
		end
	end

	while next(dependencies) do
		local found = false 

		for objectType, deps in pairs(dependencies) do 
			for i = #deps, 1, -1 do 
				if not dependencies[deps[i]] then
					found = true
					table.remove(deps, i)
				end
			end

			if #deps == 0 then
				table.insert(sortedObjectLoaders, objectType)
				dependencies[objectType] = nil
			end
		end

		if next(dependencies) and not found then
			mj:error("ERROR IN DDAPI. Circular dependencies found. These dependencies could not be resolved: ", dependencies)
			os.exit(1)
		end
	end

	log:schema("ddapi", "No circular dependencies found. Here are the sorted loaders: ", sortedObjectLoaders)
end

return objectManager
