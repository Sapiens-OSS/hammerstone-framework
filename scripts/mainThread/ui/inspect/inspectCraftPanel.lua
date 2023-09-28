--- Hammerstone: inspectCraftPanel.lua
--- @author earmuffs

local mod = {
	loadOrder = 30,
}

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/legacyObjectManager"

function mod:onload(inspectCraftPanel)


	local super_load = inspectCraftPanel.load
	inspectCraftPanel.load = function(inspectCraftPanel_, serinspectUI_, inspectObjectUI_, world_, parentContainerView)

		-- Append new data to existing
		for key, value in pairs(objectManager.inspectCraftPanelData) do
			if inspectCraftPanel.itemLists[key] == nil then
				inspectCraftPanel.itemLists[key] = {}
			end
			for _, v in ipairs(value) do
				table.insert(inspectCraftPanel.itemLists[key], 1, v)
			end
		end

		super_load(inspectCraftPanel_, serinspectUI_, inspectObjectUI_, world_, parentContainerView)
	end
end

return mod
