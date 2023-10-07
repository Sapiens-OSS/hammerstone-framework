--- Hammerstone: configLoader.lua
-- Config loader is responsible for loading and staging all configs, read from the filesystem.
-- @author SirLich & earmuffs

local configLoader = {
	-- Whether the configs have been read from the FS
	isInitialized = false,

	configTypes = {
		object = {
			key = "object",
			unwrap = "hammerstone:object_definition",
			configPath = "/hammerstone/objects",
			luaGetter = "getObjectConfigs",
			configFiles = {},
		},
		storage = {
			key = "storage",
			unwrap = "hammerstone:storage_definition",
			configPath = "/hammerstone/storage",
			luaGetter = "getStorageConfigs",
			configFiles = {},
		},
		shared = {
			key = "shared",
			configPath = "/hammerstone/shared/",
			unwrap = "hammerstone:global_definitions",
			luaGetter = "getGlobalConfigs",
			configFiles = {},
		},
		builder = {
			key = "builder",
			isGlobal = true,
			configPath = "/hammerstone/builders/",
		},
		skill = {
			key = "skill",
			unwrap = "hammerstone:skill_definition",
			configPath = "/hammerstone/skills",
			luaGetter = "getSkillConfigs",
			configFiles = {},
		}, 
		--[[plannableAction = {
			key = "plannableAction",
			configPath = "/hammerstone/plannableActions", 
			configFiles = {},
		}]]
	},

	cachedSharedGlobalDefinitions = {}
}


-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

function configLoader:addConfig()
	-- TODO Continue here
end

-- Loops over known config locations and attempts to find config files
function configLoader:findConfigFiles()
	configLoader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	
	for i, mod in ipairs(mods) do
		for routeName, configType in pairs(configLoader.configTypes) do
			if configType["configPath"] ~= nil then
				local objectConfigDir = mod.path .. configType.configPath
				configLoader:findConfigsFilesInDirectory(objectConfigDir, configType)
			end
		end
	end
end

function configLoader:findConfigsFilesInDirectory(objectConfigDir, configType)
	mj:log("Fetching Configs from " .. objectConfigDir)
	local configPaths = fileUtils.getDirectoryContents(objectConfigDir)
	for j, configPath in ipairs(configPaths) do
		local fullPath =  objectConfigDir .. "/" .. configPath
		
		if fullPath:find("%.lua$") or fullPath:find("%.json$") then
			-- Load them right away if they're shared
			if configType.isGlobal then
				configLoader:loadConfigFile(fullPath, configType)
			else -- If not global, they'll be loaded the first time they're required at runtime
				table.insert(configType.configFiles, fullPath)
			end
		else
			configLoader:findConfigsFilesInDirectory(fullPath, configType)
		end
	end
end

--- Loads a single config from the filesystem 
-- @param configFilename - the full filename of the config file
-- @param configType - The configType to use to load the config files
function configLoader:loadConfigFile(configFilename, configType)
	log:schema("ddapi", "  " .. configFilename)

	-- Handle json configs
	if configFilename:find("%.json$") then
		local jsonString = fileUtils.getFileContents(configFilename)

		local objectDefinition = json:decode(jsonString)

		-- If the 'unwrap' exists, we can use this to strip the stored definition to be simpler.
		if configType.unwrap then
			objectDefinition = objectDefinition[configType.unwrap]
		end

		table.insert(configType.cachedDefinitions, objectDefinition)

	-- Handle lua configs
	elseif configFilename:find("%.lua$") then
		local chunk, errMsg = loadfile(configFilename)

		if not chunk then
			log:schema("ddapi", "ERROR: Failed to load string as lua file: ", errMsg)
			return
		end

		local function errorHandler(errMsg2)
			log:schema("ddapi", "ERROR: Failed to execute the lua file: ", errMsg2)
		end

		local ok, objectDefinition = xpcall(chunk, errorHandler)

		if ok and not objectDefinition then
			log:schema("ddapi", "ERROR: The config file returned nothing")
		elseif ok then
			if configType.isGlobal then
				table.insert(configLoader.cachedSharedGlobalDefinitions, objectDefinition)
			else
				table.insert(configType.cachedDefinitions, objectDefinition)
			end
		end
	end
end

-- @param objectLoader - The loader to fetch definitions for
function configLoader:fetchRuntimeCompatibleDefinitions(objectLoader)

	local configType = objectLoader.configType
	local outDefinitions = {}

	if not configType.cachedDefinitions then
		configType.cachedDefinitions = {}

		for _, configFilename in ipairs(configType.configFiles) do 
			configLoader:loadConfigFile(configFilename, configType)
		end
	end

	-- Handle regular Definitions
	for _, objectDefinition in ipairs(configType.cachedDefinitions) do

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
		local getterString = objectLoader.shared_getter or configType.luaGetter
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

return configLoader