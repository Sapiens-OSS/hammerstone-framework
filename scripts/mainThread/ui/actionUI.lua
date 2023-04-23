--- Hammerstone: actionUI.lua
--- It will communicate with the uiManager to handle the creation of action-views in the action-view-slot.
--- @author SirLich

local mod = {
	loadOrder = 1
}

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"

function mod:onload(actionUI)
	
	-- Handle init
	local super_init = actionUI.init
	function actionUI:init(gameUI, hubUI, world)
		super_init(actionUI, gameUI, hubUI, world)
		-- Interface with the uiManager
		uiManager:initActionView(gameUI, hubUI, world)
	end

	-- Handle show
	local super_show = actionUI.show
	function actionUI:show()
		super_show(self)

		-- Interface with the uiManager
		uiManager:showActionElements()
	end

	-- Handle hide
	local super_hide = actionUI.hide
	function actionUI:hide()
		super_hide(self)
		
		-- Interface with the uiManager
		uiManager:hideActionElements()
	end
	
	-- Handle terrain actionUI:showTerrain
	local super_showTerrain = actionUI.showTerrain
	function actionUI.showTerrain(self, vertInfo, multiSelectAllVerts, lookAtPos)
		super_showTerrain(self, vertInfo, multiSelectAllVerts, lookAtPos)

		-- Interface with the uiManager
		uiManager:renderActionElements(vertInfo, multiSelectAllVerts, lookAtPos, true)
	end

	-- Handle object selection
	-- actionUI:showObjects(baseObjectInfo_, multiSelectAllObjects, lookAtPos_)
	local super_showObjects = actionUI.showObjects
	function actionUI:showObjects(baseObjectInfo, multiSelectAllObjects, lookAtPos)
		super_showObjects(self, baseObjectInfo, multiSelectAllObjects, lookAtPos)
		
		-- Interface with the uiManager
		uiManager:renderActionElements(baseObjectInfo, multiSelectAllObjects, lookAtPos, false)
	end
end

return mod

