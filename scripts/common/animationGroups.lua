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

--- @shadow
function animationGroups:mjInit(super)
	moduleManager:addModule("animationGroups", self)
	super(self)
	ddapiManager:markObjectAsReadyToLoad("serverMobHandler")
end

--- @shadow
function animationGroups:initMainThread(super)
	moduleManager:addModule("animationGroups", self)
	super(self)
	ddapiManager:markObjectAsReadyToLoad("serverMobHandler")
end


return shadow:shadow(animationGroups, 0)