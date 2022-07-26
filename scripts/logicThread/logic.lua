--- Hammerstone: logic.lua
--- The purpose of this file is to facilitate thread communication between the logic thread
--- and the main thread.
--- @author SirLich

local mod = {
	loadOrder = 0, -- load as early as possible.
	bridge = nil
}

-- Creative Mode
local cheat = mjrequire "creativeMode/cheat"


function mod:registerLogicFunctions()
	mod.bridge:registerLogicThreadNetFunction("getWorldValueFromServer", function(key)
		local ret = mod.bridge:callMainThreadFunction("getWorldValueFromServer", key)
		mj:log("getWorldValueFromServer log.lua, ", key, ret)
		return ret
	end)
end

function mod:onload(logic)
	local super_setBridge = logic.setBridge
	logic.setBridge = function(self, bridge)
		super_setBridge(self, bridge)
		mod.bridge = bridge
		mod.registerLogicFunctions(self)
	end

	local super_setClientGOM = logic.setClientGOM
	logic.setClientGOM = function(self, clientGOM, clientSapien_)
		super_setClientGOM(self, clientGOM, clientSapien_)
	end
end

return mod