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
			local modName = allMods[v.name].name
			if modName == "Hammerstone Framework" then
				logging.modDirectoryPath = allMods[v.name].directory
			end
		end
	end
	return logging.modDirectoryPath
end

--- Log to Hammerstone log files, which are separate from mainLog.
--- @param file string
--- @param msg string
--- @return nil
function logging:schema(file, msg)
	-- Even though we have our own logging now, we still want main logs too:
	mj:log(msg)

	local logPath = getLogDirectoryPath()
	local msgString = mj:tostring(msg, 0) .. "\n"

	
	-- Add log to specific file
	if file ~= nil then
		if schemaLogsByFile[file] == nil then
			schemaLogsByFile[file] = msgString
		else
			schemaLogsByFile[file] = schemaLogsByFile[file] .. msgString
		end
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
				fileUtils.writeToFile(filePath, data)
			end
			logSaveNewLog = false
		end
	else
		logSaveTimeout = logSaveTimeout - dt
	end
end

return logging