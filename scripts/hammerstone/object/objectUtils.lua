--- objectUtils.lua
--- Utility methods, generally used by the objectManager
--- @author earmuffs, SirLich

local objectUtils = {}

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

function objectUtils:debug(identifier, config, tbl)
	if config.debug then
		log:schema("ddapi", "DEBUGGING: " .. identifier)
		log:schema("ddapi", "Config:")
		log:schema("ddapi", config)
		log:schema("ddapi", "Output:")
		log:schema("ddapi", tbl)
	end
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

return objectUtils
