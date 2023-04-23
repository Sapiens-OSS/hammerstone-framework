--- Hammerstone: buildable.lua
--- @author SirLich

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(buildable)
	moduleManager:addModule("buildable", buildable)
end

return mod