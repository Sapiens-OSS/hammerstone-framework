--- Hammerstone: modManager.lua
--- @author Witchy
--- Allows vanilla files to be patched

--- Hammerstone
local logging = mjrequire "hammerstone/logging"

local patcher = {}

local fileContent = nil

local chunks = {}

local keywords = {}

local logSkippedErrors = false

--- Clears the current list of chunks
function patcher:clearChunks()
    chunks = {}
end

--- Adds a chunk to the chunk list
--- @param chunkName string
--- @param chunk string
function patcher:addChunk(chunkName, chunk)
    chunks[chunkName] = chunk
end

--- Gets a chunk by chunkName
--- @param chunkName string
--- @return string
function patcher:getChunk(chunkName)
    return chunks[chunkName]
end

local function replaceKeywords(value)
    for k, v in pairs(keywords) do
        value = value:gsub(k, v)
    end

    return value
end

--- Loads a chunk from a table and indents it if needs be
--- Valid table example:
--- { chunk = [chunkName], indent = [number] (optional) }
local function loadChunk(chunkTable)
    local chunkName = chunkTable.chunk

    if not chunks[chunkName] then
        logging:error("Invalid chunk name: ", chunkName)
        return nil
    else
        local chunk = chunks[chunkName]

        if chunkTable.indent then
            local newChunk = ""

            for chunkLine, lineEnd in chunk:gmatch("([^\r\n]*)(\r?\n?)") do
                newChunk = newChunk .. string.rep("    ", chunkTable.indent) .. chunkLine .. lineEnd
            end

            return replaceKeywords(newChunk)
        end

        return chunk
    end
end

--- Returns a string from an object
--- The object can be: 
---   a string (which will return itself)
---   a table containing the parameterName
---   a table containing a chunk
---   a function which will return the string
local function getStringParameter(obj, parameterName)
    local objType = type(obj)

    if objType == "string" then
        return replaceKeywords(obj)

    elseif objType == "number" then
        return obj

    elseif objType == "table" then
        if obj[parameterName] then
            return getStringParameter(obj[parameterName])

        elseif obj["chunk"] then
            return loadChunk(obj)
        else
            logging:error("Could not find ", parameterName)
            return nil
        end

    elseif objType == "function" then
        return getStringParameter(obj(fileContent), parameterName)

    elseif objType == "nil" then
        return nil
    else
        logging:error("Unsupported type")
        return nil
    end
end

--- Searches nodes to locate indexes within the fileContent
--- If 'nodes' is a string, executes string.find with plain text
--- If 'nodes' is a function, executes it
--- If 'nodes' is a table, either executes string.find with the parameters provided by the table
---   or executes the nodes
--- Returns the start and end of the last searched string
local function searchNodes(nodes, startAt)
    local index = startAt or 1
    local nodesType = type(nodes)
    local fileLength = fileContent:len()
    local lastStart = nil
    local lastEnd = nil

    local function searchNode(node)
        local text = nil
        local plain = nil
        local reps = nil

        local nodeType = type(node)

        if nodeType == "string" then
            text = node
            plain = true
        elseif nodeType == "table" then
            text = node.text
            plain = node.plain
            reps = node.reps
        elseif nodeType == "function" then
            text, plain, reps = node(fileContent, index)
        else
            logging:error("Unrecognized node type")
            error()
            return nil
        end

        if not reps then reps = 1 end
        local currentRep = 0 

        while currentRep ~= reps do
            currentRep = currentRep + 1

            local nodeStart, nodeEnd = fileContent:find(replaceKeywords(text), index, plain)

            if not nodeStart then
                if reps == -1 then
                    break
                else
                    return false
                end
            end

            lastStart = nodeStart
            lastEnd = nodeEnd
            index = lastEnd + 1

            if index >= fileLength then
                if reps == -1 then
                    break
                else
                    return nil
                end
            end
        end
    end

    if nodesType == "string" or nodesType == "number" then
        return fileContent:find(nodes, index, true)

    elseif nodesType == "function" then
        return nodes(fileContent, index)

    elseif nodesType ~= "table" then
        logging:error("Unrecognized node type")
        return nil

    elseif nodes.text then
        searchNode(nodes)
    else
        for _, node in pairs(nodes) do
            searchNode(node)
        end
    end

    return lastStart, lastEnd
end

--- Turns a local function into a global function
local function localFunctionToGlobal(functionName, moduleName)
    functionName = getStringParameter(functionName, "functionName")

    if not functionName then
        logging:error("'functionName' is nil")
        return false
    end

    moduleName = getStringParameter(moduleName, "moduleName")

    if not moduleName then
        moduleName = keywords["#MODULENAME#"]
    end

    --TODO : Transform that into an operation sequence?

    local count = nil

    fileContent, count = fileContent:gsub(
        "local function " .. functionName .. "%(", 
        "function " .. moduleName .. ":PATCHEDFUNCTIONPLACEHOLDER(")

    if count == 0 then return false end 

    fileContent, count = fileContent:gsub(
        "([^%a%d]*)" .. functionName .. "%(", 
        "%1" .. moduleName .. ":" .. functionName .. "(")   
        
    if count == 0 then return false end

    fileContent, count = fileContent:gsub("PATCHEDFUNCTIONPLACEHOLDER", functionName)

    return count ~= 0
end

--- Turns a local variable into a variable part of the module
local function localVariableToModule(variableName, moduleName)
    variableName = getStringParameter(variableName, "variableName")

    if not functionName then
        logging:error("'variableName' is nil")
        return false
    end

    moduleName = getStringParameter(moduleName, "moduleName")

    if not moduleName then
        moduleName = keywords["#MODULENAME#"]
    end

    local count = nil

    local lvStart, lvEnd, lv, lvAssign = 
        fileContent:find("(local " .. variableName .. ")([^%a%d][^\r\n]*)[\r\n]+")

    local mdStart = fileContent:find("local " .. moduleName .. "[%s=]+")

    if not lvStart or not mdStart then
        return false
    end

    if lvStart < mdStart then
        fileContent = fileContent:gsub("local " .. variableName .. "[^%a%d][^\r\n]*[\r\n]+", "") 
    else
        fileContent = fileContent:gsub("local " .. variableName .. "([^%a%d][^\r\n]*[\r\n]+)", moduleName .. ".PATCHVARIABLEPLACEHOLDER%1") 
    end

    fileContent, count = fileContent:gsub("([^%a%d]*)(" .. variableName .. "[^%a%d]*)", "%1" .. moduleName .. ".%2")

    if count == 0 then return false end
    
    if lvStart < mdStart then
        fileContent, count = fileContent:gsub("local " .. moduleName .. "[%s=]+([^\r\n]*[\r\n]+)",
            function(afterModuleName)
                local replaceString = 
                "local " .. moduleName .. " = {\r\n" ..
                "    " .. variableName .. lvAssign .. ",\r\n"

                if afterModuleName:find("}") then
                    replaceString = replaceString .. "}\r\n\r\n"
                end

                return replaceString
            end
        )
    else
        fileContent, count = fileContent:gsub("PATCHVARIABLEPLACEHOLDER", variableName)
    end

    return count ~=0
end

--- Inserts a string after position "after"
local function insertAfter(after, string)
    string = getStringParameter(string, "string")

    if not string then
        logging:error("'string' is nil")
        return false
    end

    if not after then
        fileContent = fileContent .. string
    else
        local lastStart, lastEnd = searchNodes(after)

        if not lastEnd then return false end

        fileContent = fileContent:sub(1, lastEnd) .. string ..fileContent:sub(lastEnd + 1)
    end

    return true
end

--- Inserts a string before position "before"
local function insertBefore(before, string)
    string = getStringParameter(string, "string")

    if not string then
        logging:error("'string' is nil")
        return false
    end

    if not before then
        fileContent = string .. fileContent
    else
        local lastStart = searchNodes(before)

        if not lastStart then return false end

        fileContent = fileContent:sub(1, lastStart - 1) .. string .. fileContent:sub(lastStart)
    end

    return true
end

--- Removes content starting at "startAt" and ending at "endAt"
--- Both startAt and endAt are inclusive
--- If endAt is nil, the operation will remove content until end of file
local function removeAt(startAt, endAt)
    if not startAt then
        logging:error("'startAt' is nil")
        return false
    end

    local success = false

    local removeStart, startEnd = searchNodes(startAt)

    if not removeStart then return false end

    if endAt then
        local _, removeEnd = searchNodes(endAt, fileContent, startEnd + 1)

        if not removeEnd then return false end 

        fileContent = fileContent:sub(1, removeStart - 1) .. fileContent:sub(removeEnd + 1)
    else
        fileContent = fileContent:sub(1, removeStart - 1)
    end

    return true
end

--- Replaces content starting at "startAt" and ending at "endAt"
--- Both startAt and endAt are inclusive
--- If endAt is nil, the operation will remove content until end of file
local function replaceAt(startAt, endAt, repl)
    if not startAt then
        logging:error("'startAt' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        logging:error("'repl' is nil")
        return false
    end

    local removeStart, startEnd = searchNodes(startAt)

    if not removeStart then return fileContent, false end

    if endAt then
        local _, removeEnd = searchNodes(endAt, startEnd + 1)

        if not removeEnd then return fileContent, false end 

        fileContent = fileContent:sub(1, removeStart - 1) .. repl .. fileContent:sub(removeEnd + 1, fileContent:len())
    else
        fileContent = fileContent:sub(1, removeStart - 1) .. repl
    end

    return true
end

--- Replaces content between "startAt" and ending before "endAt"
--- Both startAt and endAt are exclusive
local function replaceBetween(startAt, endAt, repl)
    if not startAt then
        logging:error("'startAt' is nil")
        return false
    end

    if not endAt then
        logging:error("'endAt' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        logging:error("'repl' is nil")
        return false
    end

    local lastStart, replaceStart = searchNodes(startAt)

    if not replaceStart then return fileContent, false end

    if endAt then
        local replaceEnd = searchNodes(endAt, replaceStart + 1)

        if not replaceEnd then return fileContent, false end 

        fileContent = fileContent:sub(1, replaceStart) .. repl .. fileContent:sub(replaceEnd, fileContent:len())
    else
        fileContent = fileContent:sub(1, replaceStart) .. repl
    end

    return true
end

--- Replaces content according to a pattern
local function replace(pattern, repl)
    repl = getStringParameter(repl, "repl")

    if not repl then
        logging:error("'repl' is nil")
        return false
    end

    local count = nil 

    fileContent, count = fileContent:gsub(pattern, repl)

    return count ~= 0
end

--- Runs operations sequentially. If one fails, it stops the process
function patcher:runOperations(operations)
    for key, operation in ipairs(operations) do 
        local success = true

        if type(operation) == "function" then
            fileContent, success = operation(fileContent)
        else
            local opType = operation.type
            local canExecute = true 

            if operation.condition then
                canExecute = operation.condition(fileContent, { path = keywords["#PATH#"], moduleName = keywords["#MODULENAME#"] })
            end

            if canExecute then
                if not opType then
                    logging:error("Operation ", key, " did not declare a type")
                    return false
                elseif opType == "replace" then
                    success = replace(operation.pattern, operation.repl)
                elseif opType == "replaceAt" then
                    success = replaceAt(operation.startAt, operation.endAt, operation.repl)
                elseif opType == "replaceBetween" then
                    success = replaceBetween(operation.startAt, operation.endAt, operation.repl)
                elseif opType == "removeAt" then
                    success = removeAt(operation.startAt, operation.endAt)
                elseif opType == "insertAfter" then
                    success = insertAfter(operation.after, operation.string)
                elseif opType == "insertBefore" then
                    success = insertBefore(operation.before, operation.string)
                elseif opType == "localVariableToModule" then
                    success = localVariableToModule(operation.variableName, operation.moduleName)
                elseif opType == "localFunctionToGlobal" then
                    success = localFunctionToGlobal(operation.functionName, operation.moduleName)
                else
                    logging:error("Invalid operation type:", opType)
                    return false
                end
            end
        end

        if not success then
            if not operation.skipOnFail then
                logging:error("Operation failed: ", key)
                return false
            elseif logSkippedErrors then
                logging:log("Operation failed and was skipped: ", key)
            end
        end
    end

    return true
end

local function getModuleNameFromPath(path)
    local moduleName = nil
    
    for match in path:gmatch("[^/]+") do
        moduleName = match
    end

    return moduleName        
end

--- Applies a patch
--- @param patchInfos patchInfos (see modManager)
--- @param fileContent_ string
function patcher:applyPatch(patchInfos, fileContent_, path)
    if not patchInfos.operations then
        logging:error("Patch does not have operations")
        return fileContent_, false
    end

    fileContent = fileContent_
    chunks = {}

    local chunksFolder = patchInfos.modDirPath .. "/chunks"
    if fileUtils.isDirectoryAtPath(chunksFolder) then
        local dirContent = fileUtils.getDirectoryContents(chunksFolder)
        for i, subFileOrDir in ipairs(dirContent) do
            local extension = fileUtils.fileExtensionFromPath(subFileOrDir)
            if extension and extension == ".lua" then
                local chunkName = fileUtils.removeExtensionForPath(subFileOrDir)
                chunks[chunkName] = fileUtils.getFileContents(chunksFolder .. "/" .. subFileOrDir)
            end
        end
    end

    keywords["#PATH#"] = path
    keywords["#MODULENAME#"] = getModuleNameFromPath(path)

    local success = patcher:runOperations(patchInfos.operations)

    return fileContent, success
end

return patcher