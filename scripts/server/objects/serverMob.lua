--- Hammerstone: serverMob.lua

local serverMob = {}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/ddapi/objectManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function serverMob:preload(parent)
	moduleManager:addModule("serverMob", parent)
end

---  @override
function serverMob:init(super, serverMob_, serverGOM_, serverWorld_, serverSapien_, planManager_)
	super(self, serverMob_, serverGOM_, serverWorld_, serverSapien_, planManager_)
	objectManager:markObjectAsReadyToLoad("serverMobHandler")
end

return shadow:shadow(serverMob)