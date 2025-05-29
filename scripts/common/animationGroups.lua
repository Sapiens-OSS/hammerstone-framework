-- Hammerstone: animationGroups.lua
-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local animationGroups = {}


--- @implements
function animationGroups:addAnimationGroup(key)
	table.insert(self.loadFileNames, key)
end

--- @implement
function animationGroups:postload(parent)
	moduleManager:addModule("animationGroups", parent)
end

-- --- @shadow
-- function animationGroups:mjInit(super)
-- 	ddapiManager:markObjectAsReadyToLoad("craftable")

-- 	super(self)
-- end

-- --- @shadow
-- function animationGroups:initMainThread(super)
-- 	moduleManager:addModule("animationGroups", self)
-- 	super(self)
-- end


return shadow:shadow(animationGroups, 0)