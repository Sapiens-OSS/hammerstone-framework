--- Hammerstone: modManager.lua
--- @author Witchy
--- Allows vanilla files to be patched

local patcher = {}

local fileContent = nil

local chunks = {}

function patcher:clearChunks()
    chunks = {}
end

function patcher:addChunk(chunkName, chunk)
    chunks[chunkName] = chunk
end

function patcher:getChunk(chunkName)
    return chunks[chunkName]
end

local function loadChunk(chunkTable)
    local chunkName = chunkTable.chunk

    if not chunks[chunkName] then
        mj:error("Invalid chunk name: ", chunkName)
        return nil
    else
        local chunk = chunks[chunkName]

        if chunkTable.indent then
            local newChunk = ""

            for chunkLine, lineEnd in chunk:gmatch("([^\r\n]*)(\r?\n?)") do
                newChunk = newChunk .. string.rep("    ", chunkTable.indent) .. chunkLine .. lineEnd
            end

            return newChunk
        end

        return chunk
    end
end

local function getStringParameter(obj, parameterName)
    local objType = type(obj)

    if objType == "string" or objType == "number" then
        return obj

    elseif objType == "table" then
        if obj[parameterName] then
            return getStringParameter(obj[parameterName])

        elseif obj["chunk"] then
            return loadChunk(obj)
        else
            mj:error("Could not find ", parameterName)
            return nil
        end

    elseif objType == "function" then
        return getStringParameter(obj(fileContent), parameterName)

    elseif objType == "nil" then
        return nil
    else
        mj:error("Unsupported type")
        return nil
    end
end

local function searchNodes(nodes, startAt)
    local index = startAt or 1
    local nodesType = type(nodes)

    if nodesType == "string" or nodesType == "number" then
        return fileContent:find(nodes, index, true)
    elseif nodesType == "function" then
        return nodes(index)
    elseif nodesType ~= "table" then
        mj:error("Unrecognized node type")
        return nil
    elseif nodes.text then
        return fileContent:find(nodes.text, index, nodes.plain)
    else
        local fileLength = fileContent:len()
        local lastStart = nil
        local lastEnd = nil

        for _, node in pairs(nodes) do
            local text = nil
            local plain = nil

            local nodeType = type(node)

            if nodeType == "string" then
                text = node
                plain = true
            elseif nodeType == "table" then
                text = node.text
                plain = node.plain
            elseif nodeType == "function" then
                text, plain = node(fileContent, lastEnd +1)
            else
                mj:error("Unrecognized node type")
                error()
                return nil
            end

            local nodeStart, nodeEnd = fileContent:find(text, index, plain)

            if not nodeStart then
                return false
            end

            lastStart = nodeStart
            lastEnd = nodeEnd
            index = lastEnd + 1

            if index >= fileLength then
                return nil
            end
        end

        return lastStart, lastEnd
    end
end

--TODO : Transform that into an operation sequence?
local function localFunctionToGlobal(functionName, moduleName)
    functionName = getStringParameter(functionName, "functionName")

    if not functionName then
        mj:error("'functionName' is nil")
        return false
    end

    moduleName = getStringParameter(moduleName, "moduleName")

    if not moduleName then
        mj:error("'moduleName' is nil")
        return false
    end

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

local function localVariableToGlobal(variableName, moduleName)
    variableName = getStringParameter(variableName, "variableName")

    if not functionName then
        mj:error("'variableName' is nil")
        return false
    end

    moduleName = getStringParameter(moduleName, "moduleName")

    if not moduleName then
        mj:error("'moduleName' is nil")
        return false
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

local function insertAfter(after, repl)
    if not after then
        mj:error("'after' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        mj:error("'repl' is nil")
        return false
    end

    local lastStart, lastEnd = searchNodes(after)

    if not lastEnd then return false end

    fileContent = fileContent:sub(1, lastEnd) .. repl ..fileContent:sub(lastEnd + 1)

    return true
end

local function insertBefore(before, repl)
    if not before then
        mj:error("'before' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        mj:error("'repl' is nil")
        return false
    end

    local lastStart = searchNodes(before)

    if not lastStart then return false end

    fileContent = fileContent:sub(1, lastStart - 1) .. repl .. fileContent:sub(lastStart)

    return true
end

local function removeAt(startAt, endAt)
    if not startAt then
        mj:error("'startAt' is nil")
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

local function replaceAt(startAt, endAt, repl)
    if not startAt then
        mj:error("'startAt' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        mj:error("'repl' is nil")
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

local function replaceBetween(startAt, endAt, repl)
    if not startAt then
        mj:error("'startAt' is nil")
        return false
    end

    if not endAt then
        mj:error("'endAt' is nil")
        return false
    end

    repl = getStringParameter(repl, "repl")

    if not repl then
        mj:error("'repl' is nil")
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

local function replace(pattern, repl)
    repl = getStringParameter(repl, "repl")

    if not repl then
        mj:error("'repl' is nil")
        return false
    end

    local count = nil 

    fileContent, count = fileContent:gsub(pattern, repl)

    return count ~= 0
end

function patcher:runOperations(operations)
    for key, operation in pairs(operations) do 
        local success = nil

        if type(operation) == "function" then
            fileContent, success = operation(fileContent)
        else
            local opType = operation.type
            local canExecute = true 

            if operation.condition then
                canExecute = operation.condition(fileContent)
            end

            if canExecute then
                if not opType then
                    mj:error("Operation ", key, " did not declare a type")
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
                    success = insertAfter(operation.after, operation.repl)
                elseif opType == "insertBefore" then
                    success = insertBefore(operation.before, operation.repl)
                elseif opType == "localVariableToGlobal" then
                    success = localVariableToGlobal(operation.variableName, operation.moduleName)
                elseif opType == "localFunctionToGlobal" then
                    success = localFunctionToGlobal(operation.functionName, operation.moduleName)
                else
                    mj:error("Invalid operation type:", opType)
                    return false
                end
            end
        end

        if not success then
            mj:error("Operation failed: ", key)
            return false
        end
    end

    return true
end

function patcher:applyPatch(patchInfos, fileContent_)
    if not patchInfos.operations then
        mj:error("Patch does not have operations")
        return fileContent_, false
    end

    fileContent = fileContent_
    chunks = {}

    if patchInfos.chunkFiles then
        for chunkName, chunkFilePath in pairs(patchInfos.chunkFiles) do 
            local fullPath = patchInfos.modDirPath .. "/" .. chunkFilePath .. ".chunk"
            if not fileUtils.fileExistsAtPath(fullPath) then
                mj:error("Chunk file does not exist at ", fullPath)
                return fileContent, false
            end

            chunks[chunkName] = fileUtils.getFileContents(fullPath)
        end
    end

    local success = patcher:runOperations(patchInfos.operations)

    return fileContent, success
end

return patcher