--- Hammerstone: typeMaps.lua.
--- @Author SirLich

local typeMaps = {}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

function typeMaps:preload(parent)
	moduleManager:addModule("typeMaps", parent)
end


--- Helper function that allows converting a key into
--- an index.
--- @param key: The key to convert, such as 'sapiens'
--- @param map: The map to convert from, such as typeMaps.types.sapiens
function typeMaps:keyToIndex(key, map)
	for _, v in ipairs(map) do
		if v.key and v.key == key then
			return v.index
		end
	end
end

--- Helper function that allows converting a key into
--- an index.
--- @param index int -  The index to convert, such as '145'
--- @param map table -  The type map to convert from, such as typeMaps.types.sapiens
function typeMaps:indexToKey(index, map)
	for _, v in ipairs(map) do
		if v.index and v.index == index then
			return v.key
		end
	end
end

return shadow:shadow(typeMaps)