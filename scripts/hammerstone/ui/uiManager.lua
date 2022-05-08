--- This file contains a modding interface for creating, displaying, and managing UI elements.
-- @author SirLich


-- Module setup
local uiManager = {
	-- The UI Elements that are displayed in the GameSlot
	gameElements = {},

	-- The UI Elements that are displayed in the ActionSlot
	actionElements = {},
}

-- Requires
local logger = mjrequire "hammerstone/logging"
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2


-- ==========================================================================================
-- Action Elements Elements.
-- ==========================================================================================

--- Action Elements are rendered alongside the radial menu, in a vertical tray.
-- @param UI - The UI to add to the action tray. Must contain: view, name, and f:initActionUI(gameUI, hubUI, world)
-- TODO: We need to make views contextually aware of what is clicked (when to display)
function uiManager:registerActionElement(element)
	logger:log("Registering ActionSlot Element: " .. element.name)
	uiManager.actionElements[element.name] = element
end

--- Initialization function for Action Views.
-- This function is called when the Radial Menu is opened for the first time, amd will be used to create all modded Action Views.
-- @param actionUI - The action UI, which owns the radial menu.
-- @param gameUI - The general GameUI which holds most/all in-game UI
-- @param hubUI - Unknown
-- @param world - Unknown
function uiManager:initActionElements(gameUI, hubUI, world)
	logger:log("UI Manager: Initializing action elements [" .. #uiManager.actionElements .. "]")

	-- Create a view container for the views to be rendered in.
	local actionViewContainer = View.new(gameUI.view)
    actionViewContainer.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
	actionViewContainer.baseOffset = vec3(500, 0, 0) -- TODO: Try not to hard-code magic numbers

	-- Render the Elements into this new container
	for _, element in pairs(uiManager.actionElements) do
		element:initActionElement(actionViewContainer, gameUI, hubUI, world)
	end
end

function uiManager:showActionElements()
	logger:log("UI Manager: Showing action elements [" .. #uiManager.actionElements .. "]")
	for _, element in pairs(uiManager.actionElements) do
		-- Element may implement 'show' to customize its behavior
		if element.show ~= nil then element:show() else element.view.hidden = false end
	end
end

function uiManager:hideActionElements()
	logger:log("UI Manager: Hiding action elements [" .. #uiManager.actionElements .. "]")
	for _, element in pairs(uiManager.actionElements) do
		-- Element may implement 'hide' to customize its behavior
		if element.hide ~= nil then element:hide() else element.view.hidden = true end
	end
end

-- ==========================================================================================
-- Game Elements.
-- ==========================================================================================

--- Game Elements are UI elements that are displayed in the game world.
-- Example: 'manageUI', 'hubUI', 'chatMessageUI'
-- The view will automatically be initialized on game load.
-- @param element: The element you are adding. Must contain: view, name, and f:initGameElement(gameUI, hubUI, world)
function uiManager:registerGameElement(element)
	logger:log("New game view registered: " .. element.name)
	self.gameElements[element.name] = element
end

-- Calls init on all GameElements.
-- You should attach your new view to the gameUI.view.
-- @param gameUI: The gameUI object.
function uiManager:initGameElements(gameUI)
	logger:log("UI Manager: Initializing Game elements [" .. #self.gameElements .. "]")
	for _, element in pairs(self.gameElements) do
		if element.initGameElement ~= nil then element:initGameElement(gameUI) end
	end
end

-- Calls update on all GameElements
-- @param gameUI: The gameUI object.
function uiManager:updateGameElements(gameUI)
	for _, element in pairs(self.gameElements) do
		if element.updateGameElement ~= nil then element:updateGameElement(gameUI) end
	end
end

-- TODO: This needs to be made more generic, so that it can be used for other UI elements.
-- TODO: Or maybe it should be moved to a separate file.

--- Whether or not a custom GameView panel is displayed.
function uiManager:hasUIPanelDisplayed()
	for _, element in pairs(self.gameElements) do
		if not element.view.hidden then return true end
	end
	return false
end

-- Module return
return uiManager