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

--- Returns result of running predicate on each item in table
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:map(tbl, predicate)
	local data = {}
	for i,e in ipairs(tbl) do
		local value = predicate(e)
		if value ~= nil then
			table.insert(data, value)
		end
	end
	return data
end

--- Returns data if running predicate on each item in table returns true
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:all(tbl, predicate)
	for i,e in ipairs(tbl) do
		local value = predicate(e)
		if value == nil or value == false then
			return false
		end
	end
	return tbl
end

--- Returns items that have returned true for predicate
-- @param tbl table - The table to process
-- @param predicate function - Function to run
function objectUtils:where(tbl, predicate)
	local data = {}
	for i,e in ipairs(tbl) do
		if predicate(e) then
			table.insert(data, e)
		end
	end
	return data
end

local logMissingTables = {}
function objectUtils:logMissing(displayAlias, key, tbl)
	if logMissingTables[tbl] == nil then
		table.insert(logMissingTables, tbl)

		if key == nil then
			log:schema("ddapi", "    ERROR: " .. displayAlias .. " key is nil.")
			log:schema("ddapi", debug.traceback())
		else
			log:schema("ddapi", "    ERROR: " .. displayAlias .. " '" .. key .. "' does not exist. Try one of these instead:")

			for k, _ in pairs(tbl) do
				if type(k) == "string" then
					log:schema("ddapi", "      " .. k)
				end
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

--- Returns the index of a type, or nil if not found.
-- @param tbl The table where the index can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" where which will be cast to type.
function objectUtils:getTypeIndex(tbl, key, displayAlias)
	if displayAlias == nil then
		displayAlias = objectUtils:coerceToString(key)
	end
	
	if tbl[key] ~= nil then
		return tbl[key].index
	end
	return objectUtils:logMissing(displayAlias, key, tbl)
end

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

function objectUtils:ceorceToTable(value)
	if value == nil then
		return {}
	end
	
	return value
end

function objectUtils:merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            objectUtils:merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end


--- Returns the key of a type, or nil if not found.
-- @param tbl table
-- @param key string
-- @param displayAlias string
function objectUtils:getTypeKey(tbl, key, displayAlias)
	if tbl[key] ~= nil then
		return tbl[key].key
	end
	return objectUtils:logMissing(displayAlias, key, tbl)
end

-- Return true if a table has key.
function objectUtils:hasKey(tbl, key)
	return tbl ~= nil and tbl[key] ~= nil
end

-- Return true if a table is null or empty.
function objectUtils:isEmpty(tbl)
	return tbl == nil or next(tbl) == nil
end

-- Returns true if value is of type. Also returns true for value = "true" and typeName = "boolean".
function objectUtils:isType(value, typeName)
	if type(value) == typeName then
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

--- Applies validations when fetching from a table.
-- @param key string - The key to fetch
-- @param value any - The value
-- @param options table - The options defining the validation
function objectUtils:validate(key, value, options)

	-- Make sure this field has the proper type
	if options.type ~= nil then
		if not objectUtils:isType(value, options.type) then
			return objectUtils:logWrongType(key, options.type)
		end
	end

	-- Make sure this field value has a valid type
	if options.inTypeTable ~= nil then
		--mj:log("inTypeTable " .. key, options.inTypeTable)
		if type(options.inTypeTable) == "table" then
			if not objectUtils:hasKey(options.inTypeTable, value) then
				return objectUtils:logMissing(key, value, options.inTypeTable)
			end
		else
			log:schema("ddapi", "    ERROR: Value of inTypeTable is not table")
		end
	end

	-- Make sure this field value is a unique type
	if options.notInTypeTable ~= nil then
		if type(options.notInTypeTable) == "table" then
			if objectUtils:hasKey(options.notInTypeTable, value) then
				return objectUtils:logExisting(key, value, options.notInTypeTable)
			end
		else
			log:schema("ddapi", "    ERROR: Value of notInTypeTable is not table")
		end
	end

	return value
end

-- Returns a string, localized if possible
function objectUtils:getLocalizedString(tbl, key, options)
	--- Inject options, without overwriting
	options = objectUtils:merge(objectUtils:ceorceToTable(options), {
		type = "string",
		with = function(key)
			return locale:getUnchecked(key)
		end
	})

	--- Fall through to base definition
	return objectUtils:getField(tbl, key, options)
end

--- Fetches a vec3 by coercing a json array with three elements.
function objectUtils:getVec3(tbl, key, options)
	-- Configure inner options to match a vec3 conversion, while still allowing custom pass-through info
	options = objectUtils:merge(objectUtils:ceorceToTable(options), {
		type = "number",
		length = 3,
		with = function(tbl)
			return vec3(tbl[1], tbl[2], tbl[3]) -- Convert number table to vec3
		end
	})

	return objectUtils:getTable(tbl, key, options)
end

--- Fetches a field and casts it to the correct type index.
-- @param tbl The table to get the field from.
-- @param key The key to get from the tbl
-- @param indexTable the index table where you are going to cast the value to
-- @example "foo" becomes gameObject.types["foo"].index
function objectUtils:getFieldAsIndex(tbl, key, indexTable, options)
	options = objectUtils:merge(objectUtils:ceorceToTable(options), {
		inTypeTable = indexTable,
		with = function(value)
			return objectUtils:getTypeIndex(indexTable, value)
		end
	})

	return objectUtils:getField(tbl, key, options)
end

--- Returns whether it's possible to get a field directly
local function canGetField(tbl, key)
	if tbl == nil then
		return false
	end

	if type(tbl) ~= "table" then
		return false
	end

	if key == nil then
		return false
	end

	if tbl[key] == nil then
		return false
	end

	return true
end

--- Fetches a field from the table, with validation.
-- @param tbl table - The table where the field should be fetched from
-- @param key string - The key to fetch from the table
-- @param options table - A table definiting the options
-- Options:
-- default (any)
-- with (function)end
-- type
-- optional
-- inTypeTable
-- notInTypeTable
function objectUtils:getField(tbl, key, options)
	-- Protect against nil options
	options = objectUtils:ceorceToTable(options)

	-- Handle 
	if canGetField(tbl, key) == false then
		-- Attempt to return default, if it exists
		if options.default ~= nil then
			return options.default
		end

		-- Optional fields silently coerce to nil
		if options.optional == true then
			return nil -- no error
		end

		-- If field wasn't explicitally marked as optional, we throw an error at this point.
		log:schema("ddapi", "    ERROR: Missing required field: " .. key .. " in table: ")
		log:schema("ddapi", tbl)
		os.exit(1)
		return nil
	end

	-- Sanitize
	if key == nil or tbl == nil then
		log:schema("ddapi", "    ERROR: Failed to get table-field: key='" .. objectUtils:coerceToString(key) .. "' table='" .. objectUtils:coerceToString(tbl) .. "'")
	end

	local value = tbl[key]

	if objectUtils:validate(key, value, options) == nil then
		return
	end

	if options.with ~= nil then
		if type(options.with) == "function" then
			value = options.with(value)
		else
			log:schema("ddapi", "    ERROR: Value of with option is not function")
		end
	end

	return value
end

-- TODO: Make this share more stuff with `getField`
function objectUtils:getTable(tbl, key, options)
	options = objectUtils:ceorceToTable(options)
	
	-- Handle 
	if canGetField(tbl, key) == false then
		-- Attempt to return default, if it exists
		if options.default ~= nil then
			return options.default
		end

		-- Optional fields silently coerce to nil
		if options.optional == true then
			return nil -- no error
		end

		-- If field wasn't explicitally marked as optional, we throw an error at this point.
		log:schema("ddapi", "    ERROR: Missing required table-field: " .. key .. " in table: ")
		log:schema("ddapi", tbl)
		log:schema("ddapi", options)
		os.exit(1) -- Crash
		return nil
	end

	-- Sanitize
	if key == nil or tbl == nil then
		log:schema("ddapi", "    ERROR: Failed to get field: key='" .. objectUtils:coerceToString(key) .. "' table='" .. objectUtils:coerceToString(tbl) .. "'")
		return nil
	end

	local values = tbl[key]

	if type(values) ~= "table" then
		return log:schema("ddapi", "    ERROR: Value type of key '" .. key .. "' is not table")
	end

	if options ~= nil then

		-- Run basic validation on all elements in the table
		for k, v in pairs(values) do
			if objectUtils:validate(key, v, options) == nil then
				return
			end
		end

		if options.length ~= nil and options.length ~= #values then
			return log:schema("ddapi", "    ERROR: Value of key '" .. key .. "' requires " .. options.length .. " elements")
		end

		for k, v in pairs(options) do
			if k == "map" then
				if type(v) == "function" then
					values = objectUtils:map(values, v)
				else
					log:schema("ddapi", "    ERROR: Value of map option is not function.")
				end
			end

			if k == "with" then
				if type(v) == "function" then
					values = v(values)
					if values == nil then
						return
					end
				else
					log:schema("ddapi", "    ERROR: Value of with option is not function.")
				end
			end
		end
	end

	return values
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

return objectUtils