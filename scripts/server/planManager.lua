--- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local planManager = {
    addPlansFunctions = {}
}

local context = nil

function planManager:postload(base)
    moduleManager:addModule("planManager", base)
end

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

        if self.addPlansFunctions[planTypeIndex] then
            self.addPlansFunctions[planTypeIndex](context, tribeID, userData)
            self:updatePlansForFollowerOrOrderCountChange(tribeID)
        else
            super(self, tribeID, userData)
        end
    end
end
