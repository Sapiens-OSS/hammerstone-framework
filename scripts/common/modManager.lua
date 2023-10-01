mjrequire "hammerstone/globals" -- by loading it here, every script from now on should be able to use them

local function startDebug()
    local lldebugger = mjrequire "hammerstone/debug/lldebugger"
    lldebugger.init("Hammerstone Framework").start()
end

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
local patchInfosPerPath = {}

-- path for the hammerstone mod
local hammerstonePath = nil

-- Recursively finds all "lua" scripts within patch mods
local function recursivelyFindScripts(patchDirPath, requirePath, localPath, modPath, patchFilesPerPath)
    local patchDirContents = fileUtils.getDirectoryContents(patchDirPath)

    for i, subFileOrDir in ipairs(patchDirContents) do
        local extension = fileUtils.fileExtensionFromPath(subFileOrDir)
        if extension and extension == ".lua" then
            local moduleName = fileUtils.removeExtensionForPath(subFileOrDir)

            -- mods that apply to more than one file are placed at the root
            if patchDirPath == modPath .. "/patches" then
                if not patchFilesPerPath[""] then
                    patchFilesPerPath[""] = {}
                end

                table.insert(patchFilesPerPath[""], {
                    path = patchDirPath .. "/" .. subFileOrDir,
                    modPath = modPath
                })
            else
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
            end
        else
            local subDirName = subFileOrDir
            if requirePath then
                subDirName = requirePath .. "/" .. subDirName
            end
            recursivelyFindScripts(patchDirPath .. "/" .. subFileOrDir, subDirName, localPath .. "/" .. subFileOrDir, modPath, patchFilesPerPath)
        end
    end
end

local function getPatchInfosMatchingPath(path)
    local orderedPatchInfos = {}

    for p, patchInfosList in pairs(patchInfosPerPath) do
        local pattern = "^" .. p .. "$"
        if path:match(pattern) == path then
            for _, patchInfos in pairs(patchInfosList) do
                table.insert(orderedPatchInfos, patchInfos)
            end
        end
    end

    table.sort(orderedPatchInfos, function(a,b) return a.patchOrder < b.patchOrder end)

    return orderedPatchInfos
end

local function getDirPathFromPath(path)
    local directories = {}

    for match in path:gmatch("[^/]+") do
        table.insert(directories, match)
    end

    table.remove(directories, #directories)

    local dirPath = ""
    for _, dir in pairs(directories) do
        dirPath = dirPath .. "/" .. dir
    end

    return dirPath
end

-- applies a patch to the file requested in 'path'
local function applyPatch(path)

    local orderedPatchInfos = getPatchInfosMatchingPath(path)

    if not next(orderedPatchInfos) then
        return nil -- no patch to apply
    end

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

    for _, patchInfos in ipairs(orderedPatchInfos) do
        --logging:log("Applying patch mod to ", path, " for version:", patchInfos.version, " with filepath:", patchInfos.filePath, " debugOnly:", patchInfos.debugOnly, " debugCopyBefore:", patchInfos.debugCopyBefore, " debugCopyAfter:", patchInfos.debugCopyAfter)

        -- if the patch mod requests it, save a "before" copy of the file for debug purposes
        if patchInfos.debugCopyBefore then
            fileUtils.createDirectoriesIfNeededForDirPath(patchInfos.modDirPath .. "/patches" .. getDirPathFromPath(path))
            fileUtils.writeToFile(patchInfos.modDirPath .. "/patches/" ..path .. "_before.lua.temp", newFileContent)
        end

        -- call the patch module's "applyPatch" function and get the new fileContent
        local success = nil 
            
        newFileContent, success = patcher:applyPatch(patchInfos, newFileContent, path)

        if not newFileContent then
            logging:error("Patching resulted in an empty file for patch at ", patchInfos.path)
        else
            -- if the patch mod requests it, save an "after" copy of the file for debug purposes
            if patchInfos.debugCopyAfter then
                fileUtils.createDirectoriesIfNeededForDirPath(patchInfos.modDirPath .. "/patches" .. getDirPathFromPath(path))
                fileUtils.writeToFile(patchInfos.modDirPath .. "/patches/" ..path .. "_after.lua.temp", newFileContent)
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
                    fileContent = newFileContent
                    patchedModule = newPatchedModule
                end
            end
        end
    end

    -- Save a final copy into hammerstone's "patched" folder
    -- This is to help modders see the changes to the files
    if patchedModule then
        local patchedDir = hammerstonePath .. "/patched/" .. getDirPathFromPath(path)
        local patchedFilename = hammerstonePath .. "/patched/" .. path .. ".lua"
        fileUtils.createDirectoriesIfNeededForDirPath(patchedDir)
        fileUtils.writeToFile(patchedFilename, fileContent)
    end

    patchedModules[path] = patchedModule

    return patchedModule
end

function mod:onload(modManager)
    
    startDebug()
    
    -- package.loaders contains a list of functions that "require" uses to load librairies
    -- lua provides 4 default functions to search for librairies
    -- the first is a list of custom loaders per moduleName so we don't want to superced that
    -- the second function searches for a file [moduleName].lua so we add our loader before that one
	if #package.loaders == 4 then
        table.insert(package.loaders, 2, function(path)
            -- if we already found and patched the file before, return it
            if patchedModules[path] then
                return patchedModules[path]
            
            -- attempt to patch it                
            else
                return applyPatch(path)
            end
        end)
    end

    -- modManager provides a list of enabled mods per type (app or world)
    -- we go through that list to find all of the lua files of the mods in their "patches" folder
    local patchFilesPerPath = {}
	for _, modsByType in pairs(modManager.enabledModDirNamesAndVersionsByType) do
        for index, modValue in ipairs(modsByType) do 
            local patchesPath = modValue.path .. "/patches"
            if fileUtils.isDirectoryAtPath(patchesPath) then
                recursivelyFindScripts(patchesPath, nil, "scripts", modValue.path, patchFilesPerPath)
            end

            if modValue.name == "hammerstone-framework" then
                hammerstonePath = modValue.path
            end
        end
	end

    local function loadPatchMod(patchFile)
        local patchFilePath = patchFile.path
        local modPath = patchFile.modPath

        logging:log("Loading patch mod at ", patchFilePath)

        local patchFileContent = fileUtils.getFileContents(patchFilePath)
        local module, errorMsg = loadstring(patchFileContent, patchFilePath)

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
                return patchInfos
            end
        end
    end

    local function addUniversalPatchToExistingPaths(patchInfos, path)
        if patchInfosPerPath[path] then
            table.insert(patchInfosPerPath[path], patchInfos)
        else
            patchInfosPerPath[path] = { patchInfos }
        end
    end

    -- load universal patches
    if patchFilesPerPath[""] then
        for _, patchFile in pairs(patchFilesPerPath[""]) do
            local patchInfos = loadPatchMod(patchFile)

            if not patchInfos.appliesTo then
                logging:error("Universal patch at ", patchFile, " does not contain field 'appliesTo'")

            elseif type(patchInfos.appliesTo) == "string" then
                addUniversalPatchToExistingPaths(patchInfos, patchInfos.appliesTo)

            elseif type(patchInfos.appliesTo) == "table" then
                for _, path in pairs(patchInfos.appliesTo) do
                    addUniversalPatchToExistingPaths(patchInfos, path)
                end
            end
        end

        patchFilesPerPath[""] = nil
    end

    -- load all patch files found in mods and ensures they are valid
    for path, patchFiles in pairs(patchFilesPerPath) do
        if not patchInfosPerPath[path] then
            patchInfosPerPath[path] = {}
        end

        for _, patchFile in pairs(patchFiles) do
            local patchInfos = loadPatchMod(patchFile)
            
            if patchInfos then
                table.insert(patchInfosPerPath[path], patchInfos)
            end
        end
    end
end

return mod