function getHammerstoneDirectory()
    
end

function getModDirectory(modName)
    local modManager = mjrequire "common/modManager"

    local allMods = modManager.modInfosByTypeByDirName.world
    local enabledMods = modManager.enabledModDirNamesAndVersionsByType.world

    for _, v in pairs(enabledMods) do
        -- Crosscheck both lists so we get the correct mod
        if allMods[v.name].name == modName then
            return allMods[v.name].directory
        end
    end
end

return {}