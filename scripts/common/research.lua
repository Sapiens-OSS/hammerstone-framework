--- Hammerstone: research.lua

local research = {}


-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/object/objectManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function research:preload(parent)
	-- moduleManager:addModule("research", parent)
end

--- @shadow
function research:load(super, gameObject, constructable_, flora)
	super(self, gameObject, constructable_, flora)
	-- objectManager:markObjectAsReadyToLoad("research")

	moduleManager:addModule("research", self) -- TODO: This is technically wrong. Modules should be made available instantly.
end


return shadow:shadow(research)