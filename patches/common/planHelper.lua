local patch = {
    version = "0.4.2.5",
    patchOrder = 0,
    debugCopyAfter = false,
    debugOnly = true,
    operations = {
        -- SIRLICH TODO
        [1] = { type = "replaceAt", startAt = "function planHelper:availablePlansForVertInfos", endAt = "\r\nend", repl = { chunk = "planHelper_getTerrainPlans" } }, 
    }
}

return patch 