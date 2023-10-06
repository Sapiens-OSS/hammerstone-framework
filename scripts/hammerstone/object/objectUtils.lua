--- objectUtils.lua
--- Utility methods, generally used by the objectManager
--- @author earmuffs, SirLich

local objectUtils = {}

-- Hammestone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/utils/utils"

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

--- Returns the type, or nil if not found. Logs error.
-- @param tbl The table where the key can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" which will be cast to type.
function objectUtils:getType(tbl, key, displayAlias)
	if displayAlias == nil then
		displayAlias = tostring(key)
	end

	if tbl[key] ~= nil then
			return tbl[key]   
	end
	return objectUtils:logMissing(displayAlias, key, tbl)
end


--- Returns the index of a type, or nil if not found.
-- @param tbl The table where the index can be found in. e.g., gameObject.types
-- @param key The key such as "inca:rat_skull" where which will be cast to type.
function objectUtils:getTypeIndex(tbl, key, displayAlias)
	if displayAlias == nil then
		displayAlias = tostring(key)
	end
	
	if tbl[key] ~= nil then
		return tbl[key].index
	end
	return objectUtils:logMissing(displayAlias, key, tbl)
end

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

function objectUtils:logNotImplemented(featureName)
	log:schema("ddapi", "    WARNING: " .. featureName .. " is used but it is yet to be implemented")
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

return objectUtils
