local clientLogicModule = {

}

local serverLogicModule = {
	activeOrderAI = {}
}


function serverLogicModule.completeAction(logicManager, actionTypeIndex, allowCompletion, sapien, orderObject, orderState, actionState, constructableType, requiredLearnComplete)
	-- gets the parameters of activeOrderAI.init like serverGOM, serverSapienAI, etc
	local context = logicManager:getContext("activeOrderAI")

	local terrain = mjrequire "server/serverTerrain"
	local serverStorageArea = mjrequire "server/serverStorageArea"
end

local plannableAction =  {
	description = {
		identifier = "fish", 
		icon = "witchy_icon_fish",
	},
	logic = {
		serverLogic = serverLogic, 
		clientLogic = clientLogic
	},
	-- OR 
	--[[ logic = {
		serverLogic = "witchyFishMod/serverLogic", 
		clientLogic = "witchyFishMod/clientLogic"
	},]]
	components = {
		["hs_plan"] = {}, 
		["hs_order"] = {
		}, 
		["hs_action"] = {
		},
		["hs_actionSequence"] = {
		}, 
		["hs_animation"] = { -- maybe?
		},
		["hs_maintenance"] = { -- maybe?
		}
	}, 
}

return plannableAction