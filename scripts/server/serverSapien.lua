--- Hammerstone: serverSapien.lua
--- @author Witchy

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local serverSapien = {}

function serverSapien:init(super, serverGOM_, serverWorld_, serverTribe_, serverDestination_, serverStorageArea_)
    self.context = {
        serverGOM = serverGOM_, 
        serverWorld = serverWorld_, 
        serverTribe = serverTribe_, 
        serverDestination = serverDestination_,
        serverStorageArea = serverStorageArea_
    }

    super(self, serverGOM_, serverWorld_, serverTribe_, serverDestination_, serverStorageArea_)
end

function serverSapien:actionSequenceTypeIndexForOrder(super, sapien, orderObject, orderState)
    local orderTypeIndex = orderState.orderTypeIndex

    for orderIndex, actionSequenceLink in pairs(ddapiManager.orderActionSequenceLinks) do 
        if orderTypeIndex == orderIndex then
            if type(actionSequenceLink) == "function" then
                return actionSequenceLink(self, sapien, orderObject, orderState)
            else
                return actionSequenceLink
            end
        end
    end

    return super(self, sapien, orderObject, orderState)
end

return shadow:shadow(serverSapien)