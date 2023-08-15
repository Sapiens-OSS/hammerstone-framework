local handlerManager = {
    
}

-- Hammerstone
local utils = mjrequire "hammerstone/ddapi/utils"

-- Loads and initalises a handler
--@param handler The handler object to load and initalise
function handlerManager:registerHandler(handler)
    -- Fill out empty objects in handler
    handler.queue = {}

    -- Fill out default transformers
    handler.transformers = utils.assertTable(handler.transformers, {
        json = function (self, data) 
            return data
        end,
    
        lua = function(self, data)
            return data
        end
    })

    -- Fill out default/empty hooks
    -- handler.
end

return handlerManager