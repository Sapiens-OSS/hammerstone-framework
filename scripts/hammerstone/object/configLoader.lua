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

-- The routest, directing how the configs are read from the FS. 
-- Each route here maps to a FILE TYPE. The fact that multiple *objects* can be generated from the same
-- file type has no impact herre.
local routes = {
	gameObject = {
		path = "/hammerstone/objects/",
		dbTable = configLoader.objectConfigs
	},
	storage = {
		path = "/hammerstone/storage/",
		dbTable = configLoader.storageConfigs
	},
	recipe = {
		path = "/hammerstone/recipes/",
		dbTable = configLoader.recipeConfigs
	},
	material = {
		path = "/hammerstone/materials/",
		dbTable = configLoader.materialConfigs
	},
	skill = {
		path = "/hammerstone/skills/",
		dbTable = configLoader.skillConfigs
	}
}

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

-- Loops over known config locations and attempts to load them
function configLoader:loadConfigs()
	configLoader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Loads files at path to dbTable for each active mod
	local modManager = mjrequire "common/modManager"
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	local count = 0; local disabledCount = 0

	for i, mod in ipairs(mods) do
		for _, route in pairs(routes) do
			if route.enabled then
				local objectConfigDir = mod.path .. route.path
				local configs = fileUtils.getDirectoryContents(objectConfigDir)
				for j, config in ipairs(configs) do
					local fullPath =  objectConfigDir .. config
					count = count + 1;

					configLoader:loadConfig(fullPath, route.dbTable)
				end
			else
				disabledCount = disabledCount + 1
			end
		end
	end

	log:schema("ddapi", "Loaded configs totalling: " .. count)

	if disabledCount ~= 0 then
		log:schema("ddapi", "Disabled configs totalling: " .. disabledCount)
		log:schema("ddapi", "Disabled configs:")
		for _, route in pairs(routes) do
			if not route.enabled then
				log:schema("ddapi", "  " .. route.path)
			end
		end
	end
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