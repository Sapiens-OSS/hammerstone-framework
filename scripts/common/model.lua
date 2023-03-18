--- Hammerstone: model.lua
--- @author SirLich

-- Hammerstone: 
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local mod = {
    loadOrder = 1,
}

function mod:onload(model)
    moduleManager:addModule("model", model)

    local super_loadRemaps = model.loadRemaps
    model.loadRemaps = function(model_)
        mj:log("aaa START loadRemaps")
		objectManager:markObjectAsReadyToLoad("customModel")
        super_loadRemaps(model_)
        mj:log("aaa FINISH loadRemaps")
    end

end

return mod