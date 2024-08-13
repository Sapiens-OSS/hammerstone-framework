--- Hammerstone: serverMob.lua

local serverMob = {}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function serverMob:preload(parent)
	moduleManager:addModule("serverMob", parent)
end

---  @override
function serverMob:init(super, serverGOM_, serverWorld_, serverSapien_, serverSapienAI_, planManager_)
	super(self, serverGOM_, serverWorld_, serverSapien_, serverSapienAI_, planManager_)
	ddapiManager:markObjectAsReadyToLoad("serverMobHandler")
end

return shadow:shadow(serverMob)