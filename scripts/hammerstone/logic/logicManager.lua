--- Hammerstone: logicManager.lua
-- Stores configurations and applies logic for different modules
-- @author Witchy

local logicManager = {}

local logicModules = {}
local activeOrderAIUpdateInfos = {}

function logicManager:registerActiveOrderAIUpdateInfos(actionIndex, updateInfos)
	activeOrderAIUpdateInfos[actionIndex] = updateInfos
end

function logicManager:getActiveOrderAIUpdateInfos()
	return activeOrderAIUpdateInfos
end

function logicManager:registerLogicModule(module)
	table.insert(logicModules, module)
end

function logicManager:getLogicModules()
	return logicModules
end

return logicManager