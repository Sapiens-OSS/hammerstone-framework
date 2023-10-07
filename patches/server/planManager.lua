local patch = {
    version = "0.4.2.5",
    patchOrder = 0,
    debugCopyAfter = false,
    operations = {
        [1] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updatePlansForFollowerOrOrderCountChange" }, 
        [2] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "getAndIncrementPlanID" }, 
        [3] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "setRequiredSkillForPlan" }, 
        [4] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForResourceAvailabilityChange" }, 
        [5] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForVert" }, 
        [6] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "getAndIncrementPrioritizedID" }, 
        [7] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "canCompleteIgnoringOrderLimit" }, 
        [8] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForSkillChange" }, 
        [9] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForTerrainTypeAvailibilityChange" }, 
        [10] = { type = "localFunctionToGlobal", moduleName = "planManager", functionName = "updateImpossibleStateForStorageAreaContainedObjectsPlanChange" }, 
        [11] = { type = "replace", pattern = "updateImpossibleStateForStorageAvailibilityChange", repl = "updateImpossibleStateForStorageAvailibilityChangeInternal" },
        [12] = { type = "insertAfter", startAt = { "local function updateImpossibleStateForStorageAvailibilityChangeInternal", "\r\nend\r\n" }, repl = { chunk = "planManager_updateImpossibleStateForStorageAvailibilityChange" } }, 
        [13] = { type = "replace", pattern = "updateImpossibleStateForCraftAreaAvailibilityChange", repl = "updateImpossibleStateForCraftAreaAvailibilityChangeInternal" }, 
        [14] = { type = "insertAfter", startAt = { "local function updateImpossibleStateForCraftAreaAvailibilityChangeInternal", "\r\nend\r\n" }, repl = { chunk = "planManager_updateImpossibleStateForCraftAreaAvailibilityChange" } }, 
    }
}

return patch