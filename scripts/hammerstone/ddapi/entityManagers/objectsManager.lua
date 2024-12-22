-- Sapiens
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local modules = moduleManager.modules

local objectsManager = {
	settings = {
		unwrap = "hammerstone:object_definition",
		configPath = "/hammerstone/objects",
		luaGetter = "getObjectConfigs",
		configFiles = {},
	}, 
	loaders = {}
}

local ddapiManager = nil

function objectsManager:init(ddapiManager_)
	ddapiManager = ddapiManager_

	objectsManager.loaders.evolvingObject = {
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
		loadFunction = objectsManager.generateEvolvingObject
	}
	
	objectsManager.loaders.objectSnapping = {
		rootComponent = "hs_object",
		moduleDependencies = {
			"sapienObjectSnapping",
			"gameObject"
		},
		loadFunction = objectsManager.generateObjectSnapping
	}

	objectsManager.loaders.resource = {
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
		loadFunction = objectsManager.generateResource
	}
	
	objectsManager.loaders.buildable = {
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
		loadFunction = objectsManager.generateBuildable
	}
	
	objectsManager.loaders.craftable = {
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
			"gameObject",
			"skill", 
			"resource", 
			"action", 
			"actionSequence"
		},
		loadFunction = objectsManager.generateCraftable
	}
	
	objectsManager.loaders.modelPlaceholder = {
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
		loadFunction = objectsManager.generateModelPlaceholder
	}
	
	objectsManager.loaders.gameObject = {
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
			-- "buildable",
			-- "craftable",
			"harvestable"
		},
		loadFunction = objectsManager.generateGameObject
	}
	
	-- Mob Section 

	objectsManager.loaders.mob = {
		rootComponent = "hs_mob",
		moduleDependencies = {
			"mob",
			"gameObject",
			"animationGroups"
		},
		dependencies = {
			"gameObject",
		},
		waitingForStart = true, -- Custom start triggered from animationGroups.lua
		loadFunction = objectsManager.generateMobObject
	}
	objectsManager.loaders.clientMobHandler = {
		rootComponent = "hs_mob",
		moduleDependencies = {
			"clientMob",
			"mob"
		},
		loadFunction = objectsManager.handleClientMob
	}
	objectsManager.loaders.serverMobHandler = {
		rootComponent = "hs_mob",
		waitingForStart = true, -- Custom start triggered from serverMob.lua
		dependencies = {
			"mob"
		},
		moduleDependencies = {
			"serverMob",
			"mob",
			"serverGOM",
			"gameObject"
		},
		loadFunction = objectsManager.handleServerMob
	}
	
	objectsManager.loaders.harvestable = {
		rootComponent = "hs_harvestable",
		waitingForStart = true,
		moduleDependencies = {
			"harvestable",
			"gameObject",
		},
		dependencies = {
			--"gameObject" -> handled by typeIndexMap
		},
		loadFunction = objectsManager.generateHarvestableObject
	}
	
	objectsManager.loaders.planHelper_object = {
		rootComponent = "hs_plans",
		waitingForStart = true, -- Custom start triggered from planHelper.lua
		moduleDependencies = {
			"planHelper",
			"gameObject"
		},
		dependencies = {
			"gameObject"
		},
		loadFunction = objectsManager.generatePlanHelperObject
	}
end

---------------------------------------------------------------------------------
-- Evolving Objects
---------------------------------------------------------------------------------

--- Generates evolving object definitions. For example an orange rotting into a rotten orange.
function objectsManager:generateEvolvingObject(objDef, description, components, identifier, rootComponent)
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

---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

function objectsManager:generateResource(objDef, description, components, identifier, rootComponent)
	-- Setup
	local name = description:getStringOrNil("name"):asLocalizedString(utils:getNameLocKey(identifier))
	local plural = description:getStringOrNil("plural"):asLocalizedString(utils:getNameLocKey(identifier))

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

	ddapiManager:tryAsTypeIndex("storage", "resource", identifier, rootComponent, "storage_identifier", false, modules["storage"].types, "storage", 
		function(storageTypeIndex)
			local storageObject = modules["storage"].types[storageTypeIndex]

			log:schema("ddapi", string.format("  Adding resource '%s' to storage '%s'", identifier, storageObject.key))
			table.insert(storageObject.resources, newResource.index) 
			modules["storage"]:mjInit()
		end
	)

	ddapiManager:tryAsTypeIndex("resourceGroup", "resource", identifier, rootComponent, "resource_groups", true, modules["resource"].groups, "resourceGroup", 
			function(result) 
				for _, resourceGroup in ipairs(result) do 
					modules["resource"]:addResourceToGroup(identifier, resourceGroup)
				end
			end)
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

function objectsManager:generateBuildable(objDef, description, components, identifier, rootComponent)
	-- Optional Components
	local objectComponent = components:getTableOrNil("hs_object"):default({})

	local newBuildable = objectsManager:getCraftableBase(description, rootComponent)

	-- Buildable Specific Stuff
	newBuildable.classification = rootComponent:getStringOrNil("classification"):default("build"):asTypeIndex(modules["constructable"].classifications)
	newBuildable.modelName = getBuildModelName(objectComponent, rootComponent)
	newBuildable.inProgressGameObjectTypeKey = utils:getBuildIdentifier(identifier)
	newBuildable.finalGameObjectTypeKey = identifier
	newBuildable.buildCompletionPlanIndex = rootComponent:getStringOrNil("build_completion_plan"):asTypeIndex(modules["plan"].types)

	ddapiManager:tryAsTypeIndex("research", "buildable", identifier, rootComponent, "research", true, modules["research"].types, "research", 
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
	table.insert(ddapiManager.constructableIndexes, newBuildable.index)
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
function objectsManager:getCraftableBase(description, craftableComponent)
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
		name = description:getStringOrNil("name"):asLocalizedString(utils:getNameLocKey(identifier)),
		plural = description:getStringOrNil("plural"):asLocalizedString(utils:getPluralLocKey(identifier)),
		summary = description:getStringOrNil("summary"):asLocalizedString(utils:getSummaryLocKey(identifier)),

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

function objectsManager:generateCraftable(objDef, description, components, identifier, rootComponent)
	-- TODO
	local outputComponent = rootComponent:getTableOrNil("hs_output")

	local newCraftable = objectsManager:getCraftableBase(description, rootComponent)

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
						return hmt(value):selectPairs(mapIndexes, hmtPairsMode.both)
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
				if ddapiManager.inspectCraftPanelData[key] == nil then
					ddapiManager.inspectCraftPanelData[key] = {}
				end
				table.insert(ddapiManager.inspectCraftPanelData[key], newCraftable.index)
			end
		else
			local key = modules["gameObject"].typeIndexMap.craftArea
			if ddapiManager.inspectCraftPanelData[key] == nil then
				ddapiManager.inspectCraftPanelData[key] = {}
			end
			table.insert(ddapiManager.inspectCraftPanelData[key], newCraftable.index)
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

function objectsManager:generateModelPlaceholder(objDef, description, components, identifier, rootComponent)
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
	,true):clear() -- Calling clear() converts it back to a regular non hmt table

	utils:debug(identifier, objDef, modelPlaceholderData)
	modules["modelPlaceholder"]:addModel(modelName, modelPlaceholderData)

	return modelPlaceholderData
end

---------------------------------------------------------------------------------
-- GameObject
---------------------------------------------------------------------------------
-- TODO: selectionGroupTypeIndexes
function objectsManager:generateGameObject(objDef, description, components, identifier, rootComponent, isBuildVariant)
	local nameKey = identifier
	
	if isBuildVariant then
		identifier = utils:getBuildIdentifier(identifier)
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
			objectsManager:generateGameObject(objDef, description, components, identifier, rootComponent, true)
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
		name = description:getStringOrNil("name"):asLocalizedString(utils:getNameLocKey(nameKey)),
		plural = description:getStringOrNil("plural"):asLocalizedString(utils:getPluralLocKey(nameKey)),
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
		ddapiManager:tryAsTypeIndex("gameObject", "gameObject", identifier, foodComponent, "items_when_eaten", false, modules["gameObject"].types, "gameObject for eatByProducts", 
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
-- Mob Object
---------------------------------------------------------------------------------

function objectsManager:generateMobObject(objDef, description, components, identifier, rootComponent)
	-- Setup
	local name = description:getStringOrNil("name"):asLocalizedString(utils:getNameLocKey(identifier))
	local objectComponent = components:getTableOrNil("hs_object")

	local mobObject = {
		name = name,
		gameObjectTypeIndex = modules["gameObject"].types[identifier].index,
		deadObjectTypeIndex = rootComponent:getString("dead_object"):asTypeIndex(modules["gameObject"].types),
		animationGroupIndex = rootComponent:getString("animation_group"):asTypeIndex(modules["animationGroups"].groups),
	}

	local defaultProps = hmt{
		-- These values are all sensible defaults, more or less averaging mammoth, aplaca, and chicken stats
		initialHealth = 10.0,

		spawnFrequency = 0.5,
		spawnDistance = mj:mToP(400.0),

		reactDistance = mj:mToP(50.0),
		agroDistance = mj:mToP(5.0),
		runDistance = mj:mToP(20.0),

		agroTimerDuration = 3.0,
		aggresionLevel = nil, -- no agro

		pathFindingRayRadius = mj:mToP(0.5),
		pathFindingRayYOffset = mj:mToP(1),
		walkSpeed = mj:mToP(0.8),
		runSpeedMultiplier = 3,
		embedBoxHalfSize = vec3(0.3,0.2,0.5),

		-- Coppied from Alpaca
		maxSoundDistance2 = mj:mToP(200.0) * mj:mToP(200.0),
		soundVolume = 0.2,
		soundRandomBaseName = "alpaca",
		soundRandomBaseCount = 2,
		soundAngryBaseName = "alpacaAngry",
		soundAngryBaseCount = 1,
		deathSound = "alpacaAngry1",

		-- NOT IMPLEMENTED. These are more specific, and should be handled internally.
		-- idleAnimations = {
		--     "stand1",
		--     "stand2",
		--     "stand3",
		--     "stand4",
		--     "sit1",
		--     "sit2",
		-- },

		-- sleepAnimations = {
		--     "sit1",
		--     "sit2",
		-- },

		-- runAnimation = "trot",
		-- deathAnimation = "die",
	}

	mobObject = defaultProps:mergeWith(rootComponent:getTableOrNil("props"):default({})):mergeWith(mobObject):clear()

	-- Insert
	modules["mob"]:addType(identifier, mobObject)

	-- Lastly, inject mob index, if required
	if objectComponent then
		modules["gameObject"].types[identifier].mobTypeIndex = mobObject.index
	end
end

function objectsManager:handleClientMob(def)
	local mobModule = moduleManager:get("mob")
	local clientMobModule = moduleManager:get("clientMob")

	-- Setup
	local identifier = def:getTable("description"):getString("identifier")
	local components = def:getTable("components")
	local mobComponent = components:getTableOrNil("hs_mob")

	-- Early return
	if mobComponent:getValue() == nil then
		return
	end

	local emulateAI = mobComponent:getBooleanOrNil("emulate_client_ai"):default(false):getValue()
	local mobIndex = identifier:asTypeIndex(mobModule.types)

	-- TODO: Clean this up
	local dummyAI = {}
	dummyAI.serverUpdate = function(object, notifications, pos, rotation, scale, incomingServerStateDelta)
	end
	dummyAI.objectWasLoaded = function(object, pos, rotation, scale)
	end
	function dummyAI:update(object, dt, speedMultiplier)
	end
	function dummyAI:init(clientGOM_)
	end


	if emulateAI then
		log:schema("ddapi", string.format("  Mob '%s' is using emulated AI.", identifier:getValue()))
		clientMobModule.mobClassMap[mobIndex] = dummyAI
	else
		log:schema("ddapi", string.format("  WARNING: Mob '%s' is not using emulated AI. You will be responsible for creating an AI yourself in clientMob.lua", identifier:getValue()))
	end
end

function objectsManager:handleServerMob(def)
	local mobModule = moduleManager:get("mob")
	local serverMobModule = moduleManager:get("serverMob")
	local serverGOMModule = moduleManager:get("serverGOM")
	local gameObjectModule = moduleManager:get("gameObject")

	-- Setup
	local identifier = def:getTable("description"):getString("identifier")
	local components = def:getTable("components")
	local mobComponent = components:getTableOrNil("hs_mob")

	-- Early return
	if mobComponent:getValue() == nil then
		return
	end

	local emulateAI = mobComponent:getBooleanOrNil("emulate_server_ai"):default(false):getValue()
	local objectSetString = mobComponent:getStringOrNil("object_set"):default(identifier):getValue()
	local objectSet = serverGOMModule.objectSets[objectSetString] -- TODO add better error handling here
	local mobIndex = identifier:asTypeIndex(mobModule.types)
	local gameObjectIndex = identifier:asTypeIndex(gameObjectModule.types)

	local function infrequentUpdate(objectID, dt, speedMultiplier)
		serverMobModule:infrequentUpdate(objectID, dt, speedMultiplier)
	end


	local function mobSapienProximity(objectID, sapienID, distance2, newIsClose)
		serverMobModule:mobSapienProximity(objectID, sapienID, distance2, newIsClose)
	end

	-- serverGOM.objectSets.moas
	local function initAI() -- No params because these are handled magically via local leaking (yay...)
		serverGOMModule:addObjectLoadedFunctionForTypes({ gameObjectIndex }, function(object)
			serverGOMModule:addObjectToSet(object, serverGOMModule.objectSets.interestingToLookAt)
			serverGOMModule:addObjectToSet(object, objectSet)

			serverMobModule:mobLoaded(object)
		end)

		local reactDistance = mobModule.types[mobIndex].reactDistance -- TODO: Add better handling here

		serverGOMModule:setInfrequentCallbackForGameObjectsInSet(objectSet, "update", 10.0, infrequentUpdate)
		serverGOMModule:addProximityCallbackForGameObjectsInSet(objectSet, serverGOMModule.objectSets.sapiens, reactDistance, mobSapienProximity)
	end

	-- TODO LIAM
	if emulateAI then
		log:schema("ddapi", string.format("  Mob '%s' is using emulated server AI.", identifier:getValue()))
		initAI()
	else
		log:schema("ddapi", string.format("  WARNING: Mob '%s' is not using emulated server AI. You will be responsible for creating an AI yourself in serverMob.lua", identifier:getValue()))
	end
end

---------------------------------------------------------------------------------
-- Object Snapping
---------------------------------------------------------------------------------

function objectsManager:generateObjectSnapping(def)
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
-- Harvestable  Object
---------------------------------------------------------------------------------

function objectsManager:generateHarvestableObject(objDef, description, components, identifier, rootComponent)
	-- Note: We use typeIndexMap here because of the circular dependency.
	-- The vanilla code uses this trick so why can't we?
	local resourcesToHarvest = rootComponent:getTable("resources_to_harvest"):asTypeMapType(modules["gameObject"].typeIndexMap)

	local finishedHarvestIndex = rootComponent:getNumberOrNil("finish_harvest_index"):default(#resourcesToHarvest):getValue()
	modules["harvestable"]:addHarvestableSimple(identifier, resourcesToHarvest, finishedHarvestIndex)
end

---------------------------------------------------------------------------------
-- Plan Helper
---------------------------------------------------------------------------------

function objectsManager:generatePlanHelperObject(objDef, description, components, identifier, rootComponent)
	-- Modules
	local planHelperModule = moduleManager:get("planHelper")

	local objectIndex = description:getString("identifier"):asTypeIndex(modules["gameObject"].types)
	local availablePlansFunction = rootComponent:getStringOrNil("available_plans"):with(
		function (value)
			return planHelperModule[value]
		end
	):getValue()

	-- Shortcut
	if rootComponent == nil then
		return
	end

	-- Handle the normal plan stuff
	if availablePlansFunction ~= nil then
		-- Nil plans would override desired vanilla plans
		planHelperModule:setPlansForObject(objectIndex, availablePlansFunction)
		if availablePlansFunction ~= nil then
			log:schema("ddapi", string.format("  Assigning plan '%s' to object '%s'", availablePlansFunction, identifier))
			planHelperModule:setPlansForObject(objectIndex, availablePlansFunction)
		else
			log:schema("ddapi", string.format("  WARING: Tried to assign plan '%s' to object '%s', but the plan was nil.", availablePlansFunction, identifier))
		end
	end
end


return objectsManager
