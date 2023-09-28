--- Hammerstone: activeOrderAI.lua
--- @author Witchy

-- Hammerstone
local logging = mjrequire "hammerstone/logging"
local logicManager = mjrequire "hammerstone/logic/logicManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local activeOrderAI = {}

function activeOrderAI:postload(parent)

end

function activeOrderAI:init(super, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)
	super(self, serverSapienAI_, serverSapien_, serverGOM_, serverWorld_, findOrderAI_)

	
end

return shadow:shadow(activeOrderAI)