--- Hammerstone: clientMob.lua

local clientMob = {}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function clientMob:preload(parent)
	moduleManager:addModule("clientMob", parent)
end

return shadow:shadow(clientMob)