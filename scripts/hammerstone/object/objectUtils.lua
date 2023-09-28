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

---------------------------------------------------------------------------------
-- ConfigTable
---------------------------------------------------------------------------------

ConfigTable={
	-- Table functions --
	get = function(self, key) return objectUtils:getField(self, key) end,
	isEmpty = function(self) return objectUtils:isEmpty(self) end,
	hasKey = function(self, key) return objectUtils:hasKey(self, key) end, 
	estimateSize = function(self) return objectUtils:estimateTableSize(self) end,

	----- Validations -----
	ofLength = function(self, length) return objectUtils:ofLength(self, length) end,

	----- Casting -----
	asVec3 = function(self) return objectUtils:asVec3(self) end,

	----- Operators -----
	__add = function(self, tblToMerge) return objectUtils:merge(self, tblToMerge) end,

	----- Table operations -----
	mergeTo = function(self, tblToMerge) return objectUtils:merge(self, tblToMerge) end,
	copy = function(self) return objectUtils:deepcopy(self) end, 

	----- Predicates -----
	all = function(self, predicate) return objectUtils:all(self, predicate) end,
	where = function(self, predicate) return objectUtils:where(self, predicate) end,
	map = function(self, predicate) return objectUtils:map(self, predicate) end, 
	forEach = function(self, predicate) return objectUtils:forEach(self, predicate) end, 


	-- Value functions --
	----- Generic functions -----
	default = function(self, defaultValue) return objectUtils:default(self, defaultValue) end,
	isType = function(self, typeName) return objectUtils:isType(self, typeName) end,

	----- Validation functions -----
	required = function(self) return objectUtils:required(self) end
	ofType = function(self, typeName) return objectUtils:ofType(self, typeName) end,
	isInTypeTable = function(self, typeTable) return objectUtils:isInTypeTable(self, typeTable) end,
	isInNotTypeTable = function(self, typeTable) return objectUtils:isNotInTypeTable(self, typeTable) end,

	----- Casting -----
	asTypeIndex = function(self, indexTable) return objectUtils:asTypeIndex(self, indexTable) end,
	asLocalizedString = function(self, default) return objectUtils:asLocalizedString(self, default) end,

	----- Predicates -----
	with = function(self, predicate) return objectUtils:with(self, predicate) end,
}

--- For better readability, we wrap all functions with an initConfig after declaring the ConfigTable
for name, funct in pairs(ConfigTable) do
	ConfigTable[name] = function(...)
		return objectUtils:initConfig(funct(...))
	end
end

--- So that we can do tbl:
ConfigTable.__index = ConfigTable

function objectUtils:initConfig(tbl)
	tbl = objectUtils:coerceToTable(tbl)

	if type(tbl) == "table" then
		setmetatable(tbl, ConfigTable);
	else
		tbl = { value = tbl }
		setmetatable(tbl, ConfigTable)
	end

	return tbl
end

----------------------------------------------------------------------------------
----------------------------- Table Operations -----------------------------------
----------------------------------------------------------------------------------

--- Fetches a field from the table, with validation.
-- @param tbl table - The table where the field should be fetched from
-- @param key string - The key to fetch from the table
function objectUtils:getField(tbl, key)
	if key == nil then
		log:schema("ddapi", "    ERROR: Failed to get table-field: key='" .. objectUtils:coerceToString(key) .. "' table='" .. objectUtils:coerceToString(tbl) .. "'")
		return
	end

	-- Store the last tbl and key used to fetch a field
	-- This is for log functions
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

	log:schema("ddapi", "    ERROR: Value of key '" .. ConfigTable.__key .. "' requires " .. length .. " elements")
end


-----------------------------------------------------------------------------------
-- Casting
-----------------------------------------------------------------------------------

--- Fetches a vec3 by coercing a json array with three elements.
function objectUtils:asVec3(tbl)
	local tbl = objectUtils:ofLength(tbl, 3)

	if tbl then
		return vec3(tbl[1], tbl[2], tbl[3])
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
function objectUtils:forEach(tbl, predicate)
	if tbl then
		local data = {}
		for i, e in pairs(tbl) do
			local value = predicate(i, e)
			if value ~= nil then
				table.insert(data, value)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
--------------------------------- Value Operations --------------------------------------------
-----------------------------------------------------------------------------------------------

------------------- Generic Operations ----------------------------

--- Returns the value of valueTbl[key] or defaultValue if nil
function objectUtils:default(valueTbl, defaultValue)
	return valueTbl["value"] or defaultValue
end

-- Returns true if value is of type. Also returns true for value = "true" and typeName = "boolean".
function objectUtils:isType(valueTbl, typeName)
	if type(valueTbl["value"]) == typeName then
		return true
	end
	if typeName == "number" then
		return tonumber(value)
	end
	if typeName == "boolean" then
		return value == "true"
	end
	return false
end

-------------------- Validation Operations -------------------------

--- Ensures the value is not nil. If not, throws an error and exits
function objectUtils:required(valueTbl)
	if not valueTbl["value"] then
		log:schema("ddapi", "    ERROR: Missing required field: " .. valueTbl.__key .. " in table: ")
		log:schema("ddapi", valueTbl.__parentTable)
		os.exit(1)
		return nil
	end
end

--- Validates the type of the value
function objectUtils:ofType(valueTbl, typeName)
	if type(valueTbl["value"]) == typeName then
		return valueTbl["value"]
	end

	objectUtils:logWrongType(valueTbl.__key, typeName)
end

function objectUtils:isInTypeTable(valueTbl, typeTable)
	if valueTbl["value"] then
		if type(typeTable) == "table" then
			if not objectUtils:hasKey(typeTable, valueTbl["value"]) then
				objectUtils:logMissing(valueTbl.__key, valueTbl["value"], typeTable)
				return false
			end
		else
			log:schema("ddapi", "    ERROR: Value of typeTable is not table")
		end

		return true
	end
end

function objectUtils:isNotInTypeTable(valueTbl, typeTable)
	if valueTbl["value"] then
		-- Make sure this field value is a unique type
		if type(typeTable) == "table" then
			if not objectUtils:hasKey(typeTable, valueTbl["value"]) then
				objectUtils:logExisting(valueTbl.__key, valueTbl["value"], typeTable)
				return false
			end
		else
			log:schema("ddapi", "    ERROR: Value of typeTable is not table")
		end

		return true
	end
end

------------------- Casting Operations -----------------------------

--- Fetches a field and casts it to the correct type index.
-- @param tbl The table to get the field from.
-- @param key The key to get from the tbl
-- @param indexTable the index table where you are going to cast the value to
-- @example "foo" becomes gameObject.types["foo"].index
function objectUtils:asTypeIndex(valueTbl, indexTable)
	local value = valueTbl["value"]

	if value then
		return indexTable[value]
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

----------------------- Predicates -----------------------------------
function objectUtils:with(valueTbl predicate)
	return predicate(valueTbl["value"])
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
	log:schema("ddapi", "    WARNING: " .. displayAlias .. " already exists with key '" .. key .. "'")
end

function objectUtils:logWrongType(key, typeName)
	log:schema("ddapi", "    ERROR: key='" .. key .. "' should be of type '" .. typeName .. "', not '" .. type(key) .. "'")
end

function objectUtils:logNotImplemented(featureName)
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
