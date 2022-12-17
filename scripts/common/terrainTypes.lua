--- Hammerstone: terainTypes.lua
--- @author nmattela

local mod = {

	-- A low load order makes sense, because we're exposing new methods.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local log = mjrequire "common/logging"

function mod:onload(terrainTypes)

	--- Add a new terrain base type.
	-- @param key: The key to add, such as 'riverSand'
	-- @param objectData: The object to add, containing all fields.
	function terrainTypes:addBaseType(key, objectData)
		local typeIndexMap = typeMaps.types.terrainBase
	
		local index = typeIndexMap[key]
		if not index then
			log:warn("Failed to add baseType because index was nil for key: ", key)
			return nil
		end

		if terrainTypes.baseTypes[key] then
			log:warn("Overwriting baseType:", key)
		end

		objectData.key = key
		objectData.index = index
		typeMaps:insert("terrainBase", terrainTypes.baseTypes, objectData)

		-- Recache the type maps
		terrainTypes.baseTypesArray = typeMaps:createValidTypesArray("terrainBase", terrainTypes.baseTypes)

		return index
	end

	--- Allows adding a terrain variation.
	-- @param key: The key to add, such as 'snow'
	-- @param objectData: The object to add, containing all fields.
	function terrainTypes:addVariation(key, objectType)
		local typeIndexMap = typeMaps.types.terrainVariations
	
		local index = typeIndexMap[key]
		if not index then
			log:warn("Failed to add variation because index was nil for key: ", key)
			return nil
		end

		if terrainTypes.variations[key] then
			log:warn("Overwriting variation:", key)
		end

		objectType.key = key
		objectType.index = index
		typeMaps:insert("terrainVariations", terrainTypes.variations, objectType)

		-- Recache the type maps
		terrainTypes.variationsArray = typeMaps:createValidTypesArray("terrainVariations", terrainTypes.variations)
	
	
		return index
	end
end

return mod