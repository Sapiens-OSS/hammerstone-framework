--- Hammerstone: model.lua
--- @author SirLich

-- Hammerstone: 
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local mod = {
    loadOrder = 1,
}

local function doesModelExist(model, modelName)
    return model.modelIndexesByName[modelName]
end

function mod:onload(model)
    moduleManager:addModule("model", model)

    local super_loadRemaps = model.loadRemaps
    model.loadRemaps = function(model_)
		ddapiManager:markObjectAsReadyToLoad("customModel")
        super_loadRemaps(model_)
    end

    model.doesModelExist  = doesModelExist

end

return mod