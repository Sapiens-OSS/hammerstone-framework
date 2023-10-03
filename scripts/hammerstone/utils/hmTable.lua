-- Sapiens
local locale = mjrequire "common/locale"

-- Math
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4 

-- Utils
local json = mjrequire "hammerstone/utils/json"

---------------------------------------------------------------
local hmt = {}

-- internal module
local int = {}

-- internal utils module
local utils = {}

do
    function utils:coerceToString(value)
        if value == nil then
            return "nil"
        end
    
        if type(value) == table then
            local valueAsString = json:encode(value)
            local maxStringLen = math.min(20, valueAsString.len)
            local new_string = ""
            for i in maxStringLen do
                new_string = new_string .. valueAsString[i]
            end
    
            return new_string
        end
    end

    function utils:coerceToTable(value)
        if value == nil then
            return {}
        end
        
        return value
    end
end

local function makeMetaTable(parentTable, fieldKey)
    local mt = {
        __isHMT = true
    }

    local function get(t, key)
        if not key then
            error("hmt.get -> key is nil")
        end

        return int:make(t[key], t, key)
    end

    --- Value tables compatility --
    do
        function mt:default(defaultValue)
            return self
        end

        function mt:isType(typeName)
            return typeName == "table"
        end

        function mt:required()
            return self
        end

        function mt:value()
            return self
        end
    end

    --- Getters ---
    do        
        function mt:get(key)
            return get(self, key):required()
        end

        function mt:getOrNil(key)
            return get(self, key)
        end

        local function getValueOfType(t, key, typeName)
            return get(t, key):required():ofType(typeName)
        end

        local function getValueOrNilOfType(t, key, typeName)
            return get(t, key):ofTypeOrNil(typeName)
        end

        local function getOfType(t, key, typeName)
            return int:make(getValueOfType(t, key, typeName), t, key)
        end

        local function getOfTypeOrNil(t, key, typeName)
            return int:make(getValueOrNilOfType(t, key, typeName), t, key)
        end

        local fieldTypes = {  "Table", "String", "Number", "Boolean", "Function"}

        for _, fieldType in ipairs(fieldTypes) do
            mt["get"..fieldType] = function(t, key) return getOfType(t, key, fieldType:lower()) end
            mt["get"..fieldType.."OrNil"] = function(t, key) return getOfTypeOrNil(t, key, fieldType:lower()) end
            mt["get"..fieldType.."Value"] = function(t, key) return getValueOfType(t, key, fieldType:lower()) end
            mt["get"..fieldType.."ValueOrNil"] = function(t, key) return getValueOrNilOfType(t, key, fieldType:lower()) end
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

            if length ~= self:length() then
                error("htm.ofLength -> Table length= " .. self:length() .. " Required Length:" .. tostring(length))
            end

            return self
        end
    end

    --- Casting ---
    do
        function mt:asVec2()
            if self:length() < 2 then
                error("hmt.asVec2 -> table has too few elements")
            end

            if self:hasKey("x") and self:hasKey("y") then
                return vec2(self.x, self.y)
            else
                return vec2(self[1], self[2])
            end
        end

        function mt:asVec3()
            if self.length() < 3 then
                error("hmt.asVec3 -> table has too few elements")
            end

            if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") then
                return vec3(self.x, self.y, self.z)
            else
                return vec3(self[1], self[2], self[3])
            end
        end

        function mt:asVec4()
            if self.length() < 4 then
                error("hmt.asVec4 -> table has too few elements")
            end

            if self:hasKey("x") and self:hasKey("y") and self:hasKey("z") and self:hasKey("w") then
                return vec4(self.x, self.y, self.z, self.w)
            else
                return vec4(self[1], self[2], self[3], self[4])
            end
        end
    end

    --- Table Operations --
    do
        local function mergeTables(t1, t2)
            if not t2 then return t1 end

            for k, v in pairs(t2) do
                if type(v) == "table" and type(t1[k]) == "table" then
                    mergeTables(t1[k], t2[k])
                else
                    t1[k] = v
                end
            end
        end

        function mt:mergeWith(t)
            mergeTables(self, t)
        end

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

        function mt:deepCopy()
            return int:make(deepCopy(self), self)
        end
    end

    --- LINQ type stuff ---
    do
        function mt:all(predicate)
            for i, e in ipairs(self) do
                if not predicate(e) then return false end 
            end
            return true
        end

        function mt:allPairs(predicate)
            for k, v in pairs(self) do 
                if not predicate(k, v) then return false end
            end
            return true
        end

        function mt:where(predicate)
            local data = {}

            for i, e in ipairs(self) do
                if predicate(e) then
                    table.insert(data, e)
                end
            end

            return int:make(data, self, fieldKey)
        end

        function mt:wherePairs(predicate)
            local data = {}

            for k, v in pairs(self) do 
                if predicate(k, v) then
                    data[k] = v
                end
            end

            return int:make(data, self, fieldKey)
        end

        function mt:select(predicate)
            local data = {}

            for i, e in ipairs(self) do 
                local value = predicate(e)
                if value then table.insert(data, value) end
            end

            return int:make(data, self, fieldKey)
        end

        function mt:selectPairs(predicate)
            local data = {}

            for k, v in pairs(self) do 
                local newK, newV = predicate(k, v)
                if newK and newV then data[newK] = newV end
            end

            return int:make(data, self, fieldKey)
        end
    end

    return mt
end

local function makeValueMetatable(value, parentTable, fieldKey)
    local mt = { 
        __isHMT = true
    }

    --- General stuff
    do
        function mt:default(defaultValue)
            if not value then
                return hmt(defaultValue)
            end

            return self
        end

        function mt:isType(typeName)
            return type(value) == typeName
        end

        function mt:value() return value end
    end

    --- Validation ---
    do
        function mt:onRequiredFailed()
            error("hmt.required -> the value is nil")
        end

        function mt:required()
            if not value then return self:onRequiredFailed() end
            return self
        end

        function mt:ofType(typeName)
            if type(value) ~= typeName then 
                error("hmt.ofType -> value is of type "..type(value).." for key "..fieldKey)
            end
            return self
        end

        function mt:ofTypeOrNil(typeName)
            if value and type(value) ~= typeName then 
                error("hmt.ofType -> value is of type "..type(value).." for key "..fieldKey)
            end
            return self
        end

        function mt:isInTypeTable(typeTable)
            if not typeTable[value] then 
                error("hmt.isInTypeTable -> value "..value.." is not in type table for key "..fieldKey)
            end
            return self 
        end

        function mt:isNotInTypeTable(typeTable)
            if typeTable[value] then 
                error("hmt.isNotInTypeTable -> value "..value.." is in type table for key "..fieldKey)
            end 
            return self 
        end
    end

    --- Casting ---
    do
        function mt:asTypeIndexValue(typeTable, displayAlias)
            if not displayAlias then
                displayAlias = utils:coerceToString(fieldKey)
            end

            if not typeTable[value] then
                error("hmt.asTypeIndexValue -> key "..fieldKey.." is not in type table")
            else
                return typeTable[value].index
            end
        end

        function mt:asLocalizedString(default)
            -- The key, which is either user submited, or the default
            local localKey = value or default

            if localKey then
                -- Unchecked fetch, returns localized result, or source string.
                return locale:getUnchecked(localKey)
            end
        end

        local function asString(allowNil, coerceNil)
            local typeName = type(value)

            if typeName == "nil" and allowNil then
                if coerceNil then return "nil" else return nil end
            elseif typeName == "string" then return value
            elseif typeName == "number" then return tostring(value)
            elseif typeName == "boolean" then return tostring(value)
            end

            error("hmt->"..debug.getInfo(3, "n").name.." Cannot convert "..fieldKey.." to string")
        end

        local function asNumber(base, allowNil, coerceNil)
            local typeName = type(value)

            if typeName == "nil" and allowNil then
                if coerceNil then return 0 else return nil end
            elseif typeName == "string" then return tonumber(value, base)
            elseif typeName == "number" then return value
            elseif typeName == "boolean" then
                if value then return 1 else return 0 end
            end

            error("hmt->"..debug.getInfo(3, "n").name.." Cannot convert "..fieldKey.."to number")
        end

        local function asBoolean(allowNil, coerceNil)
            local typeName = type(value)

            if typeName == "nil" and allowNil then
                if coerceNil then return false else return nil end
            elseif typeName == "string" then return value == "true"
            elseif typeName == "number" then return value ~= 0 
            elseif typeName == "boolean" then return value
            end

            error("hmt->"..debug.getInfo(3, "n").name.." Cannot convert "..fieldKey.."to boolean")
        end

        function mt:asStringValue(coerceNil) return asString(false, coerceNil) end
        function mt:asString(coerceNil) return int:make(asString(false, coerceNil), parentTable, fieldKey) end
        function mt:asStringValueOrNil(coerceNil) return asString(true, coerceNil) end
        function mt:asStringOrNil(coerceNil) return int:make(asString(true, coerceNil), parentTable, fieldKey) end

        function mt:asNumberValue(coerceNil, base) return asNumber(base, false, coerceNil) end
        function mt:asNumber(coerceNil, base) return int:make(asNumber(base, false, coerceNil), parentTable, fieldKey) end
        function mt:asNumberValueOrNil(coerceNil, base) return asNumber(base, true, coerceNil) end
        function mt:asNumberOrNil(coerceNil, base) return int:make(asNumber(base, true, coerceNil), parentTable, fieldKey) end

        function mt:asBooleanValue(coerceNil) return asBoolean(false, coerceNil) end
        function mt:asBoolean(coerceNil) return int:make(asBoolean(false, coerceNil), parentTable, fieldKey) end
        function mt:asBooleanValueOrNil(coerceNil) return asBoolean(true, coerceNil) end
        function mt:asBooleanOrNil(coerceNil) return int:make(asBoolean(true, coerceNil), parentTable, fieldKey) end
    end

    --- LINQ type stuff ---
    do
        function mt:with(predicate)
            return predicate(value)
        end
    end

    return mt
end

function int:make(tblOrValue, parentTable, fieldKey)
    local mt = tblOrValue and type(tblOrValue) == "table" and getmetatable(tblOrValue)

    if mt and mt.__isHMT then return tblOrValue end
    
    if type(tblOrValue) == "table" then
        mt = makeMetaTable(tblOrValue, parentTable, fieldKey)
    else
        mt = makeValueMetatable(tblOrValue, parentTable, fieldKey)
        tblOrValue = {}
    end 

    mt.__index = tblOrValue
    setmetatable(tblOrValue)
    return tblOrValue
end

local mt = {
    __call = function(tblOrValue) return int:make(tblOrValue) end
}

setmetatable(hmt, mt)

return hmt