--- Hammerstone: actionUI.lua
--- It will communicate with the uiManager to handle the creation of action-views in the action-view-slot.
--- @author SirLich

local actionUI = {}

-- Sapiens
local inspectUI = mjrequire "mainThread/ui/inspect/inspectUI"

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local gameUI = nil

-- Handle init
function actionUI:init(super, gameUI_, hubUI, world)
	super(self, gameUI_, hubUI, world)

	gameUI = gameUI_

	-- Interface with the uiManager
	uiManager:initActionView(gameUI, hubUI, world)
end

-- Handle show
function actionUI:show(super)
	super(self)

	-- Interface with the uiManager
	uiManager:showActionElements()
end

-- Handle hide
function actionUI:hide(super)
	super(self)

	-- Interface with the uiManager
	uiManager:hideActionElements()
end

-- Handle terrain actionUI:showTerrain
function actionUI:showTerrain(super, vertInfo, multiSelectAllVerts, lookAtPos)
	super(self, vertInfo, multiSelectAllVerts, lookAtPos)

	-- Interface with the uiManager
	uiManager:renderActionElements(vertInfo, multiSelectAllVerts, lookAtPos, true)
end

-- Handle object selection
function actionUI:showObjects(super, baseObjectInfo, multiSelectAllObjects, lookAtPos)
	super(self, baseObjectInfo, multiSelectAllObjects, lookAtPos)
		
	-- Interface with the uiManager
	uiManager:renderActionElements(baseObjectInfo, multiSelectAllObjects, lookAtPos, false)
end

-- replace zoomShortcut with proper handling following patch changes
function actionUI:zoomShortcut(super)
    if inspectUI.baseObjectOrVertInfo then
        gameUI:followObject(inspectUI.baseObjectOrVertInfo, inspectUI.isTerrain, {dismissAnyUI = true})
    end
end

-- replace multiselectShortcut with proper handling following patch changes
function actionUI:multiselectShortcut(super)
    if inspectUI.baseObjectOrVertInfo then
        gameUI:selectMulti(inspectUI.baseObjectOrVertInfo, inspectUI.isTerrain)
    end
end

return shadow:shadow(actionUI)

