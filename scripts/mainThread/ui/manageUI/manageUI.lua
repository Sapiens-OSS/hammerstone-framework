--- Hammerstone: manageUI.lua
--- Used to capture lifecycle events, and manage the state of custom 'manage' elements.
--- @author SirLich

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local manageUI = {}

--- @shadow
function manageUI:init(super, gameUI, controller, hubUI, world, logicInterface)
	super(self, gameUI, controller, hubUI, world, logicInterface)
	uiManager:initManageElements(self)
end

return shadow:shadow(manageUI)