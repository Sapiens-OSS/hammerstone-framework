--- Hammerstone: manageButtonsUI.lua
--- Used to initialize the 'manageElements' in the UI Manager.
--- @author SirLich

local mod = { loadOrder = 1 }

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"

function mod:onload(manageButtonsUI)
	local superInit = manageButtonsUI.init
	manageButtonsUI.init = function(manageButtonsUI_, gameUI, manageUI, hubUI, world)
		-- Interface with the uiManager
		uiManager:initManageElementButtons(manageButtonsUI, manageUI)

		-- Super
		superInit(manageButtonsUI, gameUI, manageUI, hubUI, world)
	end
end

return mod