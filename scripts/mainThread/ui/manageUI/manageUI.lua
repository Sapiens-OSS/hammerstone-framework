--- Hammerstone: manageUI.lua
--- Used to capture lifecycle events, and manage the state of custom 'manage' elements.
--- @author SirLich

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local manageUI = {}

function manageUI:show(super, modeIndexOrNil, contextOrNil)
	super(self, modeIndexOrNil, contextOrNil)
	uiManager:hideAllManageElements()
end

function manageUI:hide(super)
	super(self)
	uiManager:hideAllManageElements()
end

return shadow:shadow(manageUI)