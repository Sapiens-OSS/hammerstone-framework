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
            "actionSequence", 
            "plan"
        },
        dependencies = {
            "actionSequence", 
            "plan"
        },
        loadFunction = behaviorManager.generateOrder
    }
    
    behaviorManager.loaders.actionLogic = {
        waitingForStart = true,
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
        loadFunction = behaviorManager.generateActionLogic
    }

    behaviorManager.loaders.actionSequence = {
        rootComponent = "hs_action_sequence",
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
    
    behaviorManager.loaders.action = {
        disabled = true,
        rootComponent = "hs_action",
        moduleDependencies = {
            "action"		
        }, 
        loadFunction = behaviorManager.generateAction
    }
    
    behaviorManager.loaders.actionModifier = {
        disabled = true,
        rootComponent = "hs_action_modifier",
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
        inProgress = description:getStringOrNil("in_progress"):asLocalizedString(utils:getInProgressKey("plan", identifier)),
        icon = description:getStringValue("icon"),

        priorityOffset = rootComponent:get("priority"):with(
            function(value)
                if type(value) == "string" then
                    return modules.plan[value]
                elseif type(value) == "number" then
                    return value
                else
                    ddapiManager:raiseError("  ERROR: priority must be a string or a number")
                end
            end
        ):getValue(),
        checkCanCompleteForRadialUI = rootComponent:getBooleanOrNil("shows_on_wheel"):default(true):getValue(), 
        allowsDespiteStatusEffectSleepRequirements = rootComponent:getBooleanValueOrNil("skip_sleep_requirement"),  
        shouldRunWherePossible = rootComponent:getStringOrNil("walk_speed"):with(function(value) return value == "run" end):getValue(), 
        shouldJogWherePossible = rootComponent:getStringOrNil("walk_speed"):with(function(value) return value == "job" end):getValue(), 
        skipFinalReachableCollisionPathCheck = rootComponent:getStringOrNil("collision_path_check"):with(function(value) return value == "skip" end):getValue(), 
        skipFinalReachableCollisionAndVerticalityPathCheck = rootComponent:getStringOrNil("collision_path_check"):with(function(value) return value == "skip_vertical" end):getValue(),
        allowOtherPlanTypesToBeAssignedSimultaneously = rootComponent:getTableOrNil("simultaneous_plans"):with(
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

    modules["typeMaps"]:insert("plan", modules["plan"].types, newPlan)

    if rootComponent:hasKey("add_plan_function") then
        local addPlanFunction = rootComponent:get("add_plan_function"):ofType("function"):getValue()
        ddapiManager.addPlansFunctions[newPlan.index] = addPlanFunction
    end
end

---------------------------------------
-- Plan Helper
---------------------------------------
do
    local function defaultGetCountFunction(vertOrObjectInfos, context, queuedPlanInfos)
        if queuedPlanInfos and next(queuedPlanInfos) then
            return 0 
        else
            return #vertOrObjectInfos
        end
    end

    local function getSettingsBase(objDef, description, components, identifier, rootComponent)
        -- requiredToolTypeIndex is special. It can be the real index or a function
        local requiredTool = rootComponent:getOrNil("tool")

        local requiredToolTypeIndex = 
            switch(type(requiredTool:getValue())) : caseof {
                ["string"] = function() return requiredTool:asTypeIndex(modules["tool"].types) end, 
                ["function"] = function() return requiredTool:getValue() end, 
                ["nil"] = function() return nil end, 
                default = 
                    function() 
                        ddapiManager:raiseError("  ERROR: The required tool for planHelper must be a string or a function")
                    end
            }


        local discovery = nil
        local research = nil

        if rootComponent:hasKey("discovery") then
            local discoveryComponent = rootComponent:getTable("discovery")

            discovery = {
                checkForDiscovery = discoveryComponent:getBooleanOrNil("do_check"):default(true):getValue(), 
                discoveryCondition = discoveryComponent:getOrNil("condition"):ofTypeOrNil("function"):getValue()
            }
        end

        if rootComponent:hasKey("research") then
            local researchComponent = rootComponent:getTable("research")

            research = {
                researchTypeIndex = researchComponent:getStringOrNil("type"):asTypeIndex(modules["research"].types),
                addMissingResearchInfo = researchComponent:getBooleanOrNil("add_missing_research_info"):default(true):getValue(), 
                canAddResearchPlanFunction = researchComponent:getOrNil("can_research"):ofTypeOrNil("function"):getValue(), 
            }
        end

        return hmt {
            planTypeIndex = description:getStringOrNil("plan"):default(identifier):asTypeIndex(modules["plan"].types), 
            requiredToolTypeIndex = requiredToolTypeIndex,
            requiredSkillIndex = rootComponent:getString("skill"):asTypeIndex(modules["skill"].types), 
            getCountFunction = rootComponent:getOrNil("get_count"):ofTypeOrNil("function"):default(defaultGetCountFunction):getValue(), 
            initFunction = rootComponent:getOrNil("init"):ofTypeOrNil("function"):getValue(), 
            extraInfoFunction = rootComponent:getOrNil("add_extra_info"):ofTypeOrNil("function"):getValue()
        }:mergeWith(discovery):mergeWith(research):clear()
    end

    local function planHelper_ForTerrain(objDef, description, components, identifier, rootComponent)
        local terrainPlanSettings = getSettingsBase(objDef, description, components, identifier, rootComponent)
        terrainPlanSettings.affectedPlanIndexes = rootComponent:getTable("affected_plans"):asTypeIndex(modules["plan"].types)

        modules["planHelper"]:addTerrainPlan(terrainPlanSettings)
    end

    local function planHelper_ForObjects(objDef, description, components, identifier, rootComponent)
        local gameObjectModule = modules.gameObject

        local objectGroups = rootComponent:getTableOrNil("object_groups")
        local objectTypeIndexes = rootComponent:getTableOrNil("objects"):asTypeIndex(gameObjectModule.types, "Game Object")

        if not objectGroups and not objectTypeIndexes then
            ddapiManager:raiseError("  ERROR: You must set either or both \"object_groups\" and \"objects\" for plan availability")
        end

        local objectPlanSettings = getSettingsBase(objDef, description, components, identifier, rootComponent)
        objectPlanSettings.addObjectTypeIndex = rootComponent:getBooleanValueOrNil("add_object_index")

        for _, objectTypeIndex in ipairs(objectTypeIndexes or {}) do 
            modules.planHelper:addObjectPlan(objectTypeIndex, objectPlanSettings)
        end

        for _, objectGroup in ipairs(objectGroups or {}) do 
            if not gameObjectModule[objectGroup] then
                ddapiManager:raiseError("  ERROR: Invalid object group: ", objectGroup)
            end

            for _, objectTypeIndex in ipairs(gameObjectModule[objectGroup]) do 
                modules.planHelper:addObjectPlan(objectTypeIndex, objectPlanSettings)
            end
        end
    end

    function behaviorManager:generatePlanHelperBehavior(objDef, description, components, identifier, rootComponent)

        local targetType = rootComponent:getStringValue("target_type")

        switch(targetType) : caseof {
            terrain = function() planHelper_ForTerrain(objDef, description, components, identifier, rootComponent) end, 

            objects = function() planHelper_ForObjects(objDef, description, components, identifier, rootComponent) end, 

            default = function()
                ddapiManager:raiseError("  ERROR: unknown target_type")
            end
        }
    end
end
---------------------------------------
-- Order
---------------------------------------
function behaviorManager:generateOrder(objDef, description, components, identifier, rootComponent)

    local newOrder = {
        key = identifier, 
        name = description:getStringOrNil("name"):asLocalizedString(utils:getNameKey("order", identifier)), 
        inProgressName = description:getStringOrNil("in_progress"):asLocalizedString(utils:getInProgressKey("order", identifier)),  
        icon = description:getStringValue("icon"), 
        disallowsLimitedAbilitySapiens = rootComponent:getBooleanValueOrNil("limiting"), 
        autoExtend = rootComponent:getBooleanOrNil("auto_extend"):default(true):getValue()
    }

    if rootComponent:hasKey("props") then
        newOrder = rootComponent:getTable("props"):mergeWith(newOrder):clear()
    end

    modules["typeMaps"]:insert("order", modules["order"].types, newOrder)	
    
    local actionSequenceLink = rootComponent:getOrNil("action_sequence"):default(identifier):with(
        function(value)
            if type(value) == "function" then
                return value
            elseif type(value) == "string" then
                return hmt(value):asTypeIndex(modules.actionSequence.types, "Action Sequence")
            else
                ddapiManager:raiseError("  ERROR: action_sequence must be a string or a function")
            end
        end
    ):getValue()

    ddapiManager.orderActionSequenceLinks[newOrder.index] = actionSequenceLink

    local planLinkComponent = rootComponent:getTable("plan_link")

    local planTypeIndex = planLinkComponent:getStringOrNil("plan"):default(identifier):asTypeIndex(modules.plan.types)

    local createOrderInfo = nil

    if planLinkComponent:hasKey("create_function") then
        createOrderInfo = {
            createFunction = planLinkComponent:get("create_function"):ofType("function"):getValue()
        }
    else
        createOrderInfo = {
            orderTypeIndex = newOrder.index,
            requiresFullAbility = newOrder.disallowsLimitedAbilitySapiens, 
            repeatCount = planLinkComponent:getNumberValue("repeat_count")
        }
    end    

    -- TODO: Check overwrite?
    ddapiManager.createOrderInfos[planTypeIndex] = createOrderInfo
end

---------------------------------------
-- Action Logic (activeOrderAI)
---------------------------------------
function behaviorManager:generateActionLogic(objDef)

    if not objDef:getTable("components"):hasKey("hs_action_logic") then return end

    local rootComponent = objDef:getTable("components"):get("hs_action_logic")

    local updateInfos = nil
    if rootComponent:isType("function") then
        updateInfos = rootComponent:getValue()(modules.activeOrderAI)
    else
        local description = objDef:getTable("description")
        local identifier = description:getStringValue("identifier")
        
        updateInfos = {
            actionTypeIndex = rootComponent:getStringOrNil("action"):default(identifier):asTypeIndex(modules["action"].types, "Action"),
            checkFrequency = rootComponent:getNumberValue("check_frequency"), 
            completionFunction = rootComponent:get("completion_function"):ofType("function"):getValue(), 
            defaultSkillIndex = rootComponent:getStringOrNil("default_skill"):asTypeIndex(modules["skill"].types, "Skill"),
            toolMultiplierTypeIndex = rootComponent:getStringOrNil("tool_multiplier"):asTypeIndex(modules["tool"].types, "Tool")
        }
    
        if rootComponent:hasKey("props") then
            updateInfos = rootComponent:getTable("props"):mergeWith(updateInfos):clear()
        end
    end

    modules["activeOrderAI"].updateInfos[updateInfos.actionTypeIndex] = updateInfos
end

--------------------------------------
-- Action Sequence
--------------------------------------
function behaviorManager:generateActionSequence(objDef, description, components, identifier, rootComponent)
    local newActionSequence = {
        key = identifier, 
        actions = rootComponent:getTable("actions"):asTypeIndex(modules["action"].types, "Action"),
        assignedTriggerIndex = rootComponent:getNumberValue("trigger"), 
        assignModifierTypeIndex = rootComponent:getStringOrNil("modifier"):asTypeIndex(modules["action"].modifierTypes), 
        snapToOrderObjectIndex = rootComponent:getNumberOrNil("snap"):default(2):getValue()
    }

    if rootComponent:hasKey("props") then
        newActionSequence = rootComponent:getTable("props"):mergeWith(newActionSequence):clear()
    end

    modules["typeMaps"]:insert("actionSequence", modules["actionSequence"].types, newActionSequence)
end

--------------------------------------
-- Action
--------------------------------------
-- disabled until we have animations
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
-- Action Modifier
--------------------------------------
-- disabled until we have animations
function behaviorManager:generateActionModifier(objDef, description, components, identifier, rootComponent)

    local newActionModifier = {
        key = identifier, 
        name = description:get("name"):asLocalizedString(utils:getNameKey("action", identifier)), 
        inProgress = description:get("in_progress"):asLocalizedString(utils:getInProgressKey("action", identifier)), 
    }

    if rootComponent:hasKey("props") then
        newActionModifier = rootComponent:getTable("props"):mergeWith(newActionModifier):clear()
    end

    modules["typeMaps"]:insert("actionModifier", modules["action"].modifierTypes, newActionModifier)
end

return behaviorManager