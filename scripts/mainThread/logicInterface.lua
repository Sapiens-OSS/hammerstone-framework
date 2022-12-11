--- Hammerstone: logicInterface.lua
--- The purpose of this file is to facilitate thread communication between the mainThread 
--- and the server thread.
--- @author SirLich

local mod = {
	loadOrder = 0,   -- load as early as possible.
	bridge = nil     -- The bridge object for LogicInterface
}

function mod:registerMainThreadFunctions()
	mod.bridge:registerMainThreadFunction("getWorldValueFromServer", function(key)
		local saveState = mjrequire "hammerstone/state/saveState"
		return saveState:getWorldValue(key)
	end)

	mod.bridge:registerMainThreadFunction("getValueFromLogic", function(key)
		local saveState = mjrequire "hammerstone/state/saveState"
		local ret = saveState:getValueClient(key)
		mj:log("getValueFromLogic called on main Thread ", ret)
		return ret
	end)
end

function mod:onload(logicInterface)
	local super_setBridge = logicInterface.setBridge

	logicInterface.setBridge = function(self, bridge)
		super_setBridge(self, bridge)

		-- Expose to Hammerstone
		mod.bridge = bridge
		logicInterface.bridge = bridge

		mod:registerMainThreadFunctions()
	end
end

return mod