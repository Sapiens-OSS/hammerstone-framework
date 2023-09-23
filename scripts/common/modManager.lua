--- Hammerstone: modManager.lua
--- @author Witchy

local patcher = mjrequire "hammerstone/utils/patcher"

local mod = {
	loadOrder = 0
}

-- a list of already patched modules
local patchedModules = {}

-- a list of patch files per path
local patchFilesPerPath = {}

-- Recursively finds all "lua" scripts within patch mods
local function recursivelyFindScripts(patchDirPath, requirePath, localPath, modPath)
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
            recursivelyFindScripts(patchDirPath .. "/" .. subFileOrDir, subDirName, localPath .. "/" .. subFileOrDir, modPath)
        end
    end
end

-- applies a patch to the file requested in 'path'
local function applyPatch(path)

    local orderedPatchModules = {}
    local scriptsFolder = fileUtils.getResourcePath("scripts")
    local originalFilePath = scriptsFolder .. "/" .. path .. ".lua"

    if not patchFilesPerPath[path] then
        -- shouldn't happen as we check for the existence in the package.loader function
        mj:error("No patch files found for path:", path)

    elseif not fileUtils.fileExistsAtPath(originalFilePath) then
        -- checks that we are patching a real 'vanilla' file found in the game's "scripts" folder
        mj:error("No file to patch found at ", originalFilePath, "\n This file may have been deleted by the dev or you are attempting to patch a mod, which is not allowed.")

    else
        -- load all patch files found in mods and ensures they are valid
        for _, patchFile in pairs(patchFilesPerPath[path]) do
            local patchFilePath = patchFile.path
            local modPath = patchFile.modPath

            mj:log("Loading patch file at ", patchFilePath)

            local patchFileContent = fileUtils.getFileContents(patchFilePath)
            local module, errorMsg = loadstring(patchFileContent, "patched " .. path)

            if not module then
                mj:error(errorMsg)
                mj:error("Failed to load patch file at path:", patchFilePath)                
            else
                local function errorhandler(err)
                    mj:error("Patch error:", patchFilePath, "\n", err)
                end

                local ok, patchObject = xpcall(module, errorhandler)

                if not patchObject then
                    mj:error("Patch load failed:", patchFilePath, "\nPlease make sure that you are returning the mod object at the end of this file")
                elseif not ok then
                    mj:error("Patch load failed:", patchFilePath)
                elseif not patchObject.applyPatch then
                    mj:error("Patch does not have an 'applyPatch' function")
                else
                    table.insert(orderedPatchModules, { 
                        path = patchFilePath, 
                        patchOrder = patchObject.patchOrder or 1, 
                        patchObject = patchObject, 
                        debugCopyAfter = patchObject.debugCopyAfter, 
                        debugCopyBefore = patchObject.debugCopyBefore, 
                        debugOnly = patchObject.debugOnly, 
                        version = patchObject.version, 
                        modPath = modPath
                    })
                end
            end
        end
    end

    if not next(orderedPatchModules) then
        mj:error("No valid patch files found for path:", path)
    else
        mj:log("Applying patch for ", path)        

        -- sort all of the patch modules by their "patchOrder"
        table.sort(orderedPatchModules, function(a,b) return a.patchOrder < b.patchOrder end)

        -- load the vanilla file content
	    local fileContent = fileUtils.getFileContents(originalFilePath)
        if not fileContent then
            mj:error("Failed to load original sapiens file at ", path)
            return nil
        end

        local patchedModule = nil 

        for _, patchModule in ipairs(orderedPatchModules) do
            mj:log("Apply patch mod for version:", patchModule.version, " with filepath:", patchModule.path)

            patcher:clearChunks()

            local patchObject = patchModule.patchObject
            local modPath = patchModule.modPath

            if patchObject.registerChunkFiles then
                for chunkName, chunkFilePath in pairs(patchObject:registerChunkFiles()) do
                    local chunkFullPath = modPath .. "/" .. chunkFilePath .. ".chunk"

                    if not fileUtils.fileExistsAtPath(chunkFullPath) then
                        mj:error("Could not locate chunk at path:", chunkFullPath)
                    else
                        local chunkContent = fileUtils.getFileContents(chunkFullPath)
                        patcher:addChunk(chunkName, chunkContent)
                    end
                end
            end

            local fileFullPathWithoutExtension = fileUtils.removeExtensionForPath(patchModule.path)

            -- if the patch mod requests it, save a "before" copy of the file for debug purposes
            if patchModule.debugCopyBefore then
                fileUtils.writeToFile(fileFullPathWithoutExtension .. "_before.lua.temp", fileContent)
            end

            -- call the patch module's "applyPatch" function and get the new fileContent
            local newFileContent = nil
            local success = nil 
            
            newFileContent, success = patchObject:applyPatch(fileContent)

            if not newFileContent then
                mj:error("Patching resulted in an empty file")
            else
                mj:log("patch done. success: ", success, " file length:", newFileContent:len())

                -- if the patch mod requests it, save an "after" copy of the file for debug purposes
                if patchModule.debugCopyAfter then
                    fileUtils.writeToFile(fileFullPathWithoutExtension .. "_after.lua.temp", newFileContent)
                end

                if not success then
                    mj:error("Patching did not succeed for patch at ", patchModule.path)

                elseif not patchModule.debugOnly then
                    -- test that the new fileContent is valid
                    local errorMsg = nil 
                    patchedModule, errorMsg = loadstring(newFileContent)
                    if not patchedModule then
                        mj:error(errorMsg)
                        mj:error("Patch failed for patch file at ", patchModule.path)
                    else
                        mj:log("Patching successful")
                        fileContent = newFileContent
                    end
                end
            end
        end

        patchedModules[path] = patchedModule

        return patchedModule
    end
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
            elseif patchFilesPerPath[path] then
                return applyPatch(path)
            end
        end)
    end

    -- modManager provides a list of enabled mods per type (app or world)
    -- we go through that list to find all of the lua files of the mods in their "patches" folder
	for _, modsByType in pairs(modManager.enabledModDirNamesAndVersionsByType) do
        for index, mod in ipairs(modsByType) do 
            local patchesPath = mod.path .. "/patches"
            if fileUtils.isDirectoryAtPath(patchesPath) then
                recursivelyFindScripts(patchesPath, nil, "scripts", mod.path)
            end
        end
	end
end

return mod