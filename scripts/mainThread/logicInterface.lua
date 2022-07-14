--- Shadow of logicInterface.lua
-- @author SirLich

local mod = {
	loadOrder = 0,

	-- The bridge object for LogicInterface
	bridge = nil
}

-- Hammerstone
local saveState = mjrequire "hammerstone/state/saveState"

function mod:setBridge(bridge)
	mod.bridge = bridge
	mod:registerMainThreadFunctions()

end

function mod:registerMainThreadFunctions()

	--- Test
	mod.bridge:registerMainThreadFunction("getWorldValueFromServer", function(key)
		local ret = saveState:getWorldValue(key)
		mj:log("getWorldValueFromServer logicInterface.lua, ", key, ret)
		return ret
	end)
end


function mod:onload(logicInterface)
	local super_setBridge = logicInterface.setBridge

	logicInterface.setBridge = function(self, bridge)
		super_setBridge(self, bridge)
		mod:setBridge(bridge)
	end
end


return mod