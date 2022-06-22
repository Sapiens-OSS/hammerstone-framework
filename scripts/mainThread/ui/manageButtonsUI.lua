--- Shadow of 'manageButtonsUI.lua'
-- Used to initialize the 'manageElements' in the UI Manager.

-- Module Setup
local mod = { loadOrder = 1 }

-- Sapiens
local uiManager = mjrequire "hammerstone/ui/uiManager"
local mj = mjrequire "common/mj"

function mod:onload(manageButtonsUI)
	local superInit = manageButtonsUI.init
	manageButtonsUI.init = function(self, gameUI, manageUI, hubUI, world)
		-- Super
		superInit(manageButtonsUI, gameUI, manageUI, hubUI, world)

		-- Interface with the uiManager
		uiManager:initManageElements(gameUI, manageButtonsUI, manageUI)
	end
end

-- Module Return
return mod