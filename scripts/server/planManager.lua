--- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local objectManager = mjrequire "hammerstone/ddapi/objectManager"

local planManager = {
}

local context = nil

function planManager:init(super, serverGOM_, serverWorld_, serverSapien_, serverCraftArea_)
    super(self, serverGOM_, serverWorld_, serverSapien_, serverCraftArea_)

    context = {
        serverGOM = serverGOM_, 
        serverWorld = serverWorld_, 
        serverSapien = serverSapien_, 
        serverCraftArea = serverCraftArea_
    }
end

function planManager:addPlans(super, tribeID, userData)
    if userData then
        local planTypeIndex = userData.planTypeIndex 

        if objectManager.addPlansFunctions[planTypeIndex] then
            objectManager.addPlansFunctions[planTypeIndex](context, tribeID, userData)
            self:updatePlansForFollowerOrOrderCountChange(tribeID)
        else
            super(self, tribeID, userData)
        end
    end
end

return shadow:shadow(planManager, 0)