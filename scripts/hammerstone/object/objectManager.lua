--- Hammerstone: objectManager.lua
-- @author SirLich

local objectManager = {
	-- Unstructured game object definitions, read from FS
	objectConfigs = {},

	-- Unstructured storage configurations, read from FS
	storageConfigs = {},

	-- Map between storage identifiers and objects that should use this storage.
	-- Collected when generating objects, and inserted when generating storages.
	-- @format map<string, array<string>>
	objectsForStorage = {}

}

-- sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

---------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Private API
---------------------------------------------------------------------------------

function objectManager:init()
	objectManager:loadConfigs()
end

--- Loops over known config locations and attempts to load them
-- TODO: Do mods get stored in different places when downloaded from steam?
-- TODO: Make sure it only loads configs from enabled mods.
-- TODO: Call this method from the correct location
function objectManager:loadConfigs()
	log:log("Loading Configuration files:")
	local modsDirectory = fileUtils.getSavePath("mods")
	local mods = fileUtils.getDirectoryContents(modsDirectory)
	local count = 0;

	-- Objects
	for i, mod in ipairs(mods) do
		local objectConfigDir = modsDirectory .. "/" .. mod .. "/hammerstone/objects/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectManager.objectConfigs)
		end
	end

	-- Storage
	for i, mod in ipairs(mods) do
		local objectConfigDir = modsDirectory .. "/" .. mod .. "/hammerstone/storage/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for j, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			count = count + 1;
			objectManager:loadConfig(fullPath, objectManager.storageConfigs)
		end
	end

	log:log("Loaded Configs totalling: " .. count)
end

function objectManager:loadConfig(path, type)
	log:log("Loading DDAPI Config of type " .. type .. " at " .. path)
	local configString = fileUtils.getFileContents(path)
	local configTable = json:decode(configString)
	table.insert(type, configTable)
end

--- Generates resource definitions based on the loaded config, and registers them.
-- @param resource - Module definition of resource.lua
function objectManager:generateResourceDefinitions(resource)
	log:log("Generating resource definitions:")
	for i, config in ipairs(objectManager.objectConfigs) do
		objectManager:generateResourceDefinition(resource, config)
	end
end

function objectManager:generateResourceDefinition(resource, config)
	local object = config["hammerstone:object"]
	local description = object["description"]
	local components = object["components"]
	local gom = components["object"]
	local localization = gom["localization"]

	local identifier = description["identifier"]
	local name = localization["name"]
	local plural = localization["plural"]
	local scale = gom["scale"]
	local model = gom["model"]
	local physics = gom["physics"]
	local marker_positions = gom["marker_positions"]

	local newResource = {
		key = identifier,
		name = name,
		plural = plural,
		foodValue = 0.7, --TODO
		foodPortionCount = 1, -- TODO
		displayGameObjectTypeIndex = typeMaps.types.gameObject[identifier] -- TODO: Does this work???
	}

	resource:addResource(identifier, newResource)
end

--- Generates DDAPI storage objects.
function objectManager:generateStorageObjects(storage)
	log:log("Generating Storage Objects:")
	for i, config in ipairs(objectManager.storageConfigs) do
		objectManager:generateStorageObject(storage, config)
	end
end

function objectManager:generateStorageObject(storageModule, config)
	-- Load structured information
	local object = config["hammerstone:storage"]
	local description = object["description"]
	local carry = object.components["hammerstone:carry"]
	local storage = object.components["hammerstone:storage"]

	-- TODO: Can we somehow cache which objects should be added to this storage?
	local newStorage = {

	}

end

---------------------------------------------------------------------------------
-- Game Object Handling
---------------------------------------------------------------------------------

--- Registers an object into a storage
-- @param identifier - The identifier of the object. e.g., hs:cake
-- @param componentData - The inner-table data for `hammerstone:storage`
function objectManager:registerObjectForStorage(identifier, componentData)
	if componentData == nil then
		return
	end

	-- Initialize this storage container, if this is the first item we're adding.
	local storageIdentifier = componentData.identifier
	if objectManager.objectsForStorage[storageIdentifier] == nil then
		objectManager.objectsForStorage[storageIdentifier] = {}
	end

	-- Insert the object identifier for this storage container
	table.insert(objectManager.objectsForStorage[storageIdentifier], identifier)
end

--- Called from `gameObject.lua`, and generates all game objects from cached storage
-- @param gameObject - gameObject module.
function objectManager:generateGameObjects(gameObject)
	log:log("Generating GameObjects:")

	for i, config in ipairs(objectManager.objectConfigs) do
		objectManager:registerGameObject(gameObject, config)
	end
end

function objectManager:registerGameObject(gameObject, config)
	local object = config["hammerstone:object"]
	local description = object["description"]
	local components = object["components"]
	local gom = components["object"]
	local localization = gom["localization"]

	local identifier = description["identifier"]

	local name = localization["name"]
	local plural = localization["plural"]
	local scale = gom["scale"]
	local model = gom["model"]
	local physics = gom["physics"]
	local marker_positions = gom["marker_positions"]

	local resource = mjrequire "common/resource";

	local newObject = {
		name = name,
		plural = plural,
		modelName = model,
		scale = scale,
		hasPhysics = physics,

		resourceTypeIndex = resource.types[identifier].index,

		-- TODO
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	objectManager:registerObjectForStorage(identifier, components["hammerstone:storage"])
	gameObject:addGameObject(identifier, newObject)
end

--- Generates the evolving object, based on config files that were previouslly loaded.
-- @param evolvingObject - Module reference to evolvingObject.lua
function objectManager:generateEvolvingObjects(evolvingObject)
	mj:log("Hey")
end

return objectManager


