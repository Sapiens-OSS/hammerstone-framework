--- Hammerstone: configLoader.lua
-- Config loader is responsible for loading and staging all configs, read from the filesystem.
-- @author SirLich & earmuffs

local configLoader = {
	-- Whether the configs have been read from the FS
	isInitialized = false,
	cachedSharedGlobalDefinitions = {}
}


-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

function configLoader:addConfig()
	-- TODO Continue here
end

-- Loops over known config locations and attempts to find config files
function configLoader:findConfigFiles(modManager, entityManagers)
	configLoader.isInitialized = true
	log:schema("ddapi", "Loading configuration files from FileSystem:")

	-- Loads files at path to dbTable for each active mod
	local mods = modManager.enabledModDirNamesAndVersionsByType.world
	
	for i, mod in ipairs(mods) do
		for _, entityManager in pairs(entityManagers) do
			if entityManager.settings["configPath"] ~= nil then
				local objectConfigDir = mod.path .. entityManager.settings.configPath
				configLoader:findConfigsFilesInDirectory(objectConfigDir, entityManager.settings)
			end
		end
	end
end

function configLoader:findConfigsFilesInDirectory(objectConfigDir, settings)
	mj:log("Fetching Configs from " .. objectConfigDir)
	local configPaths = fileUtils.getDirectoryContents(objectConfigDir)
	for j, configPath in ipairs(configPaths) do
		local fullPath =  objectConfigDir .. "/" .. configPath
		
		if fullPath:find("%.lua$") or fullPath:find("%.json$") then
			-- Load them right away if they're shared
			if settings.isGlobal then
				configLoader:loadConfigFile(fullPath, settings)
			else -- If not global, they'll be loaded the first time they're required at runtime
				table.insert(settings.configFiles, fullPath)
			end
		else
			configLoader:findConfigsFilesInDirectory(fullPath, settings)
		end
	end
end

--- Loads a single config from the filesystem 
-- @param configFilename - the full filename of the config file
-- @param settings - The settings to use to load the config files
function configLoader:loadConfigFile(configFilename, settings)
	log:schema("ddapi", "  " .. configFilename)

	-- Handle json configs
	if configFilename:find("%.json$") then
		local jsonString = fileUtils.getFileContents(configFilename)

		local objectDefinition = json:decode(jsonString)

		-- If the 'unwrap' exists, we can use this to strip the stored definition to be simpler.
		if settings.unwrap then
			objectDefinition = objectDefinition[settings.unwrap]
		end

		table.insert(settings.cachedDefinitions, objectDefinition)

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
			if settings.isGlobal then
				table.insert(configLoader.cachedSharedGlobalDefinitions, objectDefinition)
			else
				table.insert(settings.cachedDefinitions, objectDefinition)
			end
		end
	end
end

return configLoader