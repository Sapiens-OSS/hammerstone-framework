--- Hammerstone: sapienObjectSnapping.lua
--- @author SirLich

-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local sapienObjectSnapping = {
	loadOrder = 0
}

--- @override
function sapienObjectSnapping:init(super, serverGOM_)
	super(self, serverGOM_)
	moduleManager:addModule("sapienObjectSnapping", self)
end

return shadow:shadow(sapienObjectSnapping)