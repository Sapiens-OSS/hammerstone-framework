--- objectUtils.lua
--- Utility methods, generally used by the objectManager
--- @author earmuffs, SirLich

local objectUtils = {}

-- Sapiens
local locale = mjrequire "common/locale"

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local json = mjrequire "hammerstone/utils/json"

-- util
local utils = mjrequire "hammerstone/utils/utils"

-- Hammestone
local log = mjrequire "hammerstone/logging"

local runOnceGuards = {}
--- Guards against the same code being run multiple times.
-- @param id string - The unique identifier for this guard.
function objectUtils:runOnceGuard(id)
	if runOnceGuards[id] == nil then
		runOnceGuards[id] = true
		return false
	end
	return true
end

objectUtils.errorCount = 0

---------------------------------------------------------------------------------
-- ConfigTable
---------------------------------------------------------------------------------

local ConfigTable={
	init = function(self, tbl) return objectUtils:initConfig(tbl) end,

	-- Table functions --
	----- Getters -----
	get = function(self, key) return self:init(objectUtils:getField(self, key)) end,
	getField = function(self, key) return self:init(self:get(key):required()) end,
	getTable = function(self, key) return self:get(key):required():ofType("table") end,
	getTableOrNil = function(self, key) return self:get(key):ofTypeOrNil("table") end,

	getString = function(self, key) return self:get(key):required():ofType("string") end,
	getStringOrNil = function(self, key) return self:get(key):ofTypeOrNil("string") end,
	getNumber = function(self, key) return self:get(key):required():ofType("number") end, 
	getNumberOrNil = function(self, key) return self:get(key):ofTypeOrNil("number") end, 
	getBoolean = function(self, key) return self:get(key):required():ofType("boolean") end,
	getBooleanOrNil = function(self, key) return self:get(key):ofTypeOrNil("boolean") end,

	getStringValue = function(self, key) return self:get(key):required():ofType("string") end,
	getStringValueOrNil = function(self, key) return self:get(key):ofTypeOrNil("string") end,
	getNumberValue = function(self, key) return self:get(key):required():ofType("number") end, 
	getNumberValueOrNil = function(self, key) return self:get(key):ofTypeOrNil("number") end, 
	getBooleanValue = function(self, key) return self:get(key):required():ofType("boolean") end,
	getBooleanValueOrNil = function(self, key) return self:get(key):ofTypeOrNil("boolean") end,

	----- Utils -----
	isEmpty = function(self) return objectUtils:isEmpty(self) end, -- returned as true value, no init
	hasKey = function(self, key) return objectUtils:hasKey(self, key) end, -- returned as true value, no init
	estimateSize = function(self) return objectUtils:estimateTableSize(self) end, -- returned as true value, no init

	----- Validations -----
	ofLength = function(self, length) return self:init(objectUtils:ofLength(self, length)) end,

	----- Casting -----
	asVec3 = function(self) return self:init(objectUtils:asVec3(self)) end,

	----- Operators -----
	__add = function(self, tblToMerge) return self:init(objectUtils:merge(self, tblToMerge)) end,

	----- Table operations -----
	mergeTo = function(self, tblToMerge) return self:init(objectUtils:merge(self, tblToMerge)) end,
	copy = function(self) return self:init(objectUtils:deepcopy(self)) end, 

	----- Predicates -----
	all = function(self, predicate) return self:init(objectUtils:all(self, predicate)) end,
	where = function(self, predicate) return self:init(objectUtils:where(self, predicate)) end,
	map = function(self, predicate) return self:init(objectUtils:map(self, predicate)) end, 
	mapKV = function(self, predicate) return self:init(objectUtils:mapKV(self, predicate)) end, 

	-- Value functions --
	----- Generic functions -----
	default = function(self, defaultValue) return self:init(objectUtils:default(self, defaultValue)) end,
	isType = function(self, typeName) return self:init(objectUtils:isType(self, typeName)) end,

	----- Validation functions -----
	required = function(self) return self:init(objectUtils:required(self)) end,
	ofType = function(self, typeName) return self:init(objectUtils:ofType(self, typeName)) end,
	ofTypeOrNil = function(self, typeName) return self:init(objectUtils:ofTypeOrNil(self, typeName)) end, 
	isInTypeTable = function(self, typeTable) return self:init(objectUtils:isInTypeTable(self, typeTable)) end,
	isInNotTypeTable = function(self, typeTable) return self:init(objectUtils:isNotInTypeTable(self, typeTable)) end,

	----- Casting -----
	asTypeIndexValue = function(self, indexTable, displayAlias) return objectUtils:asTypeIndex(self:required(), indexTable, displayAlias) end, -- returned as true value, no init
	asLocalizedStringValue = function(self, default) return objectUtils:asLocalizedString(self, default) end, -- returned as true value, no init

	asStringValue = function(self, coerceNil) return objectUtils:asString(self, false, coerceNil) end, -- returned as true value, no init
	asString = function(self, coerceNil) return self:init(self:asStringValue(coerceNil)) end, 
	asStringValueOrNil = function(self, coerceNil) return objectUtils:asString(self, true, coerceNil) end, -- returned as true value, no init
	asStringOrNil = function(self, coerceNil) return self:init(self:asStringValueOrNil(coerceNil)) end,

	asNumberValue = function(self, coerceNil, base) return objectUtils:asNumber(self, false, coerceNil, base) end, -- returned as true value, no init
	asNumber = function(self, coerceNil, base) return self:init(self:asNumberValue(coerceNil, base)) end, 
	asNumberValueOrNil = function(self, coerceNil, base) return objectUtils:asNumber(self, true, coerceNil, base) end, -- returned as true value, no init
	asNumberOrNil = function(self, coerceNil, base) self:init(self:asNumberValueOrNil(coerceNil, base)) end, 

	asBooleanValue = function(self, coerceNil) return objectUtils:asBoolean(self, false, coerceNil) end, -- returned as true value, no init
	asBoolean = function(self, coerceNil) return self:init(self:asBooleanValue(coerceNil)) end,
	asBooleanValueOrNil = function(self, coerceNil) return objectUtils:asBoolean(self, true, coerceNil) end, -- returned as true value, no init
	asBooleanOrNil = function(self, coerceNil) return self:init(self:asBooleanValueOrNil(coerceNil)) end,

	----- Predicates -----
	with = function(self, predicate) return self:init(objectUtils:with(self, predicate)) end,

	--- Returns the true value
	value = function(self) return objectUtils:getValue(self) end
}

--- So that we can do tbl:functioName
ConfigTable.__index = ConfigTable

function objectUtils:initConfig(tbl)
	if type(tbl) ~= "table" then
		local fieldTable = { fieldValue = tbl, isFieldValueTable = true }
		tbl = fieldTable
	end

	setmetatable(tbl, ConfigTable);

	return tbl
end

----------------------------------------------------------------------------------
----------------------------- Table Operations -----------------------------------
----------------------------------------------------------------------------------

function objectUtils:getValue(tbl)
	if type(tbl) == "table" and tbl["isFieldValueTable"] then
		return tbl["fieldValue"] 
	end 
	
	return tbl
end

--- Fetches a field from the table, with validation.
-- @param tbl table - The table where the field should be fetched from
-- @param key string - The key to fetch from the table
function objectUtils:getField(tbl, key)
	if key == nil then
		log:schema("ddapi", "    ERROR: Failed to get table-field: key='" .. objectUtils:coerceToString(key) .. "' table='" .. objectUtils:coerceToString(tbl) .. "'")
		self.errorCount = self.errorCount + 1
		return
	end

	-- Store the last tbl and key used to fetch a field
	-- This is for log functions only
	ConfigTable.__tbl = tbl
	ConfigTable.__key = key

	return tbl[key]
end

-- Return true if a table has key.
function objectUtils:hasKey(tbl, key)
	return tbl ~= nil and tbl[key] ~= nil
end

-- Return true if a table is null or empty.
function objectUtils:isEmpty(tbl)
	return tbl == nil or next(tbl) == nil
end

function objectUtils:merge(t1, t2)
	if t1 then
		if not t2 then
			return t1
		end

		for k, v in pairs(t2) do
			if (type(v) == "table") and (type(t1[k] or false) == "table") then
				objectUtils:merge(t1[k], t2[k])
			else
				t1[k] = v
			end
		end
		return t1
	end
end

-- http://lua-users.org/wiki/CopyTable
function objectUtils:deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[objectUtils:deepcopy(orig_key)] = objectUtils:deepcopy(orig_value)
        end
        setmetatable(copy, objectUtils:deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-----------------------------------------------------------------------------------
-- Validations
-----------------------------------------------------------------------------------

--- Asserts the length of a tbl
function objectUtils:ofLength(tbl, length)
	if tbl and  #tbl == length then
		return tbl
	end

	self.errorCount = self.errorCount + 1
	log:schema("ddapi", "    ERROR: Value of key '" .. ConfigTable.__key .. "' requires " .. length .. " elements")
end


-----------------------------------------------------------------------------------
-- Casting
-----------------------------------------------------------------------------------

--- Fetches a vec3 by coercing a json array with three elements.
function objectUtils:asVec3(tbl)
	if tbl then
		local tbl = objectUtils:ofLength(tbl, 3)

		if tbl then
			return vec3(tbl[1], tbl[2], tbl[3])
		end
	end
end

-----------------------------------------------------------------------------------
-- Predicates
-----------------------------------------------------------------------------------
--- Returns data if running predicate on each item in table returns true
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:all(tbl, predicate)
	if tbl then
		for i,e in ipairs(tbl) do
			local value = predicate(e)
			if value == nil or value == false then
				return false
			end
		end
		return true
	end
end

--- Returns items that have returned true for predicate
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:where(tbl, predicate)
	if tbl then
		local data = {}
		for i,e in ipairs(tbl) do
			if predicate(e) then
				table.insert(data, e)
			end
		end
		return data
	end
end

--- Returns result of running predicate on each item in table
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:map(tbl, predicate)
	if tbl then
		local data = {}
		for i,e in ipairs(tbl) do
			local value = predicate(e)
			if value ~= nil then
				table.insert(data, value)
			end
		end
		return data
	end
end

--- Returns result of running predicate on each item in table using both
--- the key and the value of each table element
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:mapKV(tbl, predicate)
	if tbl then
		local data = {}
		for i, e in pairs(tbl) do
			local k, v = predicate(i, e)
			if k and v then
				data[k] = v
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
--------------------------------- Value Operations --------------------------------------------
-----------------------------------------------------------------------------------------------

------------------- Generic Operations ----------------------------

--- Returns the value or defaultValue if nil
function objectUtils:default(value, defaultValue)
	-- to support real tables
	if value and value.isFieldValueTable then
		return value["fieldValue"] or defaultValue
	else
		return value or defaultValue
	end
end

-- Returns true if type of value matches the typeName
function objectUtils:isType(value, typeName)
	-- to support real tables
	if value and value.isFieldValueTable then
		return objectUtils:isType(value["fieldValue"], typeName)
	end

	return type(value) == typeName
end

-- Returns true if type of value matches the typeName or if value is nill
function objectUtils:isTypeOrNil(value, typeName)
	if not value then return true end

	-- to support real tables
	if value and value.isFieldValueTable then
		return objectUtils:isType(value["fieldValue"], typeName)
	end

	return type(value) == typeName
end

-------------------- Validation Operations -------------------------

--- Ensures the value is not nil. If not, throws an error and exits
function objectUtils:required(value)
	if value and value.isFieldValueTable then
		return objectUtils:required(value["fieldValue"])
	end

	if not value then
		log:schema("ddapi", "    ERROR: Missing required field: " .. valueTbl.__key .. " in table: ")
		log:schema("ddapi", valueTbl.__parentTable)
		self.errorCount = self.errorCount + 1
		--os.exit(1)
		--return nil
	end
end

--- Validates the type of the value
function objectUtils:ofType(value, typeName)
	if value and value.isFieldValueTable then
		return objectUtils:ofType(value["fieldValue"])
	end

	if type(value) == typeName then
		return value
	end

	objectUtils:logWrongType(valueTbl.__key, typeName)
end

function objectUtils:notOfType(value, typeName)
	if value and value.isFieldValueTable then
		return objectUtils:notOfType(value["fieldValue"])
	end

	if type(value) ~= typeName then
		return value
	end

	objectUtils:logWrongType(valueTbl.__key, typeName)
end

--- Validates the type of the value but allows nil
function objectUtils:ofTypeOrNil(value, typeName)
	if not value then return nil end

	if value and value.isFieldValueTable then
		return objectUtils:ofType(value["fieldValue"])
	end

	if type(value) == typeName then
		return value
	end

	objectUtils:logWrongType(valueTbl.__key, typeName)
end

function objectUtils:isInTypeTable(valueTbl, typeTable)
	if value and valueTbl["fieldValue"] then
		if type(typeTable) == "table" then
			if not objectUtils:hasKey(typeTable, valueTbl["fieldValue"]) then
				objectUtils:logMissing(valueTbl.__key, valueTbl["fieldValue"], typeTable)
				return nil
			end
		else
			self.errorCount = self.errorCount + 1
			log:schema("ddapi", "    ERROR: Value of typeTable is not table")
		end

		return valueTbl["fieldValue"]
	end
end

function objectUtils:isNotInTypeTable(valueTbl, typeTable)
	if value and valueTbl["fieldValue"] then
		-- Make sure this field value is a unique type
		if type(typeTable) == "table" then
			if not objectUtils:hasKey(typeTable, valueTbl["fieldValue"]) then
				objectUtils:logExisting(valueTbl.__key, valueTbl["fieldValue"], typeTable)
				return nil
			end
		else
			self.errorCount = self.errorCount + 1
			log:schema("ddapi", "    ERROR: Value of typeTable is not table")
		end

		return valueTbl["fieldValue"]
	end
end

------------------- Casting Operations -----------------------------

--- Fetches a field and casts it to the correct type index.
-- @param tbl The table to get the field from.
-- @param key The key to get from the tbl
-- @param indexTable the index table where you are going to cast the value to
-- @example "foo" becomes gameObject.types["foo"].index
function objectUtils:asTypeIndex(tbl, indexTable, displayAlias)
	if not displayAlias then
		displayAlias = objectUtils:coerceToString(key)
	end

	if tbl then
		if tbl["isFieldValueTable"] then
			return objectUtils:asTypeIndex(tbl["fieldValue"], indexTable, displayAlias)
		else
			local data = {}
			for _, v in ipairs(tbl) do
				if not indexTable[v] then
					objectUtils:logMissing(displayAlias, v, indexTable)
				else
					table.insert(data, indexTable[v].index)
				end
			end

			return data
		end
	end
end

-- Returns a string, localized if possible
function objectUtils:asLocalizedString(valueTbl, default)
	-- The key, which is either user submited, or the default
	local localKey = objectUtils:default(valueTbl, default)

	if localKey then
		-- Unchecked fetch, returns localized result, or source string.
		return locale:getUnchecked(localKey)
	end
end

-- Converts the value to a string if it can or else returns nil and logs error
function objectUtils:asString(value, allowNil, coerceNil)
	local typeName = type(value)

	if typeName == "nil" and allowNil then
		if coerceNil then return "nil" else return nil end
	elseif typeName == "table" then
		if value["isFieldValueTable"] then
			return objectUtils:asString(value["fieldValue"], allowNil, coerceNil)
		end
	elseif typeName == "string" then
		return value

	elseif typeName == "number" then
		return toString(value)

	elseif typeName == "boolean" then
		if value == true then return "true" else return "false" end

	end

	log:schema("ddapi", "    ERROR: Cannot convert value of type " .. typeName .." to string for key=" .. value.__key) 
end

-- Converts the value to a number if it can or else returns nil and logs error
function objectUtils:asNumber(value, base, allowNil, coerceNil)
	local typeName = type(value)

	if typeName == "nil" and allowNil then
		if coerceNil then return 0 else return nil end
	elseif typeName == "table" then
		if value["isFieldValueTable"] then
			return objectUtils:asNumber(value["fieldValue"], base, allowNil)
		end
	elseif typeName == "string" then
		return tonumber(value, base)
	elseif typeName == "number" then
		return value
	elseif typeName == "boolean" then
		if value == true then return 1 else return 0 end
	end

	log:schema("ddapi", "    ERROR: Cannot convert value of type " .. typeName .." to number for key=" .. value.__key) 
end

-- Converts the value to a boolean if it can or else returns nil and logs error
function objectUtils:asBoolean(value, allowNil, coerceNil)
	local typeName = type(value)

	if typeName == "nil" and allowNil then
		if coerceNil then return false else return nil end
	elseif typeName == "table" then
		if value["isFieldValueTable"] then
			return objectUtils:asBoolean(value["fieldValue"], allowNil)
		end
	elseif typeName == "string" then
		return value == "true"
	elseif typeName == "number" then
		return value ~= 0
	elseif typeName == "boolean" then
		return value
	end

	log:schema("ddapi", "    ERROR: Cannot convert value of type " .. typeName .." to boolean for key=" .. value.__key) 
end

----------------------- Predicates -----------------------------------
function objectUtils:with(value, predicate)
	if value and value.isFieldValueTable then
		return predicate(value["fieldValue"])
	else
		return predicate(value)
	end
end

-------------------------------------------------------------------------------
--TypeMap tables
-------------------------------------------------------------------------------
--- Returns the type (as in typeMap, not type(o)), or nil if not found. Logs error.
-- @param tbl The table where the key can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" which will be cast to type.
function objectUtils:getType(tbl, key, displayAlias)
	if not displayAlias then
		displayAlias = objectUtils:coerceToString(key)
	end

	if tbl[key] then
		return tbl[key]   
	end

	return objectUtils:logMissing(displayAlias, key, tbl)
end

--- Returns the index of a type, or nil if not found.
-- @param tbl The table where the index can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" where which will be cast to type.
function objectUtils:getTypeIndex(tbl, key, displayAlias)
	if not displayAlias then
		displayAlias = objectUtils:coerceToString(key)
	end
	
	if tbl[key] then
		return tbl[key].index
	end

	return objectUtils:logMissing(displayAlias, key, tbl)
end

--- Returns the key of a type, or nil if not found. Acts as an "assert and get"
-- @param tbl The table where the index can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" where which will be cast to type.
-- @param displayAlias string
function objectUtils:getTypeKey(tbl, key, displayAlias)
	if not displayAlias then
		displayAlias = objectUtils:coerceToString(key)
	end

	if tbl[key] then
		return tbl[key].key
	end

	return objectUtils:logMissing(displayAlias, key, tbl)
end

-----------------------------------------------------------------------------------------------
-- Utils
-----------------------------------------------------------------------------------------------

function objectUtils:estimateTableSize(tbl)
	local count = 0
	for _, value in pairs(tbl) do
		if type(value) == "table" then
			count = count + objectUtils:estimateTableSize(value)
		else
			count = count + 1
		end
	end
	return count
end

--- Injects properties into a table. Intended to future proof the DDAPI
-- @param configTable The table to inject into
-- @param component The component/tbl where the 'key' can be used to find custom props
-- @param key The key where props can be found
-- @param defaultProps The default properties, which can be overriden
function objectUtils:addProps(configTable, component, key, defaultProps)
	local userDefinedProps = objectUtils:getField(component, key, {default = {}})
	local mergedProps = objectUtils:merge(defaultProps, userDefinedProps)
	objectUtils:merge(configTable, mergedProps)
end

function objectUtils:debug(identifier, config, tbl)
	if config.debug then
		log:schema("ddapi", "DEBUGGING: " .. identifier)
		log:schema("ddapi", "Config:")
		log:schema("ddapi", config)
		log:schema("ddapi", "Output:")
		log:schema("ddapi", tbl)
	end
end

function objectUtils:compile(req, data)
	for k, v in pairs(req) do
		if v and data[k] == nil then
			log:schema("ddapi", "    ERROR: Missing " .. k)
			return
		end
	end
	return data
end

------------------------------------------------------------------------------------------------
-- Logs
------------------------------------------------------------------------------------------------

local logMissingTables = {}
function objectUtils:logMissing(displayAlias, key, tbl)
	if logMissingTables[tbl] == nil then
		self.errorCount = self.errorCount + 1
		table.insert(logMissingTables, tbl)

		if key == nil then
			log:schema("ddapi", "    ERROR: " .. displayAlias .. " key is nil.")
			log:schema("ddapi", debug.traceback())
		else
			log:schema("ddapi", "    ERROR: " .. displayAlias .. " '" .. key .. "' does not exist.")
			if tbl then
				log:schema("ddapi", "    HINT: Try one of these:")
				log:schema("ddapi", "{")
				for _, tbl_k in ipairs(utils:sortedTableKeys(tbl, "string")) do
					log:schema("ddapi", "      " .. tbl_k)
				end
				log:schema("ddapi", "}")
			else
				log:schema("ddapi", "        Error: No available options. This might be a Hammerstone bug.")
			end
		end
	end
end

function objectUtils:logExisting(displayAlias, key, tbl)
	self.errorCount = self.errorCount + 1
	log:schema("ddapi", "    WARNING: " .. displayAlias .. " already exists with key '" .. key .. "'")
end

function objectUtils:logWrongType(key, typeName)
	self.errorCount = self.errorCount + 1
	log:schema("ddapi", "    ERROR: key='" .. key .. "' should be of type '" .. typeName .. "', not '" .. type(key) .. "'")
end

function objectUtils:logNotImplemented(featureName)
	self.errorCount = self.errorCount + 1
	log:schema("ddapi", "    WARNING: " .. featureName .. " is used but it is yet to be implemented")
end

-------------------------------------------------------------------
-- coerce
-------------------------------------------------------------------

-- Ceorces a value into something safe for string concatination
-- I deserve to be shot for this implementation
function objectUtils:coerceToString(value)
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

	return value
end

function objectUtils:coerceToTable(value)
	if value == nil then
		return {}
	end
	
	return value
end

return objectUtils
