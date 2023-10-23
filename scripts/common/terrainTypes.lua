--- Hammerstone: terainTypes.lua
--- @author nmattela

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local shadow = mjrequire "hammerstone/utils/shadow"

local terrainTypes = {}

--- Add a new terrain base type.
-- @param key: The key to add, such as 'riverSand'
-- @param objectData: The object to add, containing all fields.
function terrainTypes:addBaseType(key, objectData)
	if self.baseTypes[key] then
		log:warn("Overwriting baseType:", key)
	end

	typeMaps:insert("terrainBase", self.baseTypes, objectData)

	-- Recache the type maps
	self.baseTypesArray = typeMaps:createValidTypesArray("terrainBase", self.baseTypes)

	return objectData.index
end

--- Allows adding a terrain variation.
-- @param key: The key to add, such as 'snow'
-- @param objectData: The object to add, containing all fields.
function terrainTypes:addVariation(key, objectType)
	if self.variations[key] then
		log:warn("Overwriting variation:", key)
	end

	typeMaps:insert("terrainVariations", self.variations, objectType)

	-- Recache the type maps
	self.variationsArray = typeMaps:createValidTypesArray("terrainVariations", self.variations)


	return objectType.index
end

return shadow:shadow(terrainTypes, 0)