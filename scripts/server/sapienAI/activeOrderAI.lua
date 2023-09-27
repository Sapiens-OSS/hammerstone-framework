--- Hammerstone: activeOrderAI.lua
--- @author Witchy

-- Hammerstone
local logging = mjrequire "hammerstone/logging"
local logicManager = mjrequire "hammerstone/logic/logicManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local activeOrderAI = {}

function activeOrderAI:postload(parent)
	local updateInfosToAdd = logicManager:getActiveOrderAIUpdateInfos()

	for actionIndex, updateInfo in pairs(updateInfosToAdd) do
		self.updateInfos[actionIndex] = updateInfo
	end
end

function activeOrderAI:init(super, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)
	super(self, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)

	local logicModules = logicManager:getLogicModules()

	for _, logicModule in ipairs(logicModule)
		if not logicModule.init then
			logging:error("Logic module doesn't have a init function")
		else
			logicModule:init(serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)
		end
	end
end

return shadow:shadow(activeOrderAI)