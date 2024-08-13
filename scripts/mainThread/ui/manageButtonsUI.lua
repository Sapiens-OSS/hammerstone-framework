--- Hammerstone: manageButtonsUI.lua
--- Used to initialize the 'manageElements' in the UI Manager.
--- @author SirLich

local manageButtonsUI = { loadOrder = 1 }

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

-- @shadow
function manageButtonsUI:init(super, gameUI, manageUI_, hubUI_, world)
	-- Interface with the uiManager
	uiManager:initManageElementButtons(self, manageUI_)

	-- Super
	super(gameUI, manageUI_, hubUI_, world)
end

return shadow:shadow(manageButtonsUI)