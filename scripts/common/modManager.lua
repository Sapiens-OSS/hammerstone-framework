--- Hammerstone: modManager.lua
--- @author Witchy

--- Hammerstone
local logging = mjrequire "hammerstone/logging"
local patcher = mjrequire "hammerstone/utils/patcher"

local mod = {
	loadOrder = 0
}

-- a list of already patched modules
local patchedModules = {}

-- a list of patch files per path
local orderedPatchInfos = {}

-- path for the hammerstone mod
local hammerstonePath = nil

-- Recursively finds all "lua" scripts within patch mods
local function recursivelyFindScripts(patchDirPath, requirePath, localPath, modPath, patchFilesPerPath)
    local patchDirContents = fileUtils.getDirectoryContents(patchDirPath)

    for i, subFileOrDir in ipairs(patchDirContents) do
        local extension = fileUtils.fileExtensionFromPath(subFileOrDir)
        if extension and extension == ".lua" then
            local moduleName = fileUtils.removeExtensionForPath(subFileOrDir)
            if requirePath then
                moduleName = requirePath .. "/" .. moduleName
            end
            if not patchFilesPerPath[moduleName] then
                patchFilesPerPath[moduleName] = {}
            end
            table.insert(patchFilesPerPath[moduleName],{
                path = patchDirPath .. "/" .. subFileOrDir,
                modPath = modPath
            })
        else
            local subDirName = subFileOrDir
            if requirePath then
                subDirName = requirePath .. "/" .. subDirName
            end
            recursivelyFindScripts(patchDirPath .. "/" .. subFileOrDir, subDirName, localPath .. "/" .. subFileOrDir, modPath, patchFilesPerPath)
        end
    end
end

-- applies a patch to the file requested in 'path'
local function applyPatch(path)

    local scriptsFolder = fileUtils.getResourcePath("scripts")
    local originalFilePath = scriptsFolder .. "/" .. path .. ".lua"

    if not fileUtils.fileExistsAtPath(originalFilePath) then
        -- checks that we are patching a real 'vanilla' file found in the game's "scripts" folder
        logging:error("No file to patch found at ", originalFilePath, "\n This file may have been deleted by the dev or you are attempting to patch a mod, which is not allowed.")
    end

    -- load the vanilla file content
	local fileContent = fileUtils.getFileContents(originalFilePath)
    if not fileContent then
        logging:error("Failed to load original sapiens file at ", path)
        return nil
    end

    local patchedModule = nil 
    local newFileContent = fileContent

    logging:log("Applying patches for ", path)  

    for _, patchInfos in ipairs(orderedPatchInfos[path]) do
        logging:log("Applying patch mod for version:", patchInfos.version, " with filepath:", patchInfos.filePath)

        local fileFullPathWithoutExtension = fileUtils.removeExtensionForPath(patchInfos.filePath)

        -- if the patch mod requests it, save a "before" copy of the file for debug purposes
        if patchInfos.debugCopyBefore then
            fileUtils.writeToFile(fileFullPathWithoutExtension .. "_before.lua.temp", newFileContent)
        end

        -- call the patch module's "applyPatch" function and get the new fileContent
        local success = nil 
            
        newFileContent, success = patcher:applyPatch(patchInfos, newFileContent)

        if not newFileContent then
            logging:error("Patching resulted in an empty file")
        else
            -- if the patch mod requests it, save an "after" copy of the file for debug purposes
            if patchInfos.debugCopyAfter then
                fileUtils.writeToFile(fileFullPathWithoutExtension .. "_after.lua.temp", newFileContent)
            end

            if not success then
                logging:error("Patching did not succeed for patch at ", patchInfos.path)

            elseif not patchInfos.debugOnly then
                -- test that the new fileContent is valid
                local errorMsg = nil 
                local newPatchedModule = nil 

                newPatchedModule, errorMsg = loadstring(newFileContent, path .. "(patched)")

                if not newPatchedModule then
                    logging:error(errorMsg)
                    logging:error("Patch failed for patch file at ", patchInfos.path)
                else
                    logging:log("Patching successful")
                    fileContent = newFileContent
                    patchedModule = newPatchedModule
                end
            end
        end
    end

    -- Save a final copy into hammerstone's "patched" folder
    -- This is to help modders see the changes to the files
    if patchedModule then
        local patchedDir = hammerstonePath .. "/patched/" .. path
        local patchedFilename = patchedDir .. ".lua"
        fileUtils.createDirectoriesIfNeededForDirPath(patchedDir)
        fileUtils.writeToFile(patchedFilename, fileContent)

        logging:log("Saved final patched copy at ", patchedFilename)
    end

    patchedModules[path] = patchedModule

    return patchedModule
end

function mod:onload(modManager)
    -- package.loaders contains a list of functions that "require" uses to load librairies
    -- lua provides 4 default functions to search for librairies
    -- the first is a list of custom loaders per moduleName so we don't want to superced that
    -- the second function searches for a file [moduleName].lua so we add our loader before that one
	if #package.loaders == 4 then
        table.insert(package.loaders, 2, function(path)
            -- if we already found and patched the file before, return it
            if patchedModules[path] then
                return patchedModules[path]
            
            -- if mods provide a file with the same path, attempt to patch it
            elseif orderedPatchInfos[path] then
                return applyPatch(path)
            end
        end)
    end

    -- modManager provides a list of enabled mods per type (app or world)
    -- we go through that list to find all of the lua files of the mods in their "patches" folder
    local patchFilesPerPath = {}
	for _, modsByType in pairs(modManager.enabledModDirNamesAndVersionsByType) do
        for index, mod in ipairs(modsByType) do 
            local patchesPath = mod.path .. "/patches"
            if fileUtils.isDirectoryAtPath(patchesPath) then
                recursivelyFindScripts(patchesPath, nil, "scripts", mod.path, patchFilesPerPath)
            end

            if mod.name == "hammerstone-framework" then
                hammerstonePath = mod.path
            end
        end
	end

    -- load all patch files found in mods and ensures they are valid
    for path, patchFiles in pairs(patchFilesPerPath) do
        orderedPatchInfos[path] = {}

        for _, patchFile in pairs(patchFiles) do

            local patchFilePath = patchFile.path
            local modPath = patchFile.modPath

            logging:log("Loading patch mod at ", patchFilePath)

            local patchFileContent = fileUtils.getFileContents(patchFilePath)
            local module, errorMsg = loadstring(patchFileContent, "patched " .. path)

            if not module then
                logging:error("Failed to load patch mod at path:", patchFilePath, "errorMsg: ", errorMsg)                
            else
                local function errorhandler(err)
                    logging:error("Patch error:", patchFilePath, "\n", err)
                end

                local ok, patchInfos = xpcall(module, errorhandler)

                if not patchInfos then
                    logging:error("Patch load failed:", patchFilePath, "\nPlease make sure that you are returning the mod object at the end of this file")
                elseif not ok then
                    logging:error("Patch load failed:", patchFilePath)
                elseif not patchInfos.operations then
                    logging:error("Patch does not provide operations")
                else
                    patchInfos.patchOrder = patchInfos.patchOrder or 1
                    patchInfos.filePath = patchFilePath
                    patchInfos.modDirPath = modPath
                    table.insert(orderedPatchInfos[path], patchInfos)
                end
            end
        end

        -- sort all of the patch modules by their "patchOrder"
        table.sort(orderedPatchInfos[path], function(a,b) return a.patchOrder < b.patchOrder end)
    end
end

return mod