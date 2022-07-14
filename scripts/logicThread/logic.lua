--- Shadow of logic.lua
-- @author SirLich

local mod = {
	loadOrder = 1,
	bridge = nil
}


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
end

return mod