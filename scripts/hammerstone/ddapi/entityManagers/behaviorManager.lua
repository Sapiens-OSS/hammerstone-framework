-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local modules = moduleManager.modules

local behaviorManager = {
    settings = {
        configPath = "/hammerstone/behavior", 
        configFiles = {},
    }, 
    loaders = {}
}

local ddapiManager = nil

function behaviorManager:init(ddapiManager_)
    ddapiManager = ddapiManager_

    behaviorManager.loaders.plan = { 
        rootComponent = "hs_plan",
        moduleDependencies = {
            "plan"
        }, 
        loadFunction = behaviorManager.generatePlan
    }
    
    behaviorManager.loaders.planHelper_behavior = {
        rootComponent = "hs_plan_availability",
        waitingForStart = true, -- Custom start triggered from planHelper.lua
        moduleDependencies = {
            "planHelper", 
            "plan", 
            "tool", 
            "skill", 
            "research", 
            "gameObject"
        }, 
        dependencies = {
            "plan", 
            "skill", 
            "research", 
            "gameObject"
        }, 
        loadFunction = behaviorManager.generatePlanHelperBehavior
    }
    
    behaviorManager.loaders.order = {
        rootComponent = "hs_order",
        moduleDependencies = {
            "order",
        },
        loadFunction = behaviorManager.generateOrder
    }
    
    behaviorManager.loaders.activeOrder = {
        rootComponent = "hs_activeOrder",
        moduleDependencies = {
            "action", 
            "tool",
            "skill", 
            "activeOrderAI"
        }, 
        dependencies = {
            "action", 
            "skill"
        }, 
        loadFunction = behaviorManager.generateActiveOrder
    }
    
    behaviorManager.loaders.action = {
        rootComponent = "hs_action",
        moduleDependencies = {
            "action"		
        }, 
        loadFunction = behaviorManager.generateAction
    }
    
    behaviorManager.loaders.actionSequence = {
        rootComponent = "hs_actionSequence",
        moduleDependencies = {
            "actionSequence", 
            "action"
        },
        dependencies = {
            "action", 
            "actionModifier"
        }, 
        loadFunction = behaviorManager.generateActionSequence
    }
    
    behaviorManager.loaders.actionModifier = {
        rootComponent = "hs_actionModifierType",
        moduleDependencies = {
            "action", 
        }, 
        loadFunction = behaviorManager.generateActionModifier
    }
end

---------------------------------------
-- Plan
---------------------------------------
function behaviorManager:generatePlan(objDef, description, components, identifier, rootComponent)

    local newPlan = {
        key = identifier,
        name = description:getStringOrNil("name"):asLocalizedString(utils:getNameKey("plan", identifier)),
        inProgress = description:getStringOrNil("inProgress"):asLocalizedString(utils:getInProgressKey("plan", identifier)),
        icon = description:getStringValue("icon"),

        checkCanCompleteForRadialUI = rootComponent:getBooleanOrNil("showsOnWheel"):default(true):getValue(), 
        allowsDespiteStatusEffectSleepRequirements = rootComponent:getBooleanValueOrNil("skipSleepRequirement"),  
        shouldRunWherePossible = rootComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "run" end):getValue(), 
        shouldJogWherePossible = rootComponent:getStringOrNil("walkSpeed"):with(function(value) return value == "job" end):getValue(), 
        skipFinalReachableCollisionPathCheck = rootComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skip" end):getValue(), 
        skipFinalReachableCollisionAndVerticalityPathCheck = rootComponent:getStringOrNil("collisionPathCheck"):with(function(value) return value == "skipVertical" end):getValue(),
        allowOtherPlanTypesToBeAssignedSimultaneously = rootComponent:getTableOrNil("simultaneousPlans"):with(
            function(value)
                if value then 
                    return hmt(value):selectPairs( 
                        function(index, planKey)
                            return utils:getTypeIndex(modules["plan"].types, planKey), true
                        end
                    )
                end
            end
        ):getValue()
    }

    if type(newPlan.allowOtherPlanTypesToBeAssignedSimultaneously) == "table" then
        newPlan.allowOtherPlanTypesToBeAssignedSimultaneously:clear()
    end
        
    local defaultValues = hmt{
        requiresLight = true
    }

    newPlan = defaultValues:mergeWith(rootComponent:getTableOrNil("props"):default({})):mergeWith(newPlan):clear()

    local addPlanFunction = rootComponent:get("addPlanFunction"):ofType("function"):getValue()

    modules["typeMaps"]:insert("plan", modules["plan"].types, newPlan)
    ddapiManager.addPlansFunctions[newPlan.index] = addPlanFunction
end

---------------------------------------
-- Plan Helper
---------------------------------------
function behaviorManager:generatePlanHelperBehavior(objDef, description, components, identifier, rootComponent)

    local targetObjects = rootComponent:getTableOrNil("targets")

    if not targetObjects:isNil() then
        local availablePlansFunction = rootComponent:get("available_plans_function"):getValue()

        if type(availablePlansFunction) == "string" then
            availablePlansFunction = modules["planHelper"][availablePlansFunction]

        elseif type(availablePlansFunction) ~= "function" then
            log:schema("ddapi", "availablePlansFunction must be a string or a function")
            return
        end

        targetObjects:forEach(
            function(targetObject)
                local objectTypeIndex = targetObject:asTypeIndex(modules["gameObject"].types)
                modules["planHelper"]:setPlansForObject(objectTypeIndex, availablePlansFunction)
            end, true)
    else
        -- If it's not a plan for an object, it's for terrain

        -- requiredToolTypeIndex is special. It can be the real index or a function
        local requiredTool = rootComponent:getOrNil("tool")

        local ok, requiredToolTypeIndex = 
            switch(type(requiredTool:getValue())) : caseof {
                ["string"] = function() return true, requiredTool:asTypeIndex(modules["tool"].types) end, 
                ["function"] = function() return true, requiredTool:getValue() end, 
                ["nil"] = function() return true, nil end, 
                default = function() 
                    return false, "ERROR: The required tool for planHelper must be a string or a function"
                    end
            }
        
        if not ok then 
            log:schema("ddapi", requiredToolTypeIndex)
            return
        end
            
        local terrainPlanSettings = {
            planTypeIndex = description:getString("identifier"):asTypeIndex(modules["plan"].types), 
            requiredToolTypeIndex = requiredToolTypeIndex,
            requiredSkillIndex = rootComponent:getString("skill"):asTypeIndex(modules["skill"].types), 
            checkForDiscovery = rootComponent:getBooleanOrNil("needsDiscovery"):default(true):getValue(), 
            researchTypeIndex = rootComponent:getStringOrNil("research"):asTypeIndex(modules["research"].types),
            addMissingResearchInfo = rootComponent:getBooleanOrNil("addMissingResearchInfo"):default(true):getValue(), 
            canAddResearchPlanFunction = rootComponent:getOrNil("canResearchFunction"):ofTypeOrNil("function"):getValue(), 
            getCountFunction = rootComponent:get("getCountFunction"):ofType("function"):getValue(), 
            initFunction = rootComponent:getOrNil("initFunction"):asTypeOrNil("function"):getValue(), 
            affectedPlanIndexes = rootComponent:getTable("affectedPlans"):asTypeIndex(modules["plan"].types)
        }

        modules["planHelper"]:addTerrainPlan(terrainPlanSettings)
    end
end

---------------------------------------
-- Order
---------------------------------------
function behaviorManager:generateOrder(objDef, description, components, identifier, rootComponent)
    local newOrder = {
        key = identifier, 
        name = description:getStringOrNil("name"):asLocalizedString(utils:getNameKey("order", identifier)), 
        inProgressName = description:getStringOrNil("inProgress"):asLocalizedString(utils:getInProgressKey("order", identifier)),  
        icon = description:getStringValue("icon"), 
    }

    if rootComponent:hasKey("props") then
        newOrder = rootComponent:getTable("props"):mergeWith(newOrder):clear()
    end

    modules["typeMaps"]:insert("order", modules["order"].types, newOrder)		
end

---------------------------------------
-- Active Order (activeOrderAI)
---------------------------------------
function behaviorManager:generateActiveOrder(objDef, description, components, identifier, rootComponent)

    local updateInfos = {
        actionTypeIndex = description:getString("identifier"):asTypeIndex(modules["action"].types, "Action"),
        checkFrequency = rootComponent:getNumberValue("checkFrequency"), 
        completeFunction = rootComponent:get("completeFunction"):ofType("function"):value(), 
        defaultSkillIndex = rootComponent:getStringOrNil("defaultSkill"):asTypeIndex(modules["skill"].types, "Skill"),
        toolMultiplierTypeIndex = rootComponent:getStringOrNil("toolMultiplier"):asTypeIndex(modules["tool"].types, "Tool")
    }

    if rootComponent:hasKey("props") then
        updateInfos = rootComponent:getTable("props"):mergeWith(updateInfos):clear()
    end

    modules["activeOrderAI"].updateInfos[updateInfos.actionTypeIndex] = updateInfos
end

--------------------------------------
-- Action
--------------------------------------
function behaviorManager:generateAction(objDef, description, components, identifier, rootComponent)

    local newAction = {
        key = identifier, 
        name = description:getStringOrNil("name"):asLocalizedString(utils:getNameKey("action", identifier)), 
        inProgress = description:getStringOrNil("inProgress"):asLocalizedString(utils:getInProgressKey("action", identifier)), 
        restNeedModifier = rootComponent:getNumberValue("restNeedModifier"), 
    }

    if rootComponent:hasKey("props") then
        newAction = rootComponent:getTable("props"):mergeWith(newAction):clear()
    end

    modules["typeMaps"]:insert("action", modules["action"].types, newAction)
end

--------------------------------------
-- Action Sequence
--------------------------------------
function behaviorManager:generateActionSequence(objDef, description, components, identifier, rootComponent)
    local newActionSequence = {
        key = identifier, 
        actions = rootComponent:getTable("actions"):asTypeIndex(modules["action"].types, "Action"),
        assignedTriggerIndex = rootComponent:getNumberValue("assignedTriggerIndex"), 
        assignModifierTypeIndex = rootComponent:getStringOrNil("modifier"):asTypeIndex(modules["action"].modifierTypes)
    }

    if rootComponent:hasKey("props") then
        newActionSequence = rootComponent:getTable("props"):mergeWith(newActionSequence):clear()
    end

    modules["typeMaps"]:insert("actionSequence", modules["actionSequence"].types, newActionSequence)
end

--------------------------------------
-- Action Modifier
--------------------------------------
function behaviorManager:generateActionModifier(objDef, description, components, identifier, rootComponent)

    local newActionModifier = {
        key = identifier, 
        name = description:get("name"):asLocalizedString(utils:getNameKey("action", identifier)), 
        inProgress = description:get("inProgress"):asLocalizedString(utils:getInProgressKey("action", identifier)), 
    }

    if rootComponent:hasKey("props") then
        newActionModifier = rootComponent:getTable("props"):mergeWith(newActionModifier):clear()
    end

    modules["typeMaps"]:insert("actionModifier", modules["action"].modifierTypes, newActionModifier)
end

return behaviorManager