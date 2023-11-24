--- Hammerstone: ai.lua
--- @author Witchy

--- Sapiens
local order = mjrequire "common/order"
local sapienConstants = mjrequire "common/sapienConstants"

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local serverSapienAI = {}

function serverSapienAI:createOrderInfo(super, sapien, orderObject, orderAssignInfo)
    local planTypeIndex = orderAssignInfo.planTypeIndex
    local createOrderInfo = ddapiManager.createOrderInfos[planTypeIndex]

    if createOrderInfo then
        local orderInfo = nil
        if createOrderInfo.createFunction then
            orderInfo = createOrderInfo.createFunction(self, sapien, orderObject, orderAssignInfo)
        else
            orderInfo = self:createGeneralOrder(sapien, orderAssignInfo, createOrderInfo.requiresFullAbility, createOrderInfo.orderTypeIndex, {
                completionRepeatCount = createOrderInfo.repeatCount,
            })
        end

        if orderInfo and orderInfo.orderTypeIndex then
            if order.types[orderInfo.orderTypeIndex].disallowsLimitedAbilitySapiens then
                if sapienConstants:getHasLimitedGeneralAbility(sapien.sharedState) then
                    return nil
                end
            end
        end
        
        if orderInfo and orderAssignInfo.planState.researchTypeIndex then
            if not orderInfo.orderContext then 
                orderInfo.orderContext = {}
            end
            orderInfo.orderContext.researchTypeIndex = orderAssignInfo.planState.researchTypeIndex
            orderInfo.orderContext.discoveryCraftableTypeIndex = orderAssignInfo.planState.discoveryCraftableTypeIndex
        end

        return orderInfo
    else
        return super(self, sapien, orderObject, orderAssignInfo)
    end
end

return shadow:shadow(serverSapienAI)