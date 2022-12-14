--- Hammerstone: objectManager.lua
--- @author SirLich

local objectManager = {
	objects = {},
}

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"

---------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------

function objectManager:registerObjectClient()
	objectManager:registerObject()
end

function objectManager:registerObjectServer()
	objectManager:registerObject()
end

function objectManager:registerObjectFromPath(path)
	local configString = fileUtils.getFileContents(path)
	local configTable = json:decode(configString)
	objectManager:registerObject(configTable)

end

function objectManager:registerObject(data)

	mj:log("REGISTERING OBJECT")
	mj:log(data)

	local object = data["hammerstone:object"]
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

	local newObject = {
		name = name,
		plural = plural,
		modelName = model,
		scale = scale,
		hasPhysics = physics,

		-- resourceTypeIndex = resource.types.firedBowlGruel.index,

		-- TODO
		markerPositions = {
			{
				worldOffset = vec3(mj:mToP(0.0), mj:mToP(0.3), mj:mToP(0.0))
			}
		}
	}

	-- Register the new object to the mods local data. This will all be processed later.
	objectManager.objects[identifier] = newObject
end

---------------------------------------------------------------------------------
-- Private API
---------------------------------------------------------------------------------

function objectManager:finalizeObjectDefinitions(gameObject)
	mj:log("HS: Finalizing Objects")

	local modsDirectory = fileUtils.getSavePath("mods")
	local mods = fileUtils.getDirectoryContents(modsDirectory)
	for i, mod in ipairs(mods) do
		local objectConfigDir = modsDirectory .. "/" .. mod .. "/hammerstone/objects/"
		local configs = fileUtils.getDirectoryContents(objectConfigDir)
		for i, config in ipairs(configs) do
			local fullPath =  objectConfigDir .. config
			mj:log(fullPath)
			objectManager:registerObjectFromPath(fullPath)
		end
	end

	gameObject:addGameObjectsFromTable(objectManager.objects)
end

return objectManager


