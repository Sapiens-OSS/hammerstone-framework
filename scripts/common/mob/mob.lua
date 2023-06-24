-- Hammerstone: mob.lua

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/object/objectManager"

local mob = {}

--- @override
function mob:preload(parent)
	moduleManager:addModule("mob", self)
end

--- @shadow
function mob:load(super, gameObject)
	objectManager:markObjectAsReadyToLoad("mob")
	super(gameObject)
end


return shadow:shadow(mob, 1)