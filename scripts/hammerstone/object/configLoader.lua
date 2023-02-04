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
					configLoader:loadConfig(fullPath, config.configSource)
				end
			end
			
		end
	end

	log:schema("ddapi", "Loaded configs totalling: " .. count)
end

--- Loads a single config from the filesystem and decodes it from json to lua
-- @param path
-- @param type
function configLoader:loadConfig(path, type)
	log:schema("ddapi", "  " .. path)

	local configString = fileUtils.getFileContents(path)
	local configTable = json:decode(configString)
	table.insert(type, configTable)
end

return configLoader