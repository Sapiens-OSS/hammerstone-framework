--- Hammerstone: objectManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich

local objectManager = {
	gameObject = nil,
	inspectCraftPanelData = {},
}

-- Local database of config information
local objectDB = {
	-- Unstructured game object definitions, read from FS
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
}

-- TODO: Consider using metaTables to add default values to the objectDB
-- local mt = {
-- 	__index = function ()
-- 		return "10"
-- 	end
-- }
-- setmetatable(objectDB.objectConfigs, mt)

-- sapiens
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
function objectManager:init(gameObject)
	-- Initialization guard to prevent infinite looping
	if initialized then
		mj:warn("Attempting to re-initialize objectManager DDAPI! Skipping.")
		return
	else
		log:log("Initializing DDAPI...")
		initialized = true
	end

	-- Expose
	objectManager.gameObject = gameObject

	-- Load configs from FS
	objectManager:loadConfigs()

	-- Register items, in the order the game expects!
	objectManager:generateResourceDefinitions()
	objectManager:generateStorageObjects()
	objectManager:generateGameObjects(gameObject)
	-- generateEvolvingObjects is called internally, from `evolvingObjects.lua`.
	-- generateRecipeDefinitions is called internally, from `craftable.lua`.
end

-- Loops over known config locations and attempts to load them
-- TODO: Call this method from the correct location
function objectManager:loadConfigs()
	log:log("Loading Configuration files:")
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0;

	log:schema("resource", "test")
	log:schema("resource", "test2")
	log:schema("resource", "test3")

	-- Objects
	for i, mod in ipairs(mods) do
		local objectConfigDir = mod.path .. "/hammerstone/objects/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectDB.objectConfigs)
		end
	end

	-- Storage
	for i, mod in ipairs(mods) do
		local objectConfigDir = mod.path .. "/hammerstone/storage/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectDB.storageConfigs)
		end
	end

	-- Craftable
	for i, mod in ipairs(mods) do
		local objectConfigDir = mod.path .. "/hammerstone/recipes/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectDB.recipeConfigs)
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

		log:log(displayAlias .. " '" .. key .. "' does not exist. Try one of these instead:")

		for k, _ in pairs(tbl) do
			if type(k) == "string" then
				log:log(" " .. k)
			end
		end
	end
end

function logWrongType(key, typeName)
	log:log(key .. " should be of type " .. typeName .. ", not " .. type(key))
end

function logNotImplemented(featureName)
	log:log("Unfortunately, " .. featureName .. " is yet to be implemented")
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
	if typeName == "boolean" then
		return value == "true"
	end
	return false
end

function getField(tbl, key, options)
	local value = tbl[key]
	local name = key

	if value == nil then
		return
	end

	if options ~= nil then

		-- Make sure this field has the proper type
		if options.type ~= nil then
			if not isType(value, options.type) then
				return logWrongType(key, options.type)
			end
		end

		-- Make sure this field value has a valid type
		if options.typeTable ~= nil then
			if type(options.typeTable) == "table" then
				if not hasKey(options.typeTable, value) then
					return logMissing(name, value, tbl)
				end
			else
				log:log("Value of typeTable is not table")
			end
		end
	end

	return value
end

function getTable(tbl, key, options)
	local value = tbl[key]
	local name = key

	if value == nil then
		return
	end

	if type(value) ~= "table" then
		return log:log("Value type of key '" .. key .. "' is not table")
	end

	if options ~= nil then

		if options.displayName ~= nil then
			name = options.displayName
		end

		for k, v in pairs(options) do
			if k == "map" then
				if type(options.map) == "function" then
					value = map(value, options.map)
				else
					log:log("Value of map option is not function")
				end
			end
		end
	end

	return value
end


---------------------------------------------------------------------------------
-- Resource
---------------------------------------------------------------------------------

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions()
	log:log("Generating resource definitions:")
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

	-- Resource links would prevent a *new* resource from being generated.
	local resourceLinkComponent = components["hammerstone:resource_link"]
	if resourceLinkComponent ~= nil then
		log:log("GameObject " .. identifier .. " linked to resource " .. resourceLinkComponent.identifier .. " no unique resource created.")
		return
	end

	log:log("Generating Resource with identifier: " .. identifier)

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
	log:log("Generating Storage Objects:")
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

	log:log("Generating Storage Object with ID: " .. identifier)

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

	mj:log(newStorage)
	local storageModule = mjrequire "common/storage"
	storageModule:addStorage(identifier, newStorage)
end

---------------------------------------------------------------------------------
-- Game Object
---------------------------------------------------------------------------------

function objectManager:generateEvolvingObjects(evolvingObject)
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

	local object_definition = config["hammerstone:object_definition"]
	local evolvingObjectComponent = object_definition.components["hammerstone:evolving_object"]

	local identifier = object_definition.description.identifier
	
	if evolvingObjectComponent == nil then
		return -- This is allowed	
	else
		log:log("Creating EvolvingObject definition for " .. identifier)
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
				table.insert(newResource, objectManager.gameObject.types[identifier].index)
			end
		
			return newResource
		end

		newEvolvingObject.toTypes = generateTransformToTable(evolvingObjectComponent.transform_to)
	end
	

	evolvingObject:addEvolvingObject(identifier, newEvolvingObject)
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

function objectManager:generateGameObjects(gameObject)
	log:log("Generating GameObjects:")

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
	log:log("Registering GameObject with ID " .. identifier)

	local name = description["name"]
	local plural = description["plural"]
	local scale = objectComponent["scale"]
	local model = objectComponent["model"]
	local physics = objectComponent["physics"]
	local marker_positions = objectComponent["marker_positions"]

	-- Shoot me
	local resource = mjrequire "common/resource"

	
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
		resourceTypeIndex = resource.types[resourceIdentifier].index,

		-- TODO: Implement marker positions
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Actually register the game object
	gameObject:addGameObject(identifier, newObject)
end

---------------------------------------------------------------------------------
-- Craftable
---------------------------------------------------------------------------------

--- Generates recipe definitions based on the loaded config, and registers them.
function objectManager:generateRecipeDefinitions(gameObject)
	log:log("Generating recipe definitions:")
	for i, config in ipairs(objectDB.recipeConfigs) do
		objectManager:generateRecipeDefinition(gameObject, config)
	end
end

function objectManager:generateRecipeDefinition(gameObject, config)

	if config == nil then
		log:warn("Warning! Attempting to generate a recipe definition that is nil.")
		return
	end

	local craftable = mjrequire "common/craftable"
	local constructable = mjrequire "common/constructable"
	local resource = mjrequire "common/resource"
	local action = mjrequire "common/action"
	local actionSequence = mjrequire "common/actionSequence"
	local craftAreaGroup = mjrequire "common/craftAreaGroup"
	local tool = mjrequire "common/tool"
	local skill = mjrequire "common/skill"
	
	local objectDefinition = config["hammerstone:recipe_definition"]
	local description = objectDefinition["description"]
	local identifier = description["identifier"]
	local components = objectDefinition["components"]
	log:log(identifier)

	local recipe = components["hammerstone:recipe"]
	local requirements = components["hammerstone:requirements"]
	local output = components["hammerstone:output"]
	local build_sequence = components["hammerstone:build_sequence"]

	local data = {
		name = description.name,
		plural = description.plural,
		summary = description.summary,
		outputObjectInfo = {},
		requiredResources = {},
	}

	-- The following code is for sanitizing inputs and logging errors accordingly

	-- Preview Object
	if gameObject.types[recipe.preview_object] ~= nil then
		data.iconGameObjectType = recipe.preview_object
	else
		return logMissing("Preview Object", recipe.preview_object, gameObject.types)
	end

	-- Classification
	if constructable.classifications[recipe.classification] ~= nil then
		data.classification = constructable.classifications[recipe.classification].index
	else
		return logMissing("Classification", recipe.classification, constructable.classifications)
	end

	-- Is Food Preparation
	if description["isFoodPreparation"] ~= nil and description["isFoodPreparation"] then
		data.isFoodPreparation = true
	end

	-- Required Craft Area Groups
	local requiredCraftAreaGroups = map(requirements.craft_area_groups, function(element)
		return getTypeIndex(craftAreaGroup.types, element, "Craft Area Group")
	end)
	if requiredCraftAreaGroups ~= nil then
		data.requiredCraftAreaGroups = requiredCraftAreaGroups
	end

	-- Required Tools
	local requiredTools = map(requirements.tools, function(element)
		return getTypeIndex(tool.types, element, "Tool")
	end)
	if not isEmpty(requiredTools) then
		data.requiredTools = requiredTools
	end

	-- Required Skills
	if #requirements.skills > 0 then
		if skill.types[requirements.skills[1]] ~= nil then
			data.skills = {
				required = skill.types[requirements.skills[1]].index
			}
		else
			return logMissing("Skill", requirements.skills[1], skill.types)
		end
	end
	if #requirements.skills > 1 then
		if skill.types[requirements.skills[2]] ~= nil then
			data.disabledUntilAdditionalSkillTypeDiscovered = skill.types[requirements.skills[2]].index
		else
			return logMissing("Skill", requirements.skills[2], skill.types)
		end
	end

	-- Outputs
	if output.output_by_object ~= nil then
		local outputArraysByResourceObjectType = map(output.output_by_object, function(element)
			if gameObject.types[element.input] ~= nil then
				return map(element.output, function(e)
					if gameObject.types[e] ~= nil then
						return gameObject.types[e]
					end
					return logMissing("Game Object", e, gameObject.types)
				end)
			end
			return logMissing("Game Object", element.input, gameObject.types)
		end)
		if outputArraysByResourceObjectType ~= nil then
			data.outputObjectInfo.outputArraysByResourceObjectType = outputArraysByResourceObjectType
		end
	end
	
	local buildSequenceModel = build_sequence["build_sequence_model"]
	local buildSequence = build_sequence["build_sequence"]
	local objectProp = build_sequence["object_prop"]
	local resourceProp = build_sequence["resource_prop"]
	local resourceSequence = build_sequence["resource_sequence"]

	-- Build Sequence Model
	if buildSequenceModel ~= nil then
		data.inProgressBuildModel = buildSequenceModel
	else
		return log:log("[Hammerstone] Missing build sequence model")
	end
	
	-- Build Sequence
	if buildSequence ~= nil then
		local steps = buildSequence["steps"]
		if steps ~= nil then
			-- Custom build sequence
			-- TODO
			logNotImplemented("Custom Build Sequences")
		else
			-- Standard build sequence
			local action = buildSequence["action"]
			local tool = buildSequence["tool"]
			if action ~= nil then
				if actionSequence.types[action] ~= nil then
					action = actionSequence.types[action].index
					if tool ~= nil then
						if tool.types[tool] ~= nil then
							tool = tool.types[tool].index
						else
							return logMissing("Tool", tool, tool.types)
						end
					end
					data.buildSequence = craftable:createStandardBuildSequence(action, tool)
				else
					return logMissing("Action Sequence", action, actionSequence.types)
				end
			else
				log:log("Missing action sequence")
			end
		end
	else
		log:log("Missing build sequence")
	end

	-- Object Prop
	-- TODO
	if objectProp ~= nil then
		logNotImplemented("object props")
	end

	-- Resource Prop
	-- TODO
	if resourceProp ~= nil then
		logNotImplemented("resource props")
	end

	-- Resource Sequence
	if resourceSequence ~= nil then
		for _, item in ipairs(resourceSequence) do
			local resourceName = item["resource"]
			local count = item["count"] or 1
			if resource.types[resourceName] ~= nil then
				local resourceData = {
					type = resource.types[resourceName].index,
					count = count
				}
				if action ~= nil then
					if item["action"]["action_type"] ~= nil then
						if action.types[item["action"]["action_type"]] ~= nil then
							if item["action"]["duration"] ~= nil then
								resourceData.afterAction = {}
								resourceData.afterAction.actionTypeIndex = action.types[item["action"]["action_type"]].index
								resourceData.afterAction.duration = item["action"]["duration"]
								if item["action"]["duration_without_skill"] ~= nil then
									resourceData.afterAction.durationWithoutSkill = item["action"]["duration_without_skill"]
								else
									resourceData.afterAction.durationWithoutSkill = item["action"]["duration"]
								end
							else
								mj:log("[Hammerstone] Duration for action '" .. item["action"]["action_type"] .. "' cannot be nil")
							end
						else
							return logMissing("Action", item["action"]["action_type"], action.types)
						end
					end
				end
				table.insert(data.requiredResources, resourceData)
			else
				return logMissing("Resource", resourceName, actionSequence.types)
			end
		end
	else
		log:log("Missing resource sequence")
	end



	function compile(req, data)
		return data
	end


	local required = {
		requiredTools = false,
		inProgressBuildModel = true
	}

	local testdata = compile(required, {

		preview_object = getField(recipe, "preview_object", {
			typeTable = gameObject.types
		}),

		isFoodPreparation = getField(recipe, "preview_object", {
			type = "boolean"
		}),

		inProgressBuildModel = getField(build_sequence, "build_sequence_model", {
			typeTable = gameObject.types
		}),

		requiredTools = getTable(requirements.tools, "build_sequence", {
			-- Return a table of tool indexes
			map = function(e)
				return getTypeIndex(tool.types, e, "Tool")
			end
		}),
		
		requiredResources = getTable(build_sequence, "resource_sequence", {
			-- Return a table of resource sequences
			map = function(e)

				-- Cancel if resource doesn't exist
				if (getTypeIndex(resource.types, e["resource"], "Resource") == nil) then return end

				return e
			end
		})
	})

	mj:log(data)
	mj:log(testdata)

	if testdata ~= nil then
		-- add whatever
	else
		-- you got an error
	end


	-- Add recipe
	craftable:addCraftable(identifier, data)

	-- Add items in crafting panels
	for _, group in ipairs(requiredCraftAreaGroups) do
		local key = gameObject.typeIndexMap[craftAreaGroup.types[group].key]
		if objectManager.inspectCraftPanelData[key] == nil then
			objectManager.inspectCraftPanelData[key] = {}
		end
		table.insert(objectManager.inspectCraftPanelData[key], constructable.types[identifier].index)
	end
end

return objectManager