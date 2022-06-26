--- Shadow of logic.lua
-- @author SirLich

local mod = {
	loadOrder = 1,
	bridge = nil
}

function mod:registerLogicFunctions()
    mod.bridge:registerLogicThreadNetFunction("testPrint", function(message)
        mod.bridge:callMainThreadFunction("testPrint", message)
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