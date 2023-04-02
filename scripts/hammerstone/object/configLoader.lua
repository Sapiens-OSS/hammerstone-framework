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
			configPath = "/hammerstone/objects/",
			luaGetter = "getObjectConfigs",
			jsonStrings = {},
			cachedConfigs = {}
		},
		storage = {
			key = "storage",
			unwrap = "hammerstone:storage_definition",
			configPath = "/hammerstone/storage/",
			luaGetter = "getStorageConfigs",
			jsonStrings = {},
			cachedConfigs = {}
		},
		shared = {
			key = "shared",
			configPath = "/hammerstone/global_definitions/",
			unwrap = "hammerstone:global_definitions",
			luaGetter = "getGlobalConfigs",
			jsonStrings = {},
			cachedConfigs = {}
		},
		recipe = {
			key = "recipe",
			unwrap = "hammerstone:recipe_definition",
			luaGetter = "getRecipeConfigs",
			configPath = "/hammerstone/recipes/",
			jsonStrings = {},
			cachedConfigs = {}
		},
		skill = {
			key = "skill",
			unwrap = "hammerstone:skill_definition",
			configPath = "/hammerstone/skills/",
			luaGetter = "getSkillConfigs",
			jsonStrings = {},
			cachedConfigs = {}
		}
	},

	luaStrings = {}
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
function configLoader:loadConfigs()
	configLoader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0;
	
	for i, mod in ipairs(mods) do
		for routeName, config in pairs(configLoader.configTypes) do
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
	
	-- Load json configs
	if stringEndsWith(path, ".json") then
		table.insert(configData.jsonStrings, configString)
	end

	-- Load lua configs
	if stringEndsWith(path, ".lua") then
		table.insert(configLoader.luaStrings, configString)
	end
end

-- @param configData - The table, holding information on the kind of config to fetch
function configLoader:fetchRuntimeCompatibleConfigs(configData)
	mj:log("Fetching Runtime Compatible Configs:")
	local configType = configData.configType

	mj:log("Json Strings: " .. #configType.jsonStrings)

	-- -- Access from the cache, if available
	-- local cachedConfigs = configType.cachedConfigs
	-- if cachedConfigs ~= nil and cachedConfigs ~= {} then
	-- 	mj:log("SHORTCUT")
	-- 	mj:log(cachedConfigs)
	-- 	return cachedConfigs
	-- end

	-- Otherwise, we need to generate it
	local outConfigs = {}

	-- Handle Json Strings
	for i, jsonString in ipairs(configType.jsonStrings) do
		local configTable = json:decode(jsonString)

		-- If the 'unwrap' exists, we can use this to strip the stored definition to be simpler.
		if configType.unwrap then
			configTable = configTable[configType.unwrap]
		end

		-- This is like, a secondary level (such as hs_materials)
		if configData.shared_unwrap then
			configTable = configTable[configData.shared_unwrap]
			
			if configTable then
				for i, data in ipairs(configTable) do
					table.insert(outConfigs, data)
				end
			end
		else
			table.insert(outConfigs, configTable)
		end
	end

	-- Handle Lua Strings
	mj:log("Checking Lua Strings:")
	mj:log(#configLoader.luaStrings)
	for i, luaString in ipairs(configLoader.luaStrings) do
		local configFile = loadstring(luaString, "ERROR: Failed to load string as lua file")

		if configFile then
			local function errorhandler(err)
				mj:log("ERROR: Error handler triggered.")
			end
			local ok, potentialConfigFile = xpcall(configFile, errorhandler)
			if not ok then
				mj:log("ERROR: Config couldn't be gatherd.")
			else
				
				local getterString = configData.shared_getter or configType.luaGetter
				if potentialConfigFile[getterString] then
					for i, element in ipairs(potentialConfigFile[getterString]()) do
						table.insert(outConfigs, element)
					end
				else
					-- mj:log("Warning: method not implemented: " ..  getterString)
				end
			end
		end
	end

	-- configType.cachedConfigs = outConfigs

	return outConfigs
end


return configLoader