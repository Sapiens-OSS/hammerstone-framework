-- Math
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4 

---------------------------------------------------------------
-- error codes
hmtErrors = mj:enum {
    "RequiredFailed",
    "ofLengthFailed",
    "ofTypeTableFailed",
    "ofTypeFailed",
    "isInTypeTableFailed", 
    "isNotInTypeTableFailed", 
    "NotInTypeTable",
    "ConversionFailed",
    "VectorWrongElementsCount",
    "NotVector",
}

hmtPairsMode  = mj:enum {
    "ValuesOnly",
    "KeysAndValues"
}

-- default error handler
local function hmtErrorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)
    error(string.format("ERROR: [%s] %s", errorCode, msg))
end 

-- metatables
local mt = {}
local valueMt = {}

-- internal Hammerstone Table module
local hmTable = {}
do
    function hmTable:new(tblOrValue, parentTable, key, errorHandler)
        if tblOrValue and type(tblOrValue) == "table" then
            local metatable = getmetatable(tblOrValue)

            if metatable then
                if metatable.__isHMT then return tblOrValue
                else 
                    setmetatable(tblOrValue, nil)
                    --error("hmt.new -> table already has a metatable. Remove it first") 
                end
            end
        end
        
        local meta = type(tblOrValue) == "table" and mt or valueMt
        local tbl = type(tblOrValue) == "table" and tblOrValue or {}
        local value = tblOrValue
        errorHandler = errorHandler or hmtErrorHandler

        return setmetatable(tbl, {
            __index = meta, 
            __value = value, 
            __errorHandler = errorHandler, 
            __parentTable = parentTable, 
            __key = key, 
            __isHMT = true
        })
    end
end

-- Global declaration for Hammerstone Tables
function hmt(tableOrValue, errorHandler) return hmTable:new(tableOrValue, nil, nil, errorHandler) end

-- metatables setup
do
    local function init(hmTable_, tblOrValue, parentTable_, fieldKey_, errorHandler_)
        local meta = getmetatable(hmTable_)
        local parentTable = parentTable_ or meta.__parentTable
        local fieldKey = fieldKey_ or meta.__key
        local errorHandler = errorHandler_ or meta.__errorHandler

        return hmTable:new(tblOrValue, parentTable, fieldKey, errorHandler)
    end


    ----- metatable for tables --------
    do
        local function raiseError(hmTable_, errorCode, msg, ...)
            local meta = getmetatable(hmTable_)
            local parentTable = meta.__parentTable
            local fieldKey = meta.__key
            local errorHandler = meta.__errorHandler
    
            if errorHandler then
                return errorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)
            end
        end

        local function getField(tbl, key)
            if not key then
                error("hmt.get -> key is nil")
            end

            return init(tbl, rawget(tbl, key), tbl, key)
        end

        --- General stuff
        do
            function mt:getValue()
                return self
            end

            local function clearTable(t)
                for k, v in pairs(t) do 
                    if type(k) == "table" then clearTable(k) end 
                    if type(v) == "table" then clearTable(v) end
                end

                return setmetatable(t, nil)
            end

            function mt:clear()
                return clearTable(self)
            end

            function mt:required()
                return self
            end

            function mt:default()
                return self
            end

            function mt:ofType(typeName)
                if typeName ~= "table" then
                    raiseError(self, hmtErrors.ofTypeTableFailed, "hmt.ofType -> Table is not a "..typeName, typeName)
                else
                    return self
                end
            end

            function mt:ofTypeOrNil(typeName)
                if typeName ~= "table" then
                    raiseError(self, hmtErrors.ofTypeTableFailed, "hmt.ofType -> Table is not a "..typeName, typeName)
                else
                    return self
                end
            end

            function mt:isNil()
                return false
            end
        end

        --- Getters ---
        do        
            function mt:get(key)
                return getField(self, key):required()
            end

            function mt:getOrNil(key)
                return getField(self, key)
            end

            local function getValueOfType(tbl, key, typeName)
                return getField(tbl, key):required():ofType(typeName):getValue()
            end

            local function getValueOrNilOfType(tbl, key, typeName)
                return getField(tbl, key):ofTypeOrNil(typeName):getValue()
            end

            local function getOfType(tbl, key, typeName)
                return getField(tbl, key):required():ofType(typeName)
            end

            local function getOfTypeOrNil(tbl, key, typeName)
                return getField(tbl, key):ofTypeOrNil(typeName)
            end

            local fieldTypes = {  "Table", "String", "Number", "Boolean", "Function"}

            for _, fieldType in ipairs(fieldTypes) do
                mt["get"..fieldType] = function(tbl,  key) return getOfType(tbl, key, fieldType:lower()) end
                mt["get"..fieldType.."OrNil"] = function(tbl,  key) return getOfTypeOrNil(tbl, key, fieldType:lower()) end
                mt["get"..fieldType.."Value"] = function(tbl,  key) return getValueOfType(tbl, key, fieldType:lower()) end
                mt["get"..fieldType.."ValueOrNil"] = function(tbl,  key) return getValueOrNilOfType(tbl, key, fieldType:lower()) end
            end
        end

        --- Utils ---
        do
            function mt:isEmpty()
                return not next(self)
            end

            function mt:length()
                local count = 0
                for k, v in pairs(self) do
                    count = count + 1
                end
                return count
            end

            function mt:hasKey(key)
                if not key then
                    error("hmt.get -> key is null")
                end

                return self[key] ~= nil
            end

            local function estimateTableSize(t)
                local count = 0
                for _, value in pairs(t) do
                    if type(value) == "table" then
                        count = count + estimateTableSize(value)
                    else
                        count = count + 1
                    end
                end
                return count
            end

            function mt:estimateSize()
                return estimateTableSize(self)
            end
        end

        --- Validation ---
        do
            function mt:ofLength(length)
                if not length then
                    error("htm.ofLength -> length is nil")
                end

                if length == self:length() then
                    return self
                end

                return raiseError(self, hmtErrors.ofLengthFailed, "hmt.ofLength -> Table is of length= " .. self:length() .. ". Required Length:" .. tostring(length), length)
            end
        end

        --- Casting ---
        do
            function mt:asVec2()
                if self:length() < 2 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "hmt.asVec2 -> Table has too few elements", 2)
                end

                if self:hasKey("x") and self:hasKey("y") then
                    return vec2(self.x, self.y)
                elseif self:hasKey(1) and self:hasKey(2) then
                    return vec2(self[1], self[2])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            function mt:asVec3()
                if self:length() < 3 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "hmt.asVec3 -> Table has too few elements", 3)
                end

                if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") then
                    return vec3(self.x, self.y, self.z)
                elseif self:hasKey(1) and self:hasKey(2) and self:hasKey(3) then
                    return vec3(self[1], self[2], self[3])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            function mt:asVec4()
                if self:length() < 4 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "hmt.asVec3 -> Table has too few elements", 4)
                end

                if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") and self:hasKey("w") then
                    return vec4(self.x, self.y, self.z, self.w)
                elseif self:hasKey(1) and self:hasKey(2) and self:hasKey(3) and self:hasKey(4) then
                    return vec4(self[1], self[2], self[3], self[4])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            function mt:asTypeIndex(typeTable, displayAlias)
                local indexArray = {}

                for k in pairs(self) do
                    local index = self:getString(k):asTypeIndex(typeTable, displayAlias)
                    if index then
                        table.insert(indexArray, index)
                    end
                end

                return indexArray
            end
        end

        --- Table Operations --
        do
            -- inject all of "table"'s functions into ourselves
            -- so we can do hmt:insert(item), etc 
            for k, v in pairs(table) do 
                mt[k] = v
            end

            function mt:contains(value)
                return self:first(function(v) return v==value end)
            end

            local function mergeTables(t1, t2)
                if not t2 then return t1 end

                for k, v in pairs(t2) do
                    if type(v) == "table" and type(t1[k]) == "table" then
                        mergeTables(t1[k], t2[k])
                    else
                        t1[k] = v
                    end
                end

                return t1
            end

            function mt:mergeWith(t)
                return mergeTables(self, t)
            end

            --[[
            -- http://lua-users.org/wiki/CopyTable
            local function deepCopy(orig)
                local orig_type = type(orig)
                local copy
                if orig_type == 'table' then
                    copy = {}
                    for orig_key, orig_value in next, orig, nil do
                        copy[deepCopy(orig_key)] = deepCopy(orig_value)
                    end
                    setmetatable(copy, deepCopy(getmetatable(orig)))
                else -- number, string, boolean, etc
                    copy = orig
                end

                return copy
            end

             It doesn't seem to work. Need to investigate
            function mt:deepCopy()
                return init(self, deepCopy(self))
            end
            ]]
        end

        --- LINQ type stuff ---
        do
            function mt:count(predicate, valuesToHMT)
                local count = 0 
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then count = count + 1 end
                end
                return count
            end

            function mt:first(predicate, valuesToHMT)
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then return init(self, e) end
                end
                return hmt(self, nil)
            end

            function mt:firstOrDefault(predicate, defaultValue, valuesToHMT)
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then return init(self, e) end
                end
                return hmt(self, defaultValue)
            end

            function mt:last(predicate, valuesToHMT)
                for i = #self, 1 do 
                    if predicate(valuesToHMT and init(self, self[i]) or self[i]) then return init(self, self[i]) end
                end
                return hmt(self, nil)
            end

            function mt:lastOrDefault(predicate, defaultValue, valuesToHMT)
                for i = #self, 1 do 
                    if predicate(valuesToHMT and init(self, self[i]) or self[i]) then return init(self, self[i]) end
                end
                return hmt(self, defaultValue)
            end
            
            function mt:all(predicate, valuesToHMT)
                for i, e in ipairs(self) do
                    if not predicate(valuesToHMT and init(self, e) or e) then return false end 
                end
                return true
            end

            --- Returns true if all pairs satisfy the predicate
            --- @param predicate: predicate function to evaluate
            --- @param pairsToHMT: Indicates if the pairs should be passed as hmt to the predicate
            ---                     0 or nil:   no HMT
            ---                     1:          values only
            ---                     2:          keys and values
            function mt:allPairs(predicate, pairsToHMT)
                pairsToHMT = pairsToHMT or 0 

                for k, v in pairs(self) do 
                    if not predicate(pairsToHMT > 1 and init(self, k) or k, pairsToHMT > 0 and init(self, v) or v) then return false end
                end
                return true
            end

            function mt:where(predicate, valuesToHMT, resultToHMT)
                local data = {}

                for i, e in ipairs(self) do
                    local valueHMT = init(self, e)
                    if predicate(valuesToHMT and valueHMT or valueHMT:getValue()) then
                        table.insert(data, resultToHMT and valueHMT or valueHMT:getValue())
                    end
                end

                return init(self, data)
            end

            function mt:wherePairs(predicate, pairsToHMT, resultToHMT)
                local data = {}
                pairsToHMT = pairsToHMT or 0 

                for k, v in pairs(self) do 
                    local kHMT = init(self, k)
                    local vHMT = init(self, v)

                    if predicate(pairsToHMT > 1 and kHMT or kHMT:getValue(), pairsToHMT > 0 and vHMT or vHMT:getValue()) then
                        data[resultToHMT > 1 and kHMT or kHMT:getValue()] = resultToHMT > 0 and vHMT or vHMT:getValue()
                    end
                end

                return init(self, data)
            end

            function mt:select(predicate, valuesToHMT)
                local data = {}

                for i, e in ipairs(self) do 
                    local valueHMT = init(self, e)
                    local result = predicate(valuesToHMT and valueHMT or valueHMT:getValue())
                    if result then table.insert(data, result) end
                end

                return init(self, data)
            end

            function mt:selectPairs(predicate, pairsToHMT)
                local data = {}

                for k, v in pairs(self) do 
                    local kHMT = init(self, k)
                    local vHMT = init(self, v)

                    local newK, newV = predicate(pairsToHMT > 1 and kHMT or kHMT:getValue(), pairsToHMT > 0 and vHMT or vHMT:getValue())
                    if newK and newV then data[newK] = newV end
                end

                return init(self, data)
            end

            function mt:with(predicate)
                return init(self, predicate(self))
            end

            function mt:toLookup()
                local data = {}
                for k, v in pairs(self) do 
                    data[v] = k
                end
                return init(self, data)
            end

            function mt:forEach(predicate, valuesToHMT)
                for i, e in ipairs(self) do 
                    local valueHMT = init(self, e)
                    predicate(valuesToHMT and valueHMT or valueHMT:getValue())
                end
                return self
            end

            function mt:forEachPair(predicate, pairsToHMT)
                for k, v in pairs(self) do 
                    local kHMT = init(self, k)
                    local vHMT = init(self, v)

                    predicate(pairsToHMT > 1 and kHMT or kHMT:getValue(), pairsToHMT > 0 and vHMT or vHMT:getValue())
                end
                return self
            end
        end
    end

    ------- metatable for Value Table ----------
    do
        local function getValue(hmTable_)
            return getmetatable(hmTable_).__value
        end

        local function getMetaValues(hmTable_)
            local meta = getmetatable(hmTable_)

            return meta.__value, meta.__parentTable, meta.__key, meta.__errorHandler
        end

        local function raiseError(hmTable_, errorCode, msg, ...)
            local value, parentTable, fieldKey, errorHandler = getMetaValues(hmTable_)
    
            if errorHandler then
                fieldKey = fieldKey or value

                if fieldKey then
                    msg = msg .. " for key "..fieldKey
                end
    
                if parentTable then
                    msg = msg .. " in table:\r\n"..mj:tostring(parentTable)
                end

                return errorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)
            end
        end


        --- General stuff
        do
            function valueMt:__tostring()
                local value, parentTable, fieldKey = getMetaValues(self) 
                local str = string.format("HMT value = %s key = %s parentTable = %s ", value, fieldKey, mj:tostring(parentTable))
                return str
            end

            function valueMt:default(defaultValue)
                local value = self:getValue()

                if value == nil then
                    return init(self, defaultValue)
                end

                return self
            end

            function valueMt:isNil()
                return getValue() == nil
            end

            function valueMt:isType(typeName)
                return type(getValue()) == typeName
            end

            function valueMt:getValue() return getValue(self) end
        end

        --- Validation ---
        do
            function valueMt:required()
                local value = self:getValue()

                if not value then 
                    return raiseError(self, hmtErrors.RequiredFailed, "hmt.require -> The value is nil") 
                else
                    return self
                end
            end

            function valueMt:ofType(typeName)
                local value = self:getValue()

                if type(value) ~= typeName then 
                    return raiseError(self, hmtErrors.ofTypeFailed, string.format("hmt.ofType -> Value '%s' is of type %s, not %s", value, type(value), typeName), typeName)
                else
                    return self
                end
            end

            function valueMt:ofTypeOrNil(typeName)
                local value = self:getValue()

                if value and type(value) ~= typeName then 
                    return raiseError(self, hmtErrors.ofTypeFailed, string.format("hmt.ofType -> Value '%s' is of type %s, not %s", value, type(value), typeName), typeName)
                else
                    return self
                end                
            end

            function valueMt:isInTypeTable(typeTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)
                displayAlias = displayAlias or fieldKey

                if not typeTable[value] then 
                    return raiseError(self, hmtErrors.isInTypeTableFailed, string.format("hmt.isInTypeTable -> Value '%s' is not in typeTable '%s'", value, displayAlias), typeTable, displayAlias)
                else
                    return self
                end         
            end

            function valueMt:isNotInTypeTable(typeTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)
                displayAlias = displayAlias or fieldKey

                if typeTable[value] then 
                    return raiseError(self, hmtErrors.isNotInTypeTableFailed, string.format("hmt.isNotInTypeTable -> Value '%s' is already in typeTable '%s'", value, displayAlias), typeTable, displayAlias)
                else
                    return self
                end
            end
        end

        --- Casting ---
        do
            local function getVectorType(vector)
                return tonumber(tostring(vector):gmatch("vec(%d)")())
            end

            function valueMt:asVec2()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return value end,
                    default = function() return vec2(value.x, value.y) end
                }
            end

            function valueMt:asVec3()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return vec3(value.x, value.y, 0) end,
                    [3] = function() return value end,
                    [4] = function() return vec3(value.x, value.y, value.z) end
                }
            end

            function valueMt:asVec4()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return vec4(value.x, value.y, 0, 0) end,
                    [3] = function() return vec4(value.x, value.y, value.z, 0) end,
                    [4] = function() return value end
                }
            end

            function valueMt:asTypeIndex(typeTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)

                if value then
                    displayAlias = displayAlias or fieldKey

                    if not typeTable[value] then
                        return raiseError(self, hmtErrors.NotInTypeTable, string.format("hmt.asTypeIndex -> Value '%s' is not in typeTable '%s'", value, displayAlias), typeTable, displayAlias)
                    else
                        return typeTable[value].index
                    end
                end
            end

            function valueMt:asLocalizedString(default)
                -- The key, which is either user submited, or the default
                local localKey = getValue(self) or default

                if localKey then
                    -- Unchecked fetch, returns localized result, or source string.
                    local locale = mjrequire "common/locale"
                    return locale:getUnchecked(localKey)
                end
            end

            local function asString(t, allowNil, coerceNil)
                local value = getValue(t)
                local typeName = type(value)

                if typeName == "nil" and allowNil then
                    if coerceNil then return "nil" else return nil end
                elseif typeName == "string" then return value
                elseif typeName == "number" then return tostring(value)
                elseif typeName == "boolean" then return tostring(value)
                else 
                    return raiseError(t, hmtErrors.ConversionFailed, string.format("hmt.%s -> Cannot convert value '%s' to string", debug.getinfo(2, "n").name, value), "string", allowNil)
                end
            end

            local function asNumber(t, base, allowNil, coerceNil)
                local value = getValue(t)
                local typeName = type(value)

                if typeName == "nil" and allowNil then
                    if coerceNil then return 0 else return nil end
                elseif typeName == "string" then return tonumber(value, base)
                elseif typeName == "number" then return value
                elseif typeName == "boolean" then
                    if value then return 1 else return 0 end
                else
                    return raiseError(t, hmtErrors.ConversionFailed, string.format("hmt.%s -> Cannot convert value '%s' to number", debug.getinfo(2, "n").name, value), "number", allowNil)
                end
            end

            local function asBoolean(t, allowNil, coerceNil)
                local value = getValue(t)
                local typeName = type(value)

                if typeName == "nil" and allowNil then
                    if coerceNil then return false else return nil end
                elseif typeName == "string" then return value == "true"
                elseif typeName == "number" then return value ~= 0 
                elseif typeName == "boolean" then return value
                else
                    return raiseError(t, hmtErrors.ConversionFailed, string.format("hmt.%s -> Cannot convert value '%s' to boolean", debug.getinfo(2, "n").name, value), "boolean", allowNil)
                end
            end

            function valueMt:asStringValue(coerceNil) return asString(self, false, coerceNil) end
            function valueMt:asString(coerceNil) return init(self, asString(self, false, coerceNil)) end
            function valueMt:asStringValueOrNil(coerceNil) return asString(self, true, coerceNil) end
            function valueMt:asStringOrNil(coerceNil) return init(self, asString(self, true, coerceNil)) end

            function valueMt:asNumberValue(coerceNil, base) return asNumber(self, base, false, coerceNil) end
            function valueMt:asNumber(coerceNil, base) return init(self, asNumber(self, base, false, coerceNil)) end
            function valueMt:asNumberValueOrNil(coerceNil, base) return asNumber(self, base, true, coerceNil) end
            function valueMt:asNumberOrNil(coerceNil, base) return init(self, asNumber(self, base, true, coerceNil)) end

            function valueMt:asBooleanValue(coerceNil) return asBoolean(self, false, coerceNil) end
            function valueMt:asBoolean(coerceNil) return init(self, asBoolean(self, false, coerceNil)) end
            function valueMt:asBooleanValueOrNil(coerceNil) return asBoolean(self, true, coerceNil) end
            function valueMt:asBooleanOrNil(coerceNil) return init(self, asBoolean(self, true, coerceNil)) end
        end

        --- LINQ type stuff ---
        do
            function valueMt:with(predicate)
                local value = self:getValue()
                return init(self, predicate(value))
            end
        end

    end
end

return {} -- This is so mod manager doesn't freak out about not returning an object 