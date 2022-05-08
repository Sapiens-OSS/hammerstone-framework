--- This file shadows actionUI from the main thread.
-- It will communicate with the uiManager to handle the creation of action-views in the action-view-slot.
-- @author SirLich

local mod = {
	loadOrder = 1
}

local uiManager = mjrequire "erectus/ui/uiManager"

function mod:onload(actionUI)

	-- Handle init
	local superInit = actionUI.init
	function actionUI:init(gameUI, hubUI, world)
		-- Call super
		superInit(actionUI, gameUI, hubUI, world)
		-- Interface with the uiManager
		uiManager:initActionElements(gameUI, hubUI, world) -- TODO: Should I pass actionUI here too?
	end

	-- Handle show
	local superShow = actionUI.show
	function actionUI:show()
		-- Call super
		superShow(self)
		-- Interface with the uiManager
		uiManager:showActionElements()
	end

	-- Handle hide
	local superHide = actionUI.hide
	function actionUI:hide()
		-- Call super
		superHide(self)
		-- Interface with the uiManager
		uiManager:hideActionElements()
	end
end

return mod

