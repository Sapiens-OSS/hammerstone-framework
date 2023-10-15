local patch = {
    version = "0.4.2.5",
    patchOrder = 0,
    debugCopyAfter = true,
    operations = {
        [1] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updatePlansForFollowerOrOrderCountChange" }, 
        [2] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "getAndIncrementPlanID" }, 
        [3] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "setRequiredSkillForPlan" }, 
        [4] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForVert" }, 
        [5] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "getAndIncrementPrioritizedID" }, 
        [6] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "canCompleteIgnoringOrderLimit" }, 
        [7] = { type = "insertAfter", after = { "local function updateImpossibleStateForResourceAvailabilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForResourceAvailabilityChange" } }, 
        [8] = { type = "insertAfter", after = { "local function updateImpossibleStateForSkillChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForSkillChange" } }, 
        [9] = { type = "insertAfter", after = { "local function updateImpossibleStateForStorageAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForStorageAvailibilityChange" } }, 
        [10] = { type = "insertAfter", after = { "local function updateImpossibleStateForCraftAreaAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForCraftAreaAvailibilityChange" } }, 
        [11] = { type = "insertAfter", after = { "local function updateImpossibleStateForTerrainTypeAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForTerrainTypeAvailibilityChange" } },  
        [12] = { type = "insertAfter", after = { "local function updateImpossibleStateForStorageAreaContainedObjectsPlanChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForStorageAreaContainedObjectsPlanChange" } },
    }
}

return patch