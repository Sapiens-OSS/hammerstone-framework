--- Hammerstone: activeOrderAI.lua
--- @author Witchy

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local activeOrderAI = {}

function activeOrderAI:preload(parent)
	moduleManager:addModule("activeOrderAI", parent)
end

function activeOrderAI:init(super, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)
	super(self, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)

	self.context = {
		serverSapienAI = serverSapienAI_, 
		serverSapien = serverSapien_, 
		serverGOM = serverGOM_, 
		serverWorld = serverWorld_,
		findOrderAI = findOrderAI_
	}

	ddapiManager:markObjectAsReadyToLoad("actionLogic")
end

return shadow:shadow(activeOrderAI)