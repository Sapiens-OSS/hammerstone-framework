planHelper.terrainPlanSettings = {
    {
        planTypeIndex = plan.types.clear.index,
        requiredSkillIndex = skill.types.gathering.index, 
        getCountFunction = function(vertInfos)
            local count = 0 

            for _, vertInfo in ipairs(vertInfos) do 
                local variations = vertInfo.variations
                if variations then
                    for terrainVariationTypeIndex, v in pairs(variations) do 
                        local terrainVariationType = terrainTypes.variations[terrainVariationTypeIndex]
                        if terrainVariationType.canBeCleared then
                            count = count + 1
                            break
                        end
                    end
                end
            end
            return count
        end, 
        affectedPlanIndexes = {
            plan.types.dig.index, 
            plan.types.mine.index, 
            plan.types.chiselStone.index, 
            plan.types.fill.index, 
            plan.types.fertilize.index
        }
    }, 
    {
        planTypeIndex = plan.types.fill.index,
        requiredSkillIndex = skill.types.digging.index, 
        requiredToolTypeIndex = tool.types.dig.index, 
        allowsObjectTypeSelection = true,
        checkForDiscovery = true, 
        researchTypeIndex = nil, --dig will take care of it
        canAddResearchPlanFunction = nil, 
        getCountFunction = function(vertInfos) return #vertInfos end, 
        affectedPlanIndexes = {
            plan.types.clear.index, 
            plan.types.dig.index, 
            plan.types.mine.index, 
            plan.types.chiselStone.index, 
            plan.types.fertilize.index
        }
    },
    {
        planTypeIndex = plan.types.dig.index,
        requiredSkillIndex = skill.types.digging.index, 
        requiredToolTypeIndex = tool.types.dig.index, 
        checkForDiscovery = true, 
        researchTypeIndex = research.types.digging.index,
        addMissingResearchInfo = true,
        canAddResearchPlanFunction = nil, 
        getCountFunction = function(vertInfos)
            local count = 0 
            for _, vertInfo in ipairs(vertInfos) do 
                local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
                if not terrainBaseType.requiresMining then count = count + 1 end
            end
            return count
        end, 
        affectedPlanIndexes = {
            plan.types.fill.index, 
            plan.types.clear.index, 
            plan.types.fertilize.index
        }
    }, 
    {
        planTypeIndex = plan.types.mine.index,
        requiredSkillIndex = skill.types.mining.index, 
        requiredToolTypeIndex = tool.types.mine.index, 
        checkForDiscovery = true, 
        researchTypeIndex = research.types.mining.index,
        addMissingResearchInfo = true,
        canAddResearchPlanFunction = nil, 
        getCountFunction = function(vertInfos)
            local count = 0 
            for _, vertInfo in ipairs(vertInfos) do 
                local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
                if terrainBaseType.requiresMining then count = count + 1 end
            end
            return count
        end,
        affectedPlanIndexes = {
            plan.types.fill.index, 
            plan.types.clear.index, 
            plan.types.fertilize.index, 
            plan.types.chiselStone.index
        }
    }, 
    {
        planTypeIndex = plan.types.chiselStone.index,
        initFunction = function(vertInfos)
            local softChiselableVertexCount = 0
            local hardChiselableVertexCount = 0

            for _, vertInfo in ipairs(vertInfos) do 
                local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]

                if terrainBaseType.chiselOutputs then
                    if terrainBaseType.isSoftRock then
                        softChiselableVertexCount = softChiselableVertexCount + 1
                    else
                        hardChiselableVertexCount = hardChiselableVertexCount + 1
                    end
                end
            end

            return { softChiselableVertexCount = softChiselableVertexCount, hardChiselableVertexCount = hardChiselableVertexCount }
        end, 
        requiredSkillIndex = skill.types.chiselStone.index, 
        requiredToolTypeIndex = function(vertInfos, context)
            return context.softChiselableVertexCount > 0 and tool.types.softChiselling.index or tool.types.hardChiselling.index
        end, 
        checkForDiscovery = true, 
        researchTypeIndex = research.types.chiselStone.index,
        addMissingResearchInfo = true,
        canAddResearchPlanFunction = function(context, queuedPlanInfos)
            if context.softChiselableVertexCount + context.hardChiselableVertexCount > 0 then
                return context.softChiselableVertexCount > 0 and hasDiscoveredSkill(tribeID, skill.types.rockKnapping.index) or hasDiscoveredSkill(tribeID, skill.types.blacksmithing.index)
            end
        end, 
        getCountFunction = function(vertInfos, context) return context.softChiselableVertexCount + context.hardChiselableVertexCount end,
        affectedPlanIndexes = {
            plan.types.clear.index, 
            plan.types.mine.index, 
            plan.types.fill.index, 
            plan.types.fertilize.index
        }
    }, 
    {
        planTypeIndex = plan.types.fertilize.index,
        requiredSkillIndex = skill.types.mulching.index, 
        requiredToolTypeIndex = nil, --weird but okay...
        checkForDiscovery = true, 
        researchTypeIndex = research.types.mulching.index, 
        canAddResearchPlanFunction = function(context, queuedPlanInfos, researchPlanInfo, researchPlanHash)
            if queuedPlanInfos then
                return queuedPlanInfos[researchPlanHash] and queuedPlanInfos[researchPlanHash].count > 0
            end
        end, 
        getCountFunction = function(vertInfos)
            local count = 0 
            for _, vertInfo in ipairs(vertInfos) do 
                local terrainBaseType = terrainTypes.baseTypes[vertInfo.baseType]
                if terrainBaseType.fertilizedTerrainTypeKey then
                    count = count + 1
                end
            end
            return count
        end, 
        affectedPlanIndexes = {
            plan.types.fill.index, 
            plan.types.clear.index, 
            plan.types.dig.index, 
            plan.types.mine.index
        }
    }
}

function planHelper:availablePlansForVertInfos(vertInfos, tribeID)
    if vertInfos and vertInfos[1] then
        
        local queuedPlanInfos = planHelper:getQueuedPlanInfos(vertInfos, tribeID, true)
        local planCache = {}
        local availablePlanCounts = {}
        local plans = {}

        local function addUnavailableReason(vertexCount, availablePlanCount, planInfo)
            if vertexCount > 0 and availablePlanCount == 0 then
                planInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
            end
        end

        for _, settings in ipairs(planHelper.terrainPlanSettings) do 
            local planTypeIndex = settings.planTypeIndex
            local context = settings.initFunction and settings.initFunction(vertInfos, tribeID) or nil 
            local hasDiscovery = true 

            if settings.checkForDiscovery then 
                hasDiscovery = completedSkillsByTribeID[tribeID] and completedSkillsByTribeID[tribeID][settings.requiredSkillIndex]
            end

            local planInfo = {
                planTypeIndex = planTypeIndex, 
                allowsObjectTypeSelection = settings.allowsObjectTypeSelection,
                requirements = {
                    skill = settings.requiredSkillIndex, 
                    toolTypeIndex = type(settings.requiredToolTypeIndex) == "function" and settings.requiredToolTypeIndex(vertInfos, context) or settings.requiredToolTypeIndex
                }
            }

            local applicableVertexCount = settings.getCountFunction(vertInfos, context)

            local planHash = planHelper:getPlanHash(planInfo)
            planCache[planTypeIndex] = { planInfo = planInfo, vertexCount = applicableVertexCount, planHash = planHash}
            availablePlanCounts[planHash] = applicableVertexCount

            if applicableVertexCount > 0 or not settings.checkForDiscovery then

                if hasDiscovery then
                    table.insert(plans, planInfo)
                    
                elseif settings.researchTypeIndex then
                    local researchPlanInfo = {
                        planTypeIndex = plan.types.research.index, 
                        researchTypeIndex = settings.researchTypeIndex
                    }
                    local researchPlanHash = planHelper:getPlanHash(researchPlanInfo)
                    local canAddResearchPlan = true

                    if settings.canAddResearchPlanFunction then canAddResearchPlan = settings.canAddResearchPlanFunction(context, queuedPlanInfos, researchPlanInfo, researchPlanHash) end

                    if canAddResearchPlan then
                        if settings.addMissingResearchInfo then
                            planHelper:updateForAnyMissingOrInProgressDiscoveries(researchPlanInfo, tribeID, availablePlanCounts, vertInfos, queuedPlanInfos, availablePlanCounts[planHash])
                        end

                        if queuedPlanInfos and next(queuedPlanInfos) then
                            availablePlanCounts[researchPlanHash] = 0   
                            researchPlanInfo.unavailableReasonText = locale:get("ui_plan_unavailable_stopOrders")
                        end

                        planHelper:addPlanExtraInfo(researchPlanInfo, queuedPlanInfos, availablePlanCounts)
                        table.insert(plans, researchPlanInfo)
                    end
                end
            end
        end

        for _, settings in ipairs(planHelper.terrainPlanSettings) do 
            local thisPlanHash = planCache[settings.planTypeIndex].planHash

            for _, affectedPlanIndex in ipairs(settings.affectedPlanIndexes) do 
                local otherPlanHash = planCache[affectedPlanIndex].planHash
                if availablePlanCounts[otherPlanHash] and queuedPlanInfos[thisPlanHash] then
                    availablePlanCounts[otherPlanHash] = availablePlanCounts[otherPlanHash] - queuedPlanInfos[thisPlanHash].count
                end
            end
        end

        for planTypeIndex, cache in pairs(planCache) do 
            planHelper:addPlanExtraInfo(cache.planInfo, queuedPlanInfos, availablePlanCounts)
            addUnavailableReason(cache.vertexCount, availablePlanCounts[cache.planHash], cache.planInfo)
        end
        
        return plans
    end
end