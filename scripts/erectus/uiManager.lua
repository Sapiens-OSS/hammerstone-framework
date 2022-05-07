--- This file contains a modding interface for creating, displaying, and managing UI elements.
-- @author SirLich


-- Module setup
local uiManager = {
	gameViews = {}
}

-- Game Views are UI elements that are displayed in the game world.
-- Example: 'manageUI', 'hubUI', 'chatMessageUI'
-- The view will automatically be initialized on game load.
-- @param view: The view module you are adding.
function uiManager.registerGameView(view)	
	mj:log("New game view registered: " .. view.name)
	uiManager.gameViews[view.name] = view
end

--- Initialization function for the UI Manager.
-- Calls init on all registered game views, and allows them to attach to the gameUI.
-- @param gameUI: The gameUI object.
function uiManager:init(gameUI)
	mj:log("UI Manager initialized: Creating Game Views:")
	for _, view in pairs(uiManager.gameViews) do
		if view.init ~= nil then view:init(gameUI) end
	end
end

--- Update function for the UI Manager.
-- Calls update on all registered game views.
-- @param gameUI: The gameUI object.
function uiManager:update(gameUI)
	for _, view in pairs(uiManager.gameViews) do
		if view.update ~= nil then view:update(gameUI) end
	end
end

--- Whether or not a custom GameView panel is displayed.
function uiManager:hasUIPanelDisplayed()
	for _, view in pairs(uiManager.gameViews) do
		if not view.mainView.hidden then return true end
	end
	return false
end

-- Module return
return uiManager