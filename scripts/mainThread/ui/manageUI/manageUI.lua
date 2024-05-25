--- Hammerstone: manageUI.lua
--- Used to capture lifecycle events, and manage the state of custom 'manage' elements.
--- @author SirLich

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local manageUI = {}

function manageUI:init(super, gameUI, controller, hubUI_, world_, logicInterface_)
	super(self, gameUI, controller, hubUI_, world_, logicInterface_)
	uiManager:initManageElements(self)
end

return shadow:shadow(manageUI)