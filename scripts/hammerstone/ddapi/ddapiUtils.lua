--- objectUtils.lua
--- Utility methods, generally used by the ddapiManager
--- @author earmuffs, SirLich

local ddapiUtils = {}

-- Hammestone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/utils/utils"

local runOnceGuards = {}
--- Guards against the same code being run multiple times.
-- @param id string - The unique identifier for this guard.
function ddapiUtils:runOnceGuard(id)
	if runOnceGuards[id] == nil then
		runOnceGuards[id] = true
		return false
	end
	return true
end

--- Returns the type, or nil if not found. Logs error.
-- @param tbl The table where the key can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" which will be cast to type.
function ddapiUtils:getType(tbl, key, displayAlias)
	if displayAlias == nil then
		displayAlias = tostring(key)
	end

	if tbl[key] ~= nil then
			return tbl[key]   
	end
	return ddapiUtils:logMissing(displayAlias, key, tbl)
end


--- Returns the index of a type, or nil if not found.
-- @param tbl The table where the index can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" where which will be cast to type.
function ddapiUtils:getTypeIndex(tbl, key, displayAlias)
	if displayAlias == nil then
		displayAlias = tostring(key)
	end
	
	if tbl[key] ~= nil then
		return tbl[key].index
	end
	return ddapiUtils:logMissing(displayAlias, key, tbl)
end

local logMissingTables = {}
function ddapiUtils:logMissing(displayAlias, key, tbl)
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

function ddapiUtils:logNotImplemented(featureName)
	log:schema("ddapi", "    WARNING: " .. featureName .. " is used but it is yet to be implemented")
end

function ddapiUtils:debug(identifier, config, tbl)
	if config.debug then
		log:schema("ddapi", "DEBUGGING: " .. identifier)
		log:schema("ddapi", "Config:")
		log:schema("ddapi", config)
		log:schema("ddapi", "Output:")
		log:schema("ddapi", tbl)
	end
end

----------------------------
-- utils for locale
----------------------------
function ddapiUtils:getBuildIdentifier(identifier)
	return "build_" .. identifier
end

function ddapiUtils:getNameKey(prefix, identifier)
	return prefix .. "_" .. identifier
end

function ddapiUtils:getPluralKey(prefix, identifier)
	return prefix .. "_" .. identifier .. "_plural"
end

function ddapiUtils:getNameLocKey(identifier)
	return "object_" .. identifier
end

function ddapiUtils:getPluralLocKey(identifier)
	return "object_" .. identifier .. "_plural"
end

function ddapiUtils:getSummaryLocKey(identifier)
	return "object_" .. identifier .. "_summary"
end

function ddapiUtils:getInProgressKey(prefix, identifier)
	return prefix .. "_" .. identifier .. "_inProgress"
end

function ddapiUtils:getDescriptionKey(prefix, identifier)
	return prefix .. "_" ..identifier .. "_description"
end

return ddapiUtils
