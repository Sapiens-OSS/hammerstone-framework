--- Hammerstone: research.lua

local research = {}


-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implement
function research:preload(parent)
	-- moduleManager:addModule("research", parent)
end

--- @shadow
function research:load(super, gameObject, constructable_, flora)
	super(self, gameObject, constructable_, flora)

	moduleManager:addModule("research", self) 
end


return shadow:shadow(research)