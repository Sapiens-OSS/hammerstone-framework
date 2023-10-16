local function defaultTerrainAddConditionFunction(context, vertOrObjectInfos, tribeID, planHash, availablePlanCounts, queuedPlanInfos)
    return availablePlanCounts[planHash] > 0
end

planHelper.terrainPlansSettings = {
    {
        addCondition = function() return true end,
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
        addCondition = defaultTerrainAddConditionFunction,
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
        addCondition = defaultTerrainAddConditionFunction,
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
        addCondition = defaultTerrainAddConditionFunction,
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
        addCondition = defaultTerrainAddConditionFunction,
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
        addCondition = defaultTerrainAddConditionFunction,
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