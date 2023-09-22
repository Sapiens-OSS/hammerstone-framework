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

function patcher:runOperations(operations, fileContent)
    local success = nil
    local newFileContent = fileContent

    for _, operation in pairs(operations) do
        newFileContent, success = operation(newFileContent)

        if not success then
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

function patcher:insertAfter(nodes, chunk, fileContent)
    mj:log("insertAfter nodes:", nodes, " chunk:", chunk)
    local success = false 

    local index = 1
    local fileLength = fileContent:len()

    for _, node in pairs(nodes) do
        local nodeStart, nodeEnd = fileContent:find(node.text, index, node.plain)

        mj:log("nodeStart: ", nodeStart, " nodeEnd:", nodeEnd)

        if not nodeStart then
            return fileContent, false
        end

        index = nodeEnd + 1
        if index >= fileLength then
            return fileContent, false
        end
    end

    local newFileContent = fileContent:sub(1, index -1) .. chunk ..fileContent:sub(index, fileLength)

    return newFileContent, true
end

return patcher