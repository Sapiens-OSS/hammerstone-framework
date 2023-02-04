--- Hammerstone: configLoader.lua
-- Config loader is responsible for loading and staging all configs, read from the filesystem.
-- @author SirLich & earmuffs

local configLoader = {
	-- Whether the configs have been read from the FS
	isInitialized = false,

	-- The actual configs, read from the FS
	configs = {
		objectConfigs = {},
		storageConfigs = {},
		recipeConfigs = {},
		materialConfigs = {},
		skillConfigs = {}
	}
}

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
					configLoader:loadConfig(fullPath, config.configSource, config.unwrap)
				end
			end
			
		end
	end

	log:schema("ddapi", "Loaded configs totalling: " .. count)
end

--- Loads a single config from the filesystem and decodes it from json to lua
-- @param path
-- @param type
-- @param unwrap - The top level of the config, which we optionally 'unwrap' to expose the inner definitions.
function configLoader:loadConfig(path, type, unwrap)
	log:schema("ddapi", "  " .. path)

	local configTable = {}
	local configString = fileUtils.getFileContents(path)

	-- Load json configs
	if stringEndsWith(path, ".json") then
		configTable = json:decode(configString)

		-- If the 'unwrap' exists, we can use this to strip the stored definition to be simpler.
		if unwrap then
			configTable = configTable[unwrap]
		end
	end

	-- Load lua configs
	if stringEndsWith(path, ".lua") then
		local configFile = loadstring(configString, "Yeah sorry, you're screwed.")

		if configFile then
			local function errorhandler(err)
				mj:log("Rats!")
			end
			local ok, potentialConfigFile = xpcall(configFile, errorhandler)
			if not ok then
				mj:log("Wow...")
			else
				configTable = potentialConfigFile
			end
		end
	end

	mj:log("ADDING CONFIG")
	mj:log(configTable)
	if configTable then
		table.insert(type, configTable)
	else
		log:schema("ddapi", "^^^ This config is fucked.")
	end
end

return configLoader