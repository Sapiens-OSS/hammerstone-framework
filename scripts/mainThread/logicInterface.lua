--- Hammerstone shadow: logicInterface.lua
--- The purpose of this file is to facilitate thread communication between the mainThread 
--- and the server thread. 
--- @author SirLich

local mod = {
	loadOrder = 0,   -- load as early as possible.
	bridge = nil     -- The bridge object for LogicInterface
}

function mod:setBridge(bridge)
	mod.bridge = bridge
	mod:registerMainThreadFunctions()
end


function mod:registerMainThreadFunctions()
	mod.bridge:registerMainThreadFunction("getWorldValueFromServer", function(key)
		local saveState = mjrequire "hammerstone/state/saveState"
		return saveState:getWorldValue(key)
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