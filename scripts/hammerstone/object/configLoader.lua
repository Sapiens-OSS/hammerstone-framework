--- Hammerstone: configLoader.lua
-- Config loader is responsible for loading and staging all configs, read from the filesystem.
-- @author SirLich & earmuffs

local configLoader = {
	-- Whether the configs have been read from the FS
	isInitialized = false,

	-- The config types
	configTypes = {
		object = "object",
		storage = "storage",
		recipe = "recipe",
		material = "material",
		skill = "skill",
		shared = "shared"
	},

	unwrapsForConfigType = {
		object = "hammerstone:object_definition",
		storage ="hammerstone:storage_definition",
		recipe = "hammerstone:recipe_definition",
		material = "hammerstone:material_definition",
		skill = "hammerstone:skill_definition",
		shared = "hammerstone:global_definitions"
	},

	-- The actual configs, read from the FS
	jsonStrings = {

	},

	luaStrings = {

	},

	-- Cached configs, that have been configured for direct processing
	cachedConfigs = {

	}
}

for key, configType in pairs(configLoader.configTypes) do
	configLoader.jsonStrings[configType] = {}
	configLoader.luaStrings[configType] = {}
end


-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

function configLoader:addConfig()
	-- TODO Continue here
end

-- TODO: Move this somewhere more reasonable
--- Returns true if the string ends with a suffix
-- @param str The string to test against, eg. bob.json
-- @param suffix The suffix to test for, eg. .json
local function stringEndsWith(str, suffix)
    return string.sub(str, -#suffix) == suffix
end


-- Loops over known config locations and attempts to load them
-- @param objectLoader a table with a very specific structure where the loaded configs will be delivered.
function configLoader:loadConfigs(objectLoader)
	configLoader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0;
	
	for i, mod in ipairs(mods) do
		for routeName, config in pairs(objectLoader) do
			if config["configPath"] ~= nil then
				local objectConfigDir = mod.path .. config.configPath
				local configPaths = fileUtils.getDirectoryContents(objectConfigDir)
				for j, configPath in ipairs(configPaths) do
					local fullPath =  objectConfigDir .. configPath
					count = count + 1;
					configLoader:loadConfig(fullPath, config)
				end
			end
			
		end
	end

	log:schema("ddapi", "Loaded configs totalling: " .. count)
end

--- Loads a single config from the filesystem and saves it as a string, for future processing
-- @param path
-- @param type - The type of the config
-- @param unwrap - The top level of the config, which we optionally 'unwrap' to expose the inner definitions.
function configLoader:loadConfig(path, configData)
	log:schema("ddapi", "  " .. path)
	local configString = fileUtils.getFileContents(path)
	local configType = configData.configType
	
	-- Load json configs
	if stringEndsWith(path, ".json") then
		table.insert(configLoader.jsonStrings[configType], configString)
	end

	-- Load lua configs
	if stringEndsWith(path, ".lua") then
		table.insert(configLoader.luaStrings[configType], configString)
	end
end

-- @param configData - The table, holding information on the kind of config to fetch
function configLoader:fetchRuntimeCompatibleConfigs(configData)
	local configType = configData.configType
	local unwrap = configLoader.unwrapsForConfigType[configType]

	-- Access from the cache, if available
	local cachedConfigs = configLoader.cachedConfigs[configType]
	if cachedConfigs ~= nil and cachedConfigs ~= {} then
		return cachedConfigs
	end

	-- Otherwise, we need to generate it
	local outConfigs = {}

	-- Handle Json Strings
	for i, jsonString in ipairs(configLoader.jsonStrings[configType]) do
		local configTable = json:decode(jsonString)

		-- If the 'unwrap' exists, we can use this to strip the stored definition to be simpler.
		if unwrap then
			configTable = configTable[unwrap]
		end

		-- Insert
		table.insert(outConfigs, configTable)
	end

	-- Handle Lua Strings
	for i, luaString in ipairs(configLoader.luaStrings[configType]) do
		local configFile = loadstring(luaString, "ERROR: Failed to load string as lua file")

		if configFile then
			local function errorhandler(err)
				mj:log("ERROR: Error handler triggered.")
			end
			local ok, potentialConfigFile = xpcall(configFile, errorhandler)
			if not ok then
				mj:log("ERROR: Config couldn't be gatherd.")
			else
				
				if potentialConfigFile.getConfigs then
					for i, element in ipairs(potentialConfigFile:getConfigs()) do
						table.insert(outConfigs, element)
					end
				else
					mj:log("ERROR: You failed to implement `getConfigs`")
				end
			end
		end
	end

	return outConfigs
end

return configLoader