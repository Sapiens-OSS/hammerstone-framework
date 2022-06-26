--- Shadow of logicInterface.lua
-- @author SirLich

local mod = {
	loadOrder = 0,

	-- The bridge object for LogicInterface
	bridge = nil
}

function mod:setBridge(bridge)
	mod.bridge = bridge
	mod:registerMainThreadFunctions()

end

function mod:testPrint(message)
	mj:log("PRINTING FROM SERVER CALL: ", message)
end

function mod:registerMainThreadFunctions()

	--- Test
	mod.bridge:registerMainThreadFunction("testPrint", function(message)
		mod:testPrint(message)
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