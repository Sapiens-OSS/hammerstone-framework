--- Hammerstone: planHelper.lua

-- Sapiens
local plan = mjrequire "common/plan"
local locale = mjrequire "common/locale"

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local planHelper = {
	objectPlansSettings = {}
}

function planHelper:postload(base)
	moduleManager:addModule("planHelper", planHelper)
end

function planHelper:init(super, world_, serverWorld_)
	super(self, world_, serverWorld_)
	ddapiManager:markObjectAsReadyToLoad("planHelper_object")
	ddapiManager:markObjectAsReadyToLoad("planHelper_behavior")
end

--- Allows you to set the available plans for an object.
-- @warning If called before `planHelper:init` then it may be reversed. This is because some object types (i.e., resources) have their plans set on load.
-- @param gameObjectIndex The index of the game object to set the plan for.
-- @param availablePlans The plans to add to this object. e.g, planHelper.availablePlansForNonResourceCarcass
function planHelper:setPlansForObject(gameObjectIndex, availablePlans)
	self.availablePlansFunctionsByObjectType[gameObjectIndex] = availablePlans
end

function planHelper:addTerrainPlan(terrainPlanSettings)
	for _, affectedPlanIndex in ipairs(terrainPlanSettings.affectedPlanIndexes) do
		for i, settings in ipairs(self.terrainPlanSettings) do
			if settings.planTypeIndex == affectedPlanIndex then
				table.insert(settings.affectedPlanIndexes, terrainPlanSettings.planTypeIndex)
				break
			end 
		end 
	end

	table.insert(self.terrainPlansSettings, terrainPlanSettings)
end

-- Disabling for now. Fixing later
--[[
function planHelper:addObjectPlan(gameObjectIndex, objectPlanSettings)
	if not self.objectPlansSettings[gameObjectIndex] then
		self.objectPlansSettings[gameObjectIndex] = {}
	end

	table.insert(self.objectPlansSettings[gameObjectIndex], objectPlanSettings)
end

function planHelper:finalizePlanInfos(planCache, vertOrObjectInfos, tribeID, queuedPlanInfos, availablePlanCounts)
    local function addUnavailableReason(count, availablePlanCount, planInfo)
        if count > 0 and availablePlanCount == 0 or count == 0 then
            planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
        end
    end

    for planTypeIndex, cache in pairs(planCache) do 
        self:addPlanExtraInfo(cache.planInfo, queuedPlanInfos, availablePlanCounts)
        addUnavailableReason(cache.count, availablePlanCounts[cache.planHash], cache.planInfo)

        if cache.extraInfoFunction then
            cache.extraInfoFunction(cache.planInfo, cache.count, cache.planHash, cache.context, vertOrObjectInfos, tribeID, queuedPlanInfos, availablePlanCounts)
        end
    end
end

function planHelper:getPlanInfosFromSettings(vertOrObjectInfos, tribeID, settings, queuedPlanInfos, availablePlanCounts, planCache)
    local planTypeIndex = settings.planTypeIndex
    local context = settings.initFunction and settings.initFunction(vertOrObjectInfos, tribeID) or nil 
    local hasDiscovery = true 

    if settings.checkForDiscovery then 
        if settings.discoveryCondition then
            hasDiscovery = settings.discoveryCondition(self, context, vertOrObjectInfos, tribeID)
        else
            hasDiscovery = self.completedSkillsByTribeID[tribeID] and self.completedSkillsByTribeID[tribeID][settings.requiredSkillIndex]
        end
    end

    local planInfo = {
        planTypeIndex = planTypeIndex, 
        isDestructive = settings.isDestructive,
        allowAnyObjectType = settings.allowAnyObjectType,
        allowsObjectTypeSelection = settings.allowsObjectTypeSelection,
		objectTypeIndex = settings.setObjectTypeIndex and vertOrObjectInfos[1].objectTypeIndex,
        availableCount = settings.getAvailableCountFuntion and settings.getAvailableCountFuntion(context, vertOrObjectInfos, tribeID),
        requirements = {
            skill = settings.requiredSkillIndex, 
            toolTypeIndex = type(settings.requiredToolTypeIndex) == "function" and settings.requiredToolTypeIndex(vertOrObjectInfos, context) or settings.requiredToolTypeIndex
        }
    }

    local applicableCount = settings.getCountFunction(vertOrObjectInfos, context, queuedPlanInfos)

    local planHash = self:getPlanHash(planInfo)
    planCache[planTypeIndex] = { planInfo = planInfo, count = applicableCount, planHash = planHash, context = context, extraInfoFunction = settings.extraInfoFunction}
    availablePlanCounts[planHash] = applicableCount

    if not settings.addCondition or settings.addCondition(context, vertOrObjectInfos, tribeID, planHash, availablePlanCounts, queuedPlanInfos, self) then

        if hasDiscovery then
            return planInfo
            
        elseif settings.researchTypeIndex then
            local researchPlanInfo = {
                planTypeIndex = plan.types.research.index, 
                researchTypeIndex = settings.researchTypeIndex
            }
            local researchPlanHash = self:getPlanHash(researchPlanInfo)
            local canAddResearchPlan = true

            if settings.canAddResearchPlanFunction then canAddResearchPlan = settings.canAddResearchPlanFunction(context, queuedPlanInfos, researchPlanInfo, researchPlanHash) end

            if canAddResearchPlan then
                if settings.addMissingResearchInfo then
                    self:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, vertOrObjectInfos, queuedPlanInfos, availablePlanCounts[planHash])
                end

                if queuedPlanInfos and next(queuedPlanInfos) then
                    availablePlanCounts[researchPlanHash] = 0   
                    researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                end

                self:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                return researchPlanInfo
            end
        end
    end
end



--- Totally overrides the original function which was deleted by the patch (so no super)
function planHelper:availablePlansForVertInfos(baseObjectOrVert, vertInfos, tribeID)
    if not (vertInfos and baseObjectOrVert) then
        return nil
    end

    local queuedPlanInfos = self:getQueuedPlanInfos(vertInfos, tribeID, true)
    local planCache = {}
    local availablePlanCounts = {}
    local plans = {}

    for _, settings in ipairs(self.terrainPlansSettings) do 
        local planInfo = self:getPlanInfosFromSettings(vertInfos, tribeID, settings, queuedPlanInfos, availablePlanCounts, planCache)
        if planInfo then
            table.insert(plans, planInfo)
        end
    end

    for _, settings in ipairs(self.terrainPlansSettings) do 
        local thisPlanHash = planCache[settings.planTypeIndex].planHash

        for _, affectedPlanIndex in ipairs(settings.affectedPlanIndexes) do 
            local otherPlanHash = planCache[affectedPlanIndex].planHash
            if availablePlanCounts[otherPlanHash] and queuedPlanInfos[thisPlanHash] then
                availablePlanCounts[otherPlanHash] = availablePlanCounts[otherPlanHash] - queuedPlanInfos[thisPlanHash].count
            end
        end
    end

    self:finalizePlanInfos(planCache, vertInfos, tribeID, queuedPlanInfos, availablePlanCounts)
        
    return plans
end

function planHelper:availablePlansForObjectInfos(super, objectInfos, tribeID)
	local plans = super(self, objectInfos, tribeID) or {}

	if objectInfos and objectInfos[1] then
		local queuedPlanInfos = self:getQueuedPlanInfos(objectInfos, tribeID, false)
        local planCache = {}
        local availablePlanCounts = {}

        for _, settings in ipairs(self.objectPlansSettings[objectInfos[1].objectTypeIndex] or {}) do 
            local planInfo = self:getPlanInfosFromSettings(objectInfos, tribeID, settings, queuedPlanInfos, availablePlanCounts, planCache)

            if planInfo then
                for i = #plans, 1, -1 do 
                    if plans[i].planTypeIndex == planInfo.planTypeIndex then
                        table.remove(plans, i)                            
                    end
                end

                table.insert(plans, planInfo)
            end
        end

        self:finalizePlanInfos(planCache, objectInfos, tribeID, queuedPlanInfos, availablePlanCounts)
	end

	if not next(plans) then return nil end
	return plans
end
]]

return shadow:shadow(planHelper, 0)