-- Module Setup
local mod = {
	loadOrder = 1
}

-- Includes
local uiManager = mjrequire "hammerstone/ui/uiManager"
local mj = mjrequire "common/mj"

function mod:onload(manageButtonsUI)

	-- Shadow initialization
	local superInit = manageButtonsUI.init
	function manageButtonsUI:init(gameUI, manageUI, hubUI, world)
		-- Super
		superInit(manageButtonsUI, gameUI, manageUI, hubUI, world)

		-- Interface with the uiManager
		uiManager:initManageElements(manageButtonsUI, manageUI)
	end
end

-- Module Return
return mod