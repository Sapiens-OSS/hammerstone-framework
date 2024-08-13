local patch = {
    version = "0.4.2.5",
    patchOrder = 0,
    debugCopyAfter = true,
    operations = {
        [1] = { type = "insertAfter", after = { "local function updateImpossibleStateForResourceAvailabilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForResourceAvailabilityChange" } }, 
        [2] = { type = "insertAfter", after = { "local function updateImpossibleStateForSkillChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForSkillChange" } }, 
        [3] = { type = "insertAfter", after = { "local function updateImpossibleStateForStorageAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForStorageAvailibilityChange" } }, 
        [4] = { type = "insertAfter", after = { "local function updateImpossibleStateForCraftAreaAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForCraftAreaAvailibilityChange" } }, 
        [5] = { type = "insertAfter", after = { "local function updateImpossibleStateForTerrainTypeAvailibilityChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForTerrainTypeAvailibilityChange" } },  
        [6] = { type = "insertAfter", after = { "local function updateImpossibleStateForStorageAreaContainedObjectsPlanChange", "\r\n" }, string = { chunk = "planManager_updateImpossibleStateForStorageAreaContainedObjectsPlanChange" } },
    }
}

return patch