--- Hammerstone: typeMaps.lua.
--- @Author SirLich

local mod = {
	loadOrder = 1
}

function mod:onload(typeMaps)
	function typeMaps:keyToIndex(key, map)
		--- Helper function that allows converting a key into
		--- an index.
		--- @param key: The key to convert, such as 'sapiens'
		--- @param map: The map to convert from, such as typeMaps.types.sapiens

		for _, v in ipairs(map) do
			if v.key and v.key == key then
				return v.index
			end
		end
	end
end

return mod