--- Hammerstone: configLoader.lua
-- Config loader is responsible for loading and staging all configs, read from the filesystem.
-- @author SirLich & earmuffs

local loader = {
	-- Whether the configs have been read from the FS
	isInitialized = false,

	handlers = {},

	configTypes = {
		object = {
			key = "object",
			unwrap = "hammerstone:object_definition",
			configPath = "/hammerstone/objects",
			luaGetter = "getObjectConfigs",
			jsonStrings = {},
			luaStrings = {},
			cachedConfigs = {}
		},
		storage = {
			key = "storage",
			unwrap = "hammerstone:storage_definition",
			configPath = "/hammerstone/storage",
			luaGetter = "getStorageConfigs",
			jsonStrings = {},
			luaStrings = {},
			cachedConfigs = {}
		},
		shared = {
			key = "shared",
			configPath = "/hammerstone/shared/",
			unwrap = "hammerstone:global_definitions",
			luaGetter = "getGlobalConfigs",
			jsonStrings = {},
			luaStrings = {},
			cachedConfigs = {}
		},
		builder = {
			key = "builder",
			configPath = "/hammerstone/builders/",
			jsonStrings = {},
			luaStrings = {},
			cachedConfigs = {}
		},
		skill = {
			key = "skill",
			unwrap = "hammerstone:skill_definition",
			configPath = "/hammerstone/skills",
			luaGetter = "getSkillConfigs",
			jsonStrings = {},
			luaStrings = {},
			cachedConfigs = {}
		}
	},

	-- These contain the "shared" version, which uses getters
	-- The one in the table above are for the individual embeded lua configs
	luaStrings = {}
}

-- Sapiens
local modManager = mjrequire "common/modManager"

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

function loader:addConfig()
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
function loader:loadConfigs()
	loader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Find all the enabled world mods
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	
    -- Loop through enabled world mods and check if they have a DDAPI directory
	for _, mod in ipairs(mods) do

		-- TODO loop through handlers and add them to their queues

		-- Loop through config types
		for _, config in pairs(loader.configTypes) do
			if config["configPath"] ~= nil then
				local objectConfigDir = mod.path .. config.configPath
                
				-- Fetch all DDAPI object files
				local files = loader:discoverRecursive(objectConfigDir, {".json", ".lua"})
				for _, file in ipairs(files) do
					loader:loadConfig(file, config)
				end
			end
		end
	end
end

function loader:loadHandlers()
	-- Find all the enabled world mods
	local mods = modManager.enabledModDirNamesAndVersionsByType.world

	-- Loop through enabled world mods and find their handlers
	for _, mod in ipairs(mods) do
		local handlersPath = mod.path .. "/hammerstone/handlers"
		local handlers = loader:discoverRecursive(handlersPath, {".lua"})
		for _, handlerPath in ipairs(handlers) do
			local handlerRaw = fileUtils.getFileContents(handlerPath)
			local status, handler = pcall(loadstring(handlerRaw))
			if status and handler ~= nil then
				table.insert(loader.handlers, handler)
			end
		end
	end
end

--- Loads a single config from the filesystem and saves it as a string, for future processing
-- @param path
-- @param type - The type of the config
-- @param unwrap - The top level of the config, which we optionally 'unwrap' to expose the inner definitions.
function loader:loadConfig(path, configData)
	log:schema("ddapi", "  " .. path)

	-- No longer need this check because the discoverRecursive function only returns .json and .lua files
	--[[
	if not stringEndsWith(path, ".json") and not stringEndsWith(path, ".lua") then
		log:schema("ddapi", "  WARNING: " .. path .. " is skipped, since it's not a lua or json file.")
		return
	end
	]]

	local configString = fileUtils.getFileContents(path)
	
	-- Load json configs
	if stringEndsWith(path, ".json") then
		table.insert(configData.jsonStrings, configString)
		return
	end
	
	-- Handle lua configd
	if stringEndsWith(path, ".lua") then

		-- Builders are special, and sorted together
		-- otherwise, sort into the config type
		if configData.key == "builder" then
			table.insert(loader.luaStrings, configString)
		else
			table.insert(configData.luaStrings, configString)
		end
		return
	end


end

-- @param configData - The table, holding information on the kind of config to fetch
function loader:fetchRuntimeCompatibleConfigs(configData)
	local configType = configData.configType

	-- TODO: Reimplement Cache
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

	-- Handle lua strings (single)
	for i, luaString in ipairs(configType.luaStrings) do
		local status, configTable = pcall(loadstring(luaString))
		if status and configTable ~= {} and configTable ~= nil then

			-- TODO This is copy/pasted
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
	end

	-- Handle Lua Strings (shared)
	for i, luaString in ipairs(loader.luaStrings) do
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

-- Discovers files recursively
--@param dir The directory to search
--@param validEndings A table of strings with valid endings (eg ".json" and ".lua")
function loader:discoverRecursive(dir, validEndings)
	local files = {}
	local dirContents = fileUtils.getDirectoryContents(dir)
	for _, path in ipairs(dirContents) do
		local fullPath = dir .. "/" .. path

		-- Check if we match any file endings
		for _, ending in ipairs(validEndings) do
			if stringEndsWith(fullPath, ending) then
				table.insert(files, {
					path = fullPath,
					matchedEnding = ending
				})
				goto nextPath				
			end
		end

		-- If not, we recurse
		files = {table.unpack(files), table.unpack(loader:discoverRecursive(fullPath, validEndings))}
		::nextPath::
	end

	return files
end


return loader