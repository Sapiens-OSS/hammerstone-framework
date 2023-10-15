--- Hammerstone: ddapiManager.lua
-- This module controlls the registration of all Data Driven API objects. 
-- It will search the filesystem for mod files which should be loaded, and then
-- interact with Sapiens to create the objects.
-- @author SirLich, earmuffs

local ddapiManager = {
	inspectCraftPanelData = {},
	constructableIndexes = {},
	addPlansFunctions = {}, 
	orderActionSequenceLinks = {}, 
	createOrderInfos = {}
}

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local configLoader = mjrequire "hammerstone/ddapi/configLoader"
local hammerAPI = mjrequire "hammerAPI"

local entityManagers = {
	mjrequire "hammerstone/ddapi/entityManagers/behaviorManager", 
	mjrequire "hammerstone/ddapi/entityManagers/builderManager", 
	mjrequire "hammerstone/ddapi/entityManagers/knowledgeManager", --will be in 1.6.0
	mjrequire "hammerstone/ddapi/entityManagers/objectsManager", 
	mjrequire "hammerstone/ddapi/entityManagers/sharedManager", 
	mjrequire "hammerstone/ddapi/entityManagers/storageManager", 
}

hammerAPI:test()

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
local sortedObjectLoaders = {}

local function newModuleAdded(module)
	ddapiManager:tryLoadObjectDefinitions()
end

moduleManager:bind(newModuleAdded)

-- Initialize the full Data Driven API (DDAPI).
function ddapiManager:init()
	if utils:runOnceGuard("ddapi") then return end

	log:schema("ddapi", os.date() .. "\n")

	log:schema("ddapi", "Initializing DDAPI...")

	for _, entityManager in ipairs(entityManagers) do 
		entityManager:init(ddapiManager)
	end

	-- checks if we have circular dependencies and sorts the loaders
	ddapiManager:checkAndSortLoaders()

	-- Find config files from FS
	configLoader:findConfigFiles(entityManagers)
end

function ddapiManager:getLoaderAndSettings(objectType)
	for _, entityManager in ipairs(entityManagers) do 
		if entityManager.loaders[objectType] then
			return entityManager.loaders[objectType], entityManager.settings
		end
	end
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
	
	--[[ We need to let them "try" to load. If we don't, dependencies will not load
		 We do a check in loadObjectDefinitions and exit right away if it's disabled
	-- Don't enable disabled modules
	if objectLoader.disabled then
		return false, "Disabled"
	end
	]]

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
			local dependant = ddapiManager:getLoaderAndSettings(dependency)
			if not dependant then
				mj:error("Dependency ", dependency, " does not exist")
			else
				if dependant.loaded ~= true then
					local canDependencyLoad, dependencyReason = canLoadObjectType(dependant)
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
function ddapiManager:markObjectAsReadyToLoad(objectType, callbackFunction)
	log:schema("ddapi", "Object has been marked for load: " .. objectType)

	local loader = ddapiManager:getLoaderAndSettings(objectType)
	loader.waitingForStart = false

	local canLoad, reason = canLoadObjectType(loader)
	if not canLoad then
		log:schema("ddapi", "  ERROR: ", objectType, " has been marked for ready to load but cannot load yet. Reason: ", reason)
	end

	ddapiManager:tryLoadObjectDefinitions() -- Re-trigger start logic, in case no more modules will be loaded.
end

--- Attempts to load object definitions from the objectLoaders
function ddapiManager:tryLoadObjectDefinitions()
	for _, objectType in ipairs(sortedObjectLoaders) do
		local objectLoader, settings = ddapiManager:getLoaderAndSettings(objectType)
		if  canLoadObjectType(objectLoader) then
			ddapiManager:loadObjectDefinitions(objectType, objectLoader, settings)
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
function ddapiManager:tryAsTypeIndex(objectType, sourceObjectType, identifier, hmTable, key, optional, typeTable, typeTableName, onSuccess)

	local value = (optional and hmTable:getOrNil(key) or hmTable:get(key)):getValue()

	if not value then return end 

	local function addCallback(typeMapKey, setIndexFunction)
		ddapiManager:registerCallback(objectType, typeMapKey, typeTable, setIndexFunction, 
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

function ddapiManager:registerCallback(objectType, typeMapKey, typeTable, setIndexFunction, errorMessage)
	local objectLoader = ddapiManager:getLoaderAndSettings(objectType)

	if not objectLoader.callbacks then
		objectLoader.callbacks = {}
	end

	if not objectLoader.callbacks[typeMapKey] then
		objectLoader.callbacks[typeMapKey] = {}
	end

	table.insert(objectLoader.callbacks[typeMapKey], {setIndexFunction = setIndexFunction, typeTable = typeTable, errorMessage = errorMessage})
end

-- @param objectLoader - The loader to fetch definitions for
function ddapiManager:fetchRuntimeCompatibleDefinitions(objectLoader, settings)

	local outDefinitions = {}

	if not settings.cachedDefinitions then
		settings.cachedDefinitions = {}

		for _, configFilename in ipairs(settings.configFiles) do 
			configLoader:loadConfigFile(configFilename, settings)
		end
	end

	-- Handle regular Definitions
	for _, objectDefinition in ipairs(settings.cachedDefinitions) do

		-- This is for example a secondary level (such as hs_materials)
		if objectLoader.shared_unwrap then
			objectDefinition = objectDefinition[objectLoader.shared_unwrap]
			
			if objectDefinition then
				for i, data in ipairs(objectDefinition) do
					table.insert(outDefinitions, data)
				end
			end
		else
			table.insert(outDefinitions, objectDefinition)
		end
	end

	-- Handle Global Definitions
	for _, candidate in ipairs(configLoader.cachedSharedGlobalDefinitions) do
		local getterString = objectLoader.shared_getter or settings.luaGetter
		if candidate[getterString] then
			for i, element in ipairs(candidate[getterString]()) do
				table.insert(outDefinitions, element)
			end
		--else
			--mj:log("Warning: method not implemented: " ..  getterString)
		end
	end

	return outDefinitions
end

function ddapiManager:raiseError(...)
	log:schema("ddapi", ...)
	
	log:schema("ddapi", debug.traceback())
	os.exit(1)
end

-- Error handler for hmTables
local function ddapiErrorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)

	local arg = {...}

	switch(errorCode) : caseof {
		[hmtErrors.ofLengthFailed] = function()
			local requiredLength = arg[1]
			ddapiManager:raiseError("    ERROR: Value of key '" .. fieldKey .. "' requires " .. requiredLength .. " elements")
		end,

		[hmtErrors.ofTypeFailed] = function() ddapiManager:raiseError("    ERROR: key='" .. fieldKey .. "' should be of type '" .. arg[1] .. "', not '" .. type(fieldKey) .. "'") end,

		[hmtErrors.ofTypeTableFailed] = function() return ddapiManager:raiseError("    ERROR: Value type of key '" .. fieldKey .. "' is a table") end,

		[hmtErrors.RequiredFailed] = function()
			ddapiManager:raiseError("    ERROR: Missing required field: " .. fieldKey .. " in table: ", parentTable)
		end,

		[hmtErrors.isNotInTypeTableFailed] = function() 
			local displayAlias = arg[2]
			ddapiManager:raiseError("    WARNING: " .. displayAlias .. " already exists with key '" .. parentTable[fieldKey] .. "'") 
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
			ddapiManager:raiseError("    ERROR: Not enough elements in table to make vec"..vecType.." for table with key '"..fieldKey.."' in table: ", parentTable)
		end,

		[hmtErrors.NotVector] = function()
			local vecType = arg[1]
			ddapiManager:raiseError("    ERROR: Not able to convert to vec"..vecType.." with infos from table with key '"..fieldKey.."' in table: ", parentTable)
		end,

		default = function() ddapiManager:raiseError("    ERROR: ", msg) end
	}
end

-- Loads all objects for a given objectType
-- @param objectType - The type of object to load
-- @param objectLoader - A table, containing fields from 'objectLoaders'
function ddapiManager:loadObjectDefinitions(objectType, objectLoader, settings)
	objectLoader.loaded = true

	if objectLoader.disabled then
		log:schema("ddapi", "WARNING: Object is disabled, skipping: " .. objectType)
		return
	end

	log:schema("ddapi", string.format("\r\n\r\nGenerating %s definitions:", objectType))

	local objDefinitions = ddapiManager:fetchRuntimeCompatibleDefinitions(objectLoader, settings)

	if objDefinitions == nil or #objDefinitions == 0 then
		log:schema("ddapi", "  (no objects of this type created)")
		return
	end

	log:schema("ddapi", "Available Possible Definitions: " .. #objDefinitions)

	for i, objDef in ipairs(objDefinitions) do
		ddapiManager:loadObjectDefinition(objDef, objectLoader, objectType)
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
	local settingsDone, allDone = ddapiManager:isProcessDone(settings)
	if settingsDone then
		settings.cachedDefinitions = nil
	end
	if allDone then
		configLoader.cachedSharedGlobalDefinitions = nil
	end

	log:schema("ddapi", "-----")
end

function ddapiManager:loadObjectDefinition(objDef, objectLoader, objectType)
	objDef = hmt(objDef, ddapiErrorHandler)

	if objectLoader.shared_unwrap or not objectLoader.rootComponent then
		objectLoader.loadFunction(objectLoader.manager, objDef)
	else
		local components = objDef:getTable("components")

		if objectLoader.rootComponent and not components:hasKey(objectLoader.rootComponent) then 
			return
		end

		local description = objDef:getTable("description")
		local identifier = description:getStringValue("identifier")
		local rootComponent = components:getTable(objectLoader.rootComponent)

		log:schema("ddapi", "  " .. identifier)

		objectLoader.loadFunction(objectLoader.manager, objDef, description, components, identifier, rootComponent)

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

function ddapiManager:isProcessDone(settings)
	local allLoaded = true 

	for _, entityManager in ipairs(entityManagers) do 
		for _, objectLoader in pairs(entityManager.loaders) do 
			if entityManager.settings == settings and not objectLoader.loaded then
				return false, false
			elseif not objectLoader.loaded then 
				allLoaded = false
			end
		end
	end

	return true, allLoaded
end


function ddapiManager:checkAndSortLoaders()
	local dependencies = {}

	for _, entityManager in ipairs(entityManagers) do 
		for objectType, loader in pairs(entityManager.loaders) do 
			loader.manager = entityManager
			dependencies[objectType] = {}

			if loader.dependencies then
				for _, dep in ipairs(loader.dependencies) do 
					if not ddapiManager:getLoaderAndSettings(dep) then
						log:schema("ddapi", "ERROR. ObjectType ", dep, " does not exist")
						os.exit(1)
					end

					table.insert(dependencies[objectType], dep)
				end
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

return ddapiManager
