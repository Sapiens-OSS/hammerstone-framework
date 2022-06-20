--- Shadow of 'manageUI.lua'
--- Used to capture lifecycle events, and manage the state of custom 'manage' elements.
-- @author SirLich

local mod = { loadOrder = 1 }

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"

function mod:onload(manageUI)
	-- Shadow show
	local superShow = manageUI.show
	manageUI.show = function(self, modeIndex)
		superShow(manageUI, modeIndex)
		uiManager:hideAllManageElements()
	end

	-- Shadow hide
	local superHide = manageUI.hide
	manageUI.hide = function(self)
		superHide(manageUI)
		uiManager:hideAllManageElements()
	end
end

return mod