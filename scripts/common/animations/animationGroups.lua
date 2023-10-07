-- Hammerstone: animationGroups.lua

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local animationGroups = {}


--- @implements
function animationGroups:addAnimationGroup(key)
	table.insert(self.groupNames, key)
end

--- @shadow
function animationGroups:mjInit(super)
	super(self)
	moduleManager:addModule("animationGroups", self)
end


return shadow:shadow(animationGroups, 0)