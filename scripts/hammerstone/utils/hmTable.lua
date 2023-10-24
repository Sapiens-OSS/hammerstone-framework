--- Hammerstone: hmTable
--- Allows for easier table and value manipulations
--- @author Witchy

-- Math
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4 


-- error codes
hmtErrors = mj:enum {
    "keyIsNil",
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
    "notFound",
    "notEmptyFailed"
}

-- modes for predicates
hmtPairsMode  = mj:enum {
    "none",
    "keysOnly",
    "valuesOnly",
    "both"
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
    -- Creates a new hmt
    -- @param tblOrValue:   The table or value to convert to hmt
    -- @param parentTable:  The table that requested the creation of the new hmt, if any
    -- @param key:          The key used to fetch the new tblOrValue, if any
    -- @param errorHandler: The error handler to assign to the new hmt. If nil, the default error handler will be applied
    function hmTable:new(tblOrValue, parentTable, key, errorHandler)
        if tblOrValue and type(tblOrValue) == "table" then
            local metatable = getmetatable(tblOrValue)

            if metatable then
                if metatable.__isHMT then return tblOrValue
                else 
                    setmetatable(tblOrValue, nil)
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
                raiseError(tbl, hmtErrors.keyIsNil, "hmt.get -> key is nil")
            end

            return init(tbl, rawget(tbl, key), tbl, key)
        end

        --- General stuff
        do
            local function clearTable(t)
                for k, v in pairs(t) do 
                    if type(k) == "table" then clearTable(k) end 
                    if type(v) == "table" then clearTable(v) end
                end

                return setmetatable(t, nil)
            end

            -- Removes the metatable from the table and all its children, reverting the hmt table to a normal table
            -- If a table needs to be stored by the game, please call "clear" on it
            function mt:clear()
                return clearTable(self)
            end
        end

        --- Compatibility with value tables ---
        do
            -- Returns the hmt
            function mt:getValue()
                return self
            end

            -- Returns the hmt as it cannot be nil
            function mt:required()
                return self
            end

            -- Returns itself as it cannot be nil
            function mt:default()
                return self
            end

            -- Checks if the hmt's value is of type "typeName". If not, raises an error
            -- @param typeName: The name of the type
            function mt:ofType(typeName)
                if typeName ~= "table" then
                    raiseError(self, hmtErrors.ofTypeTableFailed, "hmt.ofType -> Table is not a "..typeName, typeName)
                else
                    return self
                end
            end

            -- Checks if the hmt's value is of type "typeName". If not, raises an error
            -- @param typeName: The name of the type
            function mt:ofTypeOrNil(typeName)
                if typeName ~= "table" then
                    raiseError(self, hmtErrors.ofTypeTableFailed, "hmt.ofType -> Table is not a "..typeName, typeName)
                else
                    return self
                end
            end

            -- Returns false as tables cannot be nil
            function mt:isNil()
                return false
            end

            -- Returns true if "typeName" is a table
            -- @param typeName: The name of the type
            function mt:isType(typeName)
                return typeName == "table"
            end
        end

        --- Getters ---
        do        
            -- Gets the value of the table corresponding to "key". If not found, raises an error
            -- @param key:  The key of the value to get
            function mt:get(key)
                return getField(self, key):required()
            end

            -- Gets the value of the table corresponding to "key" or nil if not found.
            -- @param key:  The key of the value to get
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
            -- Returns true if the table contains no elements
            function mt:isEmpty()
                return not next(self)
            end

            -- Returns the length of the table
            function mt:length()
                local count = 0
                for k, v in pairs(self) do
                    count = count + 1
                end
                return count
            end

            -- Returns true if the table has a value corresponding to "key"
            -- @param key: The key of the value to get
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

            -- Returns the total size (length) of the table, including children
            function mt:estimateSize()
                return estimateTableSize(self)
            end

            -- Allows to iterate over an hmt table where the values are also converted to hmt
            function mt:pairs()
                local key = nil
                local iterator = function()
                    local nextKey = next(self, key)
                    if not nextKey then return nil end
                    key = nextKey
                    return key, self:get(key)
                end

                return iterator, self, key
            end

            -- Allows to iterate over an hmt table (array) where the values are also converted to hmt
            function mt:ipairs()
                local index = 0
                local iterator = function()
                    index = index + 1
                    if index > #self then return nil end
                    return index, self:get(index)
                end

                return iterator, self, index
            end
        end

        --- Validation ---
        do
            -- Raises an error if the table does not have [length] elements
            -- @param length: The required length
            function mt:ofLength(length)
                if not length then
                    error("htm.ofLength -> length is nil")
                end

                if length == self:length() then
                    return self
                end

                return raiseError(self, hmtErrors.ofLengthFailed, "Table is of length= " .. self:length() .. ". Required Length:" .. tostring(length), length)
            end

            -- Raises an error if the table is empty
            function mt:notEmpty()
                if not next(self) then
                    return raiseError(self, hmtErrors.notEmptyFailed, "Table is empty")
                end

                return self
            end
        end

        --- Casting ---
        do
            -- Converts the table to a vec2
            function mt:asVec2()
                if self:length() < 2 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "Table has too few elements", 2)
                end

                if self:hasKey("x") and self:hasKey("y") then
                    return vec2(self.x, self.y)
                elseif self:hasKey(1) and self:hasKey(2) then
                    return vec2(self[1], self[2])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            -- Converts the table to a vec3
            function mt:asVec3()
                if self:length() < 3 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "Table has too few elements", 3)
                end

                if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") then
                    return vec3(self.x, self.y, self.z)
                elseif self:hasKey(1) and self:hasKey(2) and self:hasKey(3) then
                    return vec3(self[1], self[2], self[3])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            -- Converts the table to a vec4
            function mt:asVec4()
                if self:length() < 4 then
                    return raiseError(self, hmtErrors.VectorWrongElementsCount, "Table has too few elements", 4)
                end

                if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") and self:hasKey("w") then
                    return vec4(self.x, self.y, self.z, self.w)
                elseif self:hasKey(1) and self:hasKey(2) and self:hasKey(3) and self:hasKey(4) then
                    return vec4(self[1], self[2], self[3], self[4])
                else
                    return raiseError(self, hmtErrors.NotVector, "Could not build vector")
                end
            end

            -- Converts a table of strings into a table of type indexes
            -- @param typeTable:    The table to fetch the types from (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
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

            -- Converts a table of strings into a table of types
            -- @param typeTable:    The table to fetch the types from (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
            function mt:asTypeIndexMap(typeTable, displayAlias)
                local indexArray = {}

                for k in pairs(self) do
                    local index = self:getString(k):asTypeIndexMap(typeTable, displayAlias)
                    if index then
                        table.insert(indexArray, index)
                    end
                end

                return indexArray
            end

            -- Returns an array containing the keys of the table
            function mt:keysToTable()
                local data = {}
                for k, v in pairs(self) do 
                    table.insert(data, k)
                end
                return init(self, data)
            end

            -- Returns an array containing the values of the table
            function mt:valuesToTable()
                local data = {}
                for k, v in pairs(self) do 
                    table.insert(data, v)
                end
                return init(self, data)
            end
        end

        --- Table Operations --
        do
            -- inject all of "table"'s functions into ourselves
            -- so we can do hmt:insert(item), etc 
            for k, v in pairs(table) do 
                mt[k] = v
            end

            -- Returns true if the table contains the desired value
            -- @param value: The value to search for
            function mt:contains(value)
                return self:firstOrNil(function(v) return v==value end) ~= nil
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

            -- Merges a table into the current hmt
            -- @param t: The table to merge
            function mt:mergeWith(t)
                return mergeTables(self, t)
            end

            local function copy(tblOrValue)
                if type(tblOrValue) == "table" then
                    local newCopy = {}

                    for k, v in pairs(tblOrValue) do 
                        newCopy[k] = copy(v)
                    end

                    return newCopy
                else
                    return tblOrValue
                end
            end

            -- Creates a copy of the current hmt
            function mt:copy()
                return init(self, copy(self))
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
            -- Returns the number of elements that correspond to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:count(predicate, valuesToHMT)
                local count = 0 
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then count = count + 1 end
                end
                return count
            end

            -- Returns the minimum value that correspond to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:min(predicate, valuesToHMT)
                local min = math.huge
                for i, e in ipairs(self) do 
                    min = math.min(min, predicate(valuesToHMT and init(self, e) or e))
                end
                return min
            end

            -- Returns the maximum value that correspond to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:max(predicate, valuesToHMT)
                local max = -math.huge
                for i, e in ipairs(self) do 
                    max = math.max(max, predicate(valuesToHMT and init(self, e) or e))
                end
                return max
            end

            -- Returns the index of the value corresponding to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:indexOf(predicate, valuesToHMT)
                for i, e in ipairs(self) do 
                    if predicate(valuesToHMT and init(self, e) or e) then
                        return i
                    end
                end
            end

            -- Returns the first value corresponding to the predicate. If not found, raises an error.
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:first(predicate, valuesToHMT)
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then return init(self, e), i end
                end
                raiseError(self, hmtErrors.notFound, "predicate did not find a value. Maybe use firstOrNil instead")
            end

            -- Returns the first value corresponding to the predicate or the default value if not found.
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- @param defaultValue: The default to return if the desired value is not found.
            -- Note: table must be an array
            function mt:firstOrNil(predicate, valuesToHMT, defaultValue)
                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then return init(self, e), i end
                end
                return init(self, defaultValue)
            end

            -- Returns the last value corresponding to the predicate. If not found, raises an error.
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:last(predicate, valuesToHMT)
                for i = #self, 1 do 
                    if predicate(valuesToHMT and init(self, self[i]) or self[i]) then return init(self, self[i]), i end
                end
                raiseError(self, hmtErrors.notFound, "predicate did not find a value. Maybe use lastOrNil instead")
            end

            -- Returns the last value corresponding to the predicate or the default value if not found.
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- @param defaultValue: The default to return if the desired value is not found.
            -- Note: table must be an array
            function mt:lastOrNil(predicate, defaultValue, valuesToHMT)
                for i = #self, 1 do 
                    if predicate(valuesToHMT and init(self, self[i]) or self[i]) then return init(self, self[i]), i end
                end
                return init(self, defaultValue)
            end
            
            -- Returns true if all of the values of the table correspond to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:all(predicate, valuesToHMT)
                for i, e in ipairs(self) do
                    if not predicate(valuesToHMT and init(self, e) or e) then return false end 
                end
                return true
            end

            -- Returns true if all of the values of the table correspond to the predicate
            -- @param predicate:    The predicate function
            -- @param pairsToHMT:   Indicates wether to pass the values and/or keys as hmt to the predicate (see hmtPairsMode)
            function mt:allPairs(predicate, pairsToHMT)
                pairsToHMT = pairsToHMT or hmtPairsMode.none

                for k, v in pairs(self) do 
                    local key = (pairsToHMT == hmtPairsMode.keysOnly or pairsToHMT == hmtPairsMode.both) and init(self, k) or k
                    local value = (pairsToHMT == hmtPairsMode.valuesOnly or pairsToHMT == hmtPairsMode.both) and init(self, v) or v
                    if not predicate(key, value) then return false end
                end
                return true
            end

            -- Returns all values corresponding to the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:where(predicate, valuesToHMT)
                local data = {}

                for i, e in ipairs(self) do
                    if predicate(valuesToHMT and init(self, e) or e) then
                        table.insert(data, e)
                    end
                end

                return init(self, data)
            end

            -- Returns all pairs corresponding to the predicate
            -- @param predicate:    The predicate function
            -- @param pairsToHMT:   Indicates wether to pass the values and/or keys as hmt to the predicate (see hmtPairsMode)
            function mt:wherePairs(predicate, pairsToHMT)
                local data = {}
                pairsToHMT = pairsToHMT or hmtPairsMode.none

                for k, v in pairs(self) do 
                    local key = (pairsToHMT == hmtPairsMode.keysOnly or pairsToHMT == hmtPairsMode.both) and init(self, k) or k
                    local value = (pairsToHMT == hmtPairsMode.valuesOnly or pairsToHMT == hmtPairsMode.both) and init(self, v) or v

                    if predicate(key, value) then
                        data[k] = v
                    end
                end

                return init(self, data)
            end

            -- Returns a table containing the result of the predicate
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:select(predicate, valuesToHMT)
                local data = {}

                for i, e in ipairs(self) do 
                    local result = predicate(valuesToHMT and init(self, e) or e)
                    if result then table.insert(data, result) end
                end

                return init(self, data)
            end

            -- Returns a table containing the result of the predicate
            -- @param predicate:    The predicate function
            -- @param pairsToHMT:   Indicates wether to pass the values and/or keys as hmt to the predicate (see hmtPairsMode)
            function mt:selectPairs(predicate, pairsToHMT)
                local data = {}
                pairsToHMT = pairsToHMT or hmtPairsMode.none

                for k, v in pairs(self) do 
                    local key = (pairsToHMT == hmtPairsMode.keysOnly or pairsToHMT == hmtPairsMode.both) and init(self, k) or k
                    local value = (pairsToHMT == hmtPairsMode.valuesOnly or pairsToHMT == hmtPairsMode.both) and init(self, v) or v

                    local newK, newV = predicate(key, value)
                    if newK then data[newK] = newV end
                end

                return init(self, data)
            end

            -- Returns a table containing the result of the predicate
            -- @param predicate:    The predicate function
            -- @param keysToHMT:  If true, passes the key as an hmt to the predicate
            function mt:selectKeys(predicate, keysToHMT)
                local data = {}

                for k in pairs(self) do 
                    local result = predicate(keysToHMT and init(self, k) or k)
                    if result then table.insert(data, result) end
                end

                return init(self, data)
            end

            -- Returns the result of the predicate
            -- @param predicate:    The predicate function
            function mt:with(predicate)
                return init(self, predicate(self))
            end

            -- Returns a lookup table (inverses the keys and the values)
            function mt:toLookup()
                local data = {}
                for k, v in pairs(self) do 
                    data[v] = k
                end
                return init(self, data)
            end

            -- Executes a predicate on each value of the table
            -- @param predicate:    The predicate function
            -- @param valuesToHMT:  If true, passes the value as an hmt to the predicate
            -- Note: table must be an array
            function mt:forEach(predicate, valuesToHMT)
                for i, e in ipairs(self) do 
                    self[i] = predicate(valuesToHMT and init(e) or e)
                end
                return self
            end

            -- Executes a predicate on each pair of the table
            -- @param predicate:    The predicate function
            -- @param pairsToHMT:   Indicates wether to pass the values and/or keys as hmt to the predicate (see hmtPairsMode)
            function mt:forEachPair(predicate, pairsToHMT)
                pairsToHMT = pairsToHMT or hmtPairsMode.none

                for k, v in pairs(self) do 
                    local key = (pairsToHMT == hmtPairsMode.keysOnly or pairsToHMT == hmtPairsMode.both) and init(self, k) or k
                    local value = (pairsToHMT == hmtPairsMode.valuesOnly or pairsToHMT == hmtPairsMode.both) and init(self, v) or v

                    self[k] = predicate(key, value)
                end
                return self
            end

            -- Sorts the table by a specific key
            -- @param key:   The key to use
            -- Note: table must be an array
            function mt:orderBy(key)
                for i = 1, #self - 1 do 
                    local a = self:get(i):get(key):getValue()
                    for n = i + 1, #self do
                        local b = self:get(n):get(key):getValue()

                        if b < a then
                            local temp = self[i]
                            self[i] = self[n]
                            self[n] = temp
                        end
                    end
                end

                return self
            end

            function mt:orderByDescending(key)
                for i = 1, #self - 1 do 
                    local a = self:get(i):get(key):getValue()
                    for n = i + 1, #self do
                        local b = self:get(n):get(key):getValue()

                        if b > a then
                            local temp = self[i]
                            self[i] = self[n]
                            self[n] = temp
                        end
                    end
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

            -- If the true value is nil, returns the default value
            -- @param defaultValue: The default value
            function valueMt:default(defaultValue)
                local value = self:getValue()

                if value == nil then
                    return init(self, defaultValue)
                end

                return self
            end

            -- Returns true if the true value is nil
            function valueMt:isNil()
                return self:getValue() == nil
            end

            -- Returns true if the true value is of type [typeName]
            -- @param typeName: name of the type
            function valueMt:isType(typeName)
                return type(self:getValue()) == typeName
            end

            -- Returns the true value
            function valueMt:getValue() return getValue(self) end

            -- Compatibility with table hmt. Returns the true value
            function valueMt:clear()
                return self:getValue()
            end
        end

        --- Validation ---
        do
            -- If the true value is nil raises an error
            function valueMt:required()
                local value = self:getValue()

                if not value then 
                    return raiseError(self, hmtErrors.RequiredFailed, "The value is nil") 
                else
                    return self
                end
            end

            -- Raises an error if the true value's type is not [typeName]
            -- @param typeName: name of the type
            function valueMt:ofType(typeName)
                local value = self:getValue()

                if type(value) ~= typeName then 
                    return raiseError(self, hmtErrors.ofTypeFailed, string.format("Value '%s' is of type %s, not %s", value, type(value), typeName), typeName)
                else
                    return self
                end
            end

            -- Raises an error if the true value's type is not [typeName] or nil
            -- @param typeName: name of the type
            function valueMt:ofTypeOrNil(typeName)
                local value = self:getValue()

                if value and type(value) ~= typeName then 
                    return raiseError(self, hmtErrors.ofTypeFailed, string.format("Value '%s' is of type %s, not %s", value, type(value), typeName), typeName)
                else
                    return self
                end                
            end

            -- Raises an error if the true value is not in the type table
            -- @param typeTable:    The type table to use (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
            function valueMt:isInTypeTable(typeTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)
                displayAlias = displayAlias or fieldKey

                if not typeTable[value] then 
                    return raiseError(self, hmtErrors.isInTypeTableFailed, string.format("Value '%s' is not in typeTable '%s'", value, displayAlias), typeTable, displayAlias)
                else
                    return self
                end         
            end

            -- Raises an error if the true value is in the type table
            -- @param typeTable:    The type table to use (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
            function valueMt:isNotInTypeTable(typeTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)
                displayAlias = displayAlias or fieldKey

                if typeTable[value] then 
                    return raiseError(self, hmtErrors.isNotInTypeTableFailed, string.format("Value '%s' is already in typeTable '%s'", value, displayAlias), typeTable, displayAlias)
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

            -- Casts the true value as a vec2
            function valueMt:asVec2()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return value end,
                    default = function() return vec2(value.x, value.y) end
                }
            end

            -- Casts the true value as a vec3
            function valueMt:asVec3()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return vec3(value.x, value.y, 0) end,
                    [3] = function() return value end,
                    [4] = function() return vec3(value.x, value.y, value.z) end
                }
            end

            -- Casts the true value as a vec4
            function valueMt:asVec4()
                local value = self:required():ofType("cdata"):getValue()

                local vectorType = getVectorType(value)

                return switch(vectorType) : caseof {
                    [2] = function() return vec4(value.x, value.y, 0, 0) end,
                    [3] = function() return vec4(value.x, value.y, value.z, 0) end,
                    [4] = function() return value end
                }
            end

            -- Converts the true value to an index. If the true value is nil, returns nil
            -- @param typeTable:    The table to fetch the types from (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
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

            -- Converts the true value to an type. If the true value is nil, returns nil
            -- @param typeTable:    The table to fetch the types from (ex: skill.types)
            -- @param displayAlias: Alias/name of the typeTable. Used for logs (Ex: skill.types's alias would be "skill")
            function valueMt:asTypeIndexMap(typeIndexMapTable, displayAlias)
                local value, _, fieldKey = getMetaValues(self)

                if value then
                    displayAlias = displayAlias or fieldKey

                    if not typeIndexMapTable[value] then
                        return raiseError(self, hmtErrors.NotInTypeTable, string.format("hmt.asTypeIndexMap -> Value '%s' is not in typeTable '%s'", value, displayAlias), typeIndexMapTable, displayAlias)
                    else
                        return typeIndexMapTable[value]
                    end
                end
            end

            -- Converts the true value to a localized string.
            -- @param default:  default key to use
            function valueMt:asLocalizedString(default)
                -- The key, which is either user submited, or the default
                local localKey = self:getValue() or default

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

            -- The following functions are self explanatory
            -- Converts the true value to an other type. Raises an error if it cannot convert.
            -- @param coerceNil:    Returns a default value if the true value is nil (ex: "nil" for strings, 0 for numbers, false for boolean)

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
            -- Returns the result of the predicate
            -- @param predicate:    The predicate function
            function valueMt:with(predicate)
                local value = self:getValue()
                return init(self, predicate(value))
            end
        end

    end
end

return {} -- This is so mod manager doesn't freak out about not returning an object 