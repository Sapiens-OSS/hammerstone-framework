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
	moduleManager:addModule("animationGroups", self)
	super(self)
end

--- @shadow
function animationGroups:initMainThread(super)
	moduleManager:addModule("animationGroups", self)
	super(self)
end


return shadow:shadow(animationGroups, 0)