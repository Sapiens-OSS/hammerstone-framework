--- Hammerstone: logging.lua
--- @author SirLich

-- Sapiens
local mjs = mjrequire "common/mjs"
local mjm = mjrequire "common/mjm"

local logging = {
	logDirectoryPath = nil,
	modDirectoryPath = nil
}

local function enforceValid(msg)
	if msg == nil then
		return "Nil"
	else
		return msg
	end
end

function logging:log(msg)
	mj:log("[Hammerstone] ", enforceValid(msg))
	logging:schema("_main", msg)
end

--- @deprecated, use logging:warn instead
function logging:warning(msg)
	mj:warn("[Hammerstone] ", enforceValid(msg))
end

function logging:warn(msg)
	mj:warn("[Hammerstone] ", enforceValid(msg))
end

function logging:error(msg)
	mj:error("[Hammerstone] ", enforceValid(msg))
end

---------------------------------------------------------------------------------
-- Custom Logger
-- @author earmuffs
---------------------------------------------------------------------------------

local boundToEventManager = false

local schemaLogsByFile = {}
local schemaMetaByFile = {}
local logID = 0

local logSaveNewLog = false
local logSaveTimeout = 0
local logSaveTimeoutMax = 1
local logSaveTimer = nil

--- Returns the world's log directory.
--- @return string
function getLogDirectoryPath()
	-- Only does this once to initialize
	if not boundToEventManager then
		boundToEventManager = true

		local eventManager = mjrequire "hammerstone/event/eventManager"
		local eventTypes = mjrequire "hammerstone/event/eventTypes"

		eventManager:bind(eventTypes.worldLoad, function(...)
			-- Get the world save path and apply it here
			local gameState = mjrequire "hammerstone/state/gameState"
			logging.logDirectoryPath = gameState.worldPath

			-- Create a timer to timeout log dump intervals
			local timer = mjrequire "common/timer"
			timer:addUpdateTimer(function(dt, timerID)
				logSaveTimer = timerID
				updateLogs(dt)
			end)
		end)
	end
	return logging.logDirectoryPath
end

--- Returns the current Hammerstone Framework directory.
--- @return string
function getModDirectoryPath()
	if logging.modDirectoryPath == nil then
		local modManager = mjrequire "common/modManager"
		local allMods = modManager.modInfosByTypeByDirName.world
		local enabledMods = modManager.enabledModDirNamesAndVersionsByType.world

		for _, v in pairs(enabledMods) do
			-- Crosscheck both lists so we get the correct mod
			local modName = allMods[v.name].name
			if modName == "Hammerstone Framework" then
				logging.modDirectoryPath = allMods[v.name].directory
			end
		end
	end
	return logging.modDirectoryPath
end

--- Gets the log object by ID. Returns the table and the position of the log.
--- @param logID integer
--- @return table, integer
function getLogByID(logID)
	for tblName, v in pairs(schemaMetaByFile) do
		for index, id in ipairs(v) do
			if logID == id then
				return {
					metaTable = schemaMetaByFile[tblName],
					table = schemaLogsByFile[tblName],
					index = index
				}
			end
		end
	end
end

--- Log to Hammerstone log files, which are separate from mainLog.
--- @param file_or_logID string or integer
--- @param msg string
--- @return integer
function logging:schema(fileName_or_logID, msg)
	-- Even though we have our own logging now, we still want main logs too:
	mj:log(msg)

	local logPath = getLogDirectoryPath()
	local msgString = mj:tostring(msg, 0)

	-- Add log to specific file
	if fileName_or_logID ~= nil then
		if type(fileName_or_logID) == "number" then

			-- Overwrite log entry using logID
			local logID = fileName_or_logID
			local logObject = getLogByID(logID)

			if logObject ~= nil then
				logObject.table[logObject.index] = msgString
			end
		else
			-- Create new log entry in file
			local file = fileName_or_logID

			if schemaLogsByFile[file] == nil then
				schemaLogsByFile[file] = {}
			end
			table.insert(schemaLogsByFile[file], msgString)
			
			if schemaMetaByFile[file] == nil then
				schemaMetaByFile[file] = {}
			end
			logID = logID + 1
			table.insert(schemaMetaByFile[file], logID)
		end
		
		-- Prepare to save log file
		logSaveNewLog = true
		logSaveTimeout = logSaveTimeoutMax

		-- Return the log ID to use when calling append, overwrite, and delete
		return logID
	end
end

--- Append to a Hammerstone log entry using a logID.
--- @param logID integer
--- @param msg string
--- @return integer
function logging:append(logID, msg)
	local logObject = getLogByID(logID)
	local msgString = mj:tostring(msg, 0)

	if logObject ~= nil then
		logObject.table[logObject.index] = logObject.table[logObject.index] .. msgString
	end

	-- Prepare to save log file
	logSaveNewLog = true
	logSaveTimeout = logSaveTimeoutMax

	return logID
end

--- Removes a log entry in a Hammerstone log file.
--- @param logID integer
--- @param msg string
function logging:remove(logID)
	local logObject = getLogByID(logID)

	if logObject ~= nil then
		logObject.table[logObject.index] = nil
		logObject.metaTable[logObject.index] = nil
	end
	
	-- Prepare to save log file
	logSaveNewLog = true
	logSaveTimeout = logSaveTimeoutMax
end

--- This function updates log files some time after a log is sent.
--- The delay is to save to file in batches.
--- This only exists because I haven't found a way to append to a file, only overwrite it. :)
function updateLogs(dt)
	if logSaveTimeout <= 0 then
		-- Only save if a change has been done to schemaLogsByFile
		if logSaveNewLog then
			for file, data in pairs(schemaLogsByFile) do
				local filePath = getLogDirectoryPath() .. "/logs/hammerstone_" .. file .. ".log"
				fileUtils.writeToFile(filePath, table.concat(data, "\n"))
			end
			for file, data in pairs(schemaMetaByFile) do
				mj:log(file, data)
			end
			logSaveNewLog = false
		end
	else
		logSaveTimeout = logSaveTimeout - dt
	end
end

return logging