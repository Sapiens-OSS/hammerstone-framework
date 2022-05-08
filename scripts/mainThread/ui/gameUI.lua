--- Shadow of Sapiens gameUI.lua
-- This file shadows many functions, and will interface with the uiManager to display
-- additional UIs, and to handle lifecycle events.
-- @author SirLich

local mod = {
	loadOrder = 1
}

local uiManager = mjrequire "erectus/ui/uiManager"

function mod:onload(gameUI)

	-- Initialize the uiManager
	local superInit = gameUI.init
	function gameUI:init(controller, world)
		superInit(self, controller, world)
		uiManager:init(self)
	end

	-- Update the uiManager
	local superUpdate = gameUI.update
	function gameUI:update(controller, world)
		superUpdate(self, controller, world)
		uiManager:update(self)
	end

	-- Has panel displayed
	local superHasUIPanelDisplayed = gameUI.hasUIPanelDisplayed
	function gameUI:hasUIPanelDisplayed()
		return superHasUIPanelDisplayed(self) or uiManager:hasUIPanelDisplayed()
	end
	
end

return mod