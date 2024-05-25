local patch = {
    version = "0.4.2.5",
    patchOrder = 0, 
    debugCopyAfter = false,
    debugOnly = true,
    operations = {
        [1] = { type = "replaceAt", startAt = "function planHelper:availablePlansForVertInfos", endAt = "\r\nend", repl = { chunk = "planHelper_getTerrainPlans" } }, 
        [2] = { type = "localVariableToModule", variableName = "completedSkillsByTribeID" }, 
        [3] = { type = "localVariableToModule", variableName = "discoveriesByTribeID" }, 
        [4] = { type = "localVariableToModule", variableName = "craftableDiscoveriesByTribeID" }
    }
}

return patch 