--- Hammerstone: buildUI.lua
--- @author SirLich

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local mod = {
    loadOrder = 30,
}


function mod:onload(buildUI)
    -- Filled via DDAPI
    buildUI.hammerstoneItems = {}

    moduleManager:addModule("buildUI", buildUI)



    local super_createItemList = buildUI.createItemList

    buildUI.createItemList = function()
        super_createItemList()

        for i, value in ipairs(ddapiManager.constructableIndexes) do
            table.insert(buildUI.itemList, value)
        end
    end
end

return mod