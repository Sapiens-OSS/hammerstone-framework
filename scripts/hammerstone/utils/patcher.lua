--- Hammerstone: modManager.lua
--- @author Witchy
--- Provides 'util' functions to patch lua scripts

local patcher = {}

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

function patcher:indentChunk(chunk, indent)
    local newChunk = ""

    for chunkLine, lineEnd in chunk:gmatch("([^\r\n]*)(\r?\n?)") do
        newChunk = newChunk .. string.rep("    ", indent) .. chunkLine .. lineEnd
    end

    return newChunk
end

function patcher:runOperations(operations, fileContent, verbrose)
    local success = nil
    local newFileContent = fileContent

    for index, operation in pairs(operations) do
        newFileContent, success = operation(newFileContent)

        if not success then
            if verbrose then
                mj:log("Patch operation failed at index " .. index)
            end

            return fileContent, false
        end
    end

    return newFileContent, true
end

function patcher:getAndIndentChunk(chunkName, indent)
    return patcher:indentChunk(patcher:getChunk(chunkName), indent)
end

function patcher:localFunctionToGlobal(moduleName, functionName, fileContent)
    local count = nil

    fileContent, count = fileContent:gsub(
        "local function " .. functionName .. "%(", 
        "function " .. moduleName .. ":PATCHEDFUNCTIONPLACEHOLDER(")

    if count == 0 then return fileContent, false end 

    fileContent, count = fileContent:gsub(
        "([^%a%d]*)" .. functionName .. "%(", 
        "%1" .. moduleName .. ":" .. functionName .. "(")   
        
    if count == 0 then return fileContent, false end

    fileContent, count = fileContent:gsub("PATCHEDFUNCTIONPLACEHOLDER", functionName)

    return fileContent, count ~= 0
end

function patcher:localVariableToGlobal(variableName, objectName, fileContent)
    local count = nil

    local lvStart, lvEnd, lv, lvAssign = 
        fileContent:find("(local " .. variableName .. ")([^%a%d][^\r\n]*)[\r\n]+")

    local mdStart = fileContent:find("local " .. objectName .. "[%s=]+")

    if not lvStart or not mdStart then
        return fileContent, false
    end

    if lvStart < mdStart then
        fileContent = fileContent:gsub("local " .. variableName .. "[^%a%d][^\r\n]*[\r\n]+", "") 
    else
        fileContent = fileContent:gsub("local " .. variableName .. "([^%a%d][^\r\n]*[\r\n]+)", objectName .. ".PATCHVARIABLEPLACEHOLDER%1") 
    end

    fileContent, count = fileContent:gsub("([^%a%d]*)(" .. variableName .. "[^%a%d]*)", "%1" .. objectName .. ".%2")

    if count == 0 then return fileContent, false end
    
    if lvStart < mdStart then
        fileContent = fileContent:gsub("local " .. objectName .. "[%s=]+([^\r\n]*[\r\n]+)",
            function(afterObjectName)
                local replaceString = 
                "local " .. objectName .. " = {\r\n" ..
                "    " .. variableName .. lvAssign .. ",\r\n"

                if afterObjectName:find("}") then
                    replaceString = replaceString .. "}\r\n\r\n"
                end

                return replaceString
            end
        )
    else
        fileContent = fileContent:gsub("PATCHVARIABLEPLACEHOLDER", variableName)
    end

    return fileContent, true
end

local function searchNodes(nodes, fileContent, startAt)
    local fileLength = fileContent:len()
    local lastStart = nil
    local lastEnd = nil
    local index = startAt or 1

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
            return fileContent, false
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

function patcher:insertAfter(nodes, chunk, fileContent)
    local success = false 

    local lastStart, lastEnd = searchNodes(nodes, fileContent)

    if not lastEnd then return fileContent, false end

    local newFileContent = fileContent:sub(1, lastEnd) .. chunk ..fileContent:sub(lastEnd + 1, fileLength)

    return newFileContent, true
end

function patcher:removeAt(startNodes, endNodes, fileContent)
    local success = false

    local removeStart, startEnd = searchNodes(startNodes, fileContent)

    if not removeStart then return fileContent, false end

    local _, removeEnd = searchNodes(endNodes, fileContent, startEnd + 1)

    if not removeEnd then return fileContent, false end 

    local newFileContent = fileContent:sub(1, removeStart - 1) .. fileContent:sub(removeEnd + 1, fileContent:len())

    return newFileContent, true
end

function patcher:replaceAt(startNodes, endNodes, chunk, fileContent)
    local success = false

    local removeStart, startEnd = searchNodes(startNodes, fileContent)

    if not removeStart then return fileContent, false end

    local _, removeEnd = searchNodes(endNodes, fileContent, startEnd + 1)

    if not removeEnd then return fileContent, false end 

    local newFileContent = fileContent:sub(1, removeStart - 1) .. chunk .. fileContent:sub(removeEnd + 1, fileContent:len())

    return newFileContent, true
end

function patcher:replace(pattern, replacement, fileContent)
    local count = nil

    fileContent, count = fileContent:gsub(pattern, replacement)

    return fileContent, count ~= 0
end

return patcher