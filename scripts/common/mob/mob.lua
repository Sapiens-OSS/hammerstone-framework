-- Hammerstone: mob.lua

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local mob = {}

--- @override
function mob:preload(parent)
	moduleManager:addModule("mob", parent)
end


return shadow:shadow(mob, 0)