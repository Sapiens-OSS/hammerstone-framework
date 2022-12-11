--- Hammerstone: logic.lua
--- The purpose of this file is to facilitate thread communication between the logic thread
--- and the main thread.
--- @author SirLich

local mod = {
	loadOrder = 0, -- load as early as possible.

	-- Variables Exposed by Hammerstone
	bridge = nil,
	clientGOM = nil,
	clientSapien = nil
}

function mod:registerLogicFunctions()
	mod.bridge:registerLogicThreadNetFunction("getWorldValueFromServer", function(key)
		local ret = mod.bridge:callMainThreadFunction("getWorldValueFromServer", key)
		return ret
	end)

	mod.bridge:registerLogicThreadNetFunction("setPrivateShared", function(privateShared)
		--- Called from the server. Keeps the privateShared fresh on the logicThread.

		local saveState = mjrequire "hammerstone/state/saveState"

		if privateShared then
			saveState.logicThreadPrivateShared = privateShared
		end
	end)
end

function mod:onload(logic)

	-- Make this function exposed in hammerstone
	function logic:callServerFunction(functionName, paramTable)
		--- Calls a thread on the dedicated server. 
		--- ParamTable is the arguments you want to pass to the server funttion.
		if logic.bridge ~= nil then
			logic.bridge:callServerFunction(
				functionName,
				paramTable
			)
		else
			mj:warn("Trying to call server function, but bridge is nil: ", functionName)
		end
	end

	local super_setBridge = logic.setBridge
	logic.setBridge = function(self, bridge)
		super_setBridge(self, bridge)

		mod.bridge = bridge
		mod.registerLogicFunctions(self)

		-- Expose
		logic.bridge = bridge
	end

	local super_setClientGOM = logic.setClientGOM
	logic.setClientGOM = function(self, clientGOM, clientSapien)
		super_setClientGOM(self, clientGOM, clientSapien)

		local saveState = mjrequire "hammerstone/state/saveState"
		saveState:initializeLogicThread(clientGOM)

		-- Expose
		logic.clientGOM = clientGOM
		logic.clientSapien = clientSapien
	end
end

return mod