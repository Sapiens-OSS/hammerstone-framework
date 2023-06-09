--- Hammerstone: uiManager.lua
--- This file contains a modding interface for creating, displaying, and managing UI elements.
--- It is not intended to build UI elements directly, but to provide a common interface for
--- UI elements to be created and displayed, allowing them to flawlessly combine with
--- base game UI.
--- @author SirLich


-- Module setup
local uiManager = {
	-- The UI Elements that are displayed in the GameSlot
	gameElements = {},

	-- The UI Elements that are displayed in the ManageSlot
	manageElements = {},

	-- The UI Elements that are displayed in the ActionSlot
	actionElements = {},

	-- The view container for the action elements
	actionContainerView = nil,

	-- The currently rendered action elements
	actionElementsRendered = {},
}


-- Base
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local logger = mjrequire "hammerstone/logging"

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

-- ==========================================================================================
-- Manage Elements
-- ==========================================================================================

-- This is just an example:
local example_manage_element = {
	name = "The name of the icon",
	icon = "The name of the icon such as 'icon_configure' (points to glb file)",

	-- The function that is called when the element is clicked
	onClick = function(self)
		logger:log("Clicked on " .. self.name)
	end,
}


function uiManager:registerManageElement(element)
	--- Allows you to register a new manage element.
	-- Paramaters are passed via table:
	-- name: The name of the element (eg. "Creative Mode Cheats")
	-- icon: The name of the icon (eg. "icon_configure")
	-- ui: The ui managing the view. Should contain .view.
	-- onClick [Optional]: The function that is called when the element is clicked.

	mj:log("Registering manage element:", element.name)
	table.insert(self.manageElements, element)
end

function uiManager:initManageElements(gameUI, manageButtonsUI, manageUI)
	--- Function that allows Hammerstone to build out the ManageElements based on everything that
	-- has been registered. This is called automatically.
	logger:log("Initializing Manage Elements...")

	-- Local state
	local menuButtonsView = manageButtonsUI.menuButtonsView
	local menuButtonSize = manageButtonsUI.menuButtonSize
	local menuButtonPadding = manageButtonsUI.menuButtonSize * manageButtonsUI.menuButtonPaddingRatio
	local toolTipOffset = manageButtonsUI.toolTipOffset

	-- Capture the last button in the row, as we will place new buttons offset from it.
	local lastButton = manageButtonsUI.menuButtonsByManageUIModeType[#manageButtonsUI.menuButtonsByManageUIModeType]

	-- Loop through all the registered elements and create them.
	for i, element in ipairs(self.manageElements) do
		logger:log("Adding Manage Button: ", element.name)

		-- Initialize the element itself
		element:init(gameUI)

		local button = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize, menuButtonSize), uiStandardButton.types.markerLike)
		button.relativeView = lastButton
		button.relativePosition = ViewPosition(MJPositionOuterRight, MJPositionCenter)

		uiStandardButton:setIconModel(button, element.icon)
		uiToolTip:add(button.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow), element.name, nil, toolTipOffset, nil, button)
		-- uiToolTip:addKeyboardShortcut(testButton.userData.backgroundView, "game", "buildMenu", nil, nil)
		button.baseOffset = vec3(menuButtonPadding, 0, 0)

		-- Save the button for the UI into the button itself.
		element.button = button

		uiStandardButton:setClickFunction(button, function()

			-- Default behavior is to hide the menu.
			-- After hiding, we must re-show the buttons.
			manageUI:hide()
			manageButtonsUI:setSelectedButton(nil)
			manageButtonsUI.menuButtonsView.hidden = false

			uiStandardButton:setSelected(element.button, true)

			-- Default behavior is to show the element view.
			element.view.hidden = false

			-- Custom binding from the mod (optional)
			if element.onClick then
				element.onClick()
			end
		end)

		-- Make sure we pass the new buttons back to the actual UI
		-- table.insert(manageButtonsUI.menuButtonsByManageUIModeType, button)

		-- Update the last button, so we can continue handling offset.
		lastButton = button
	end

	-- Shift the entire view left, to compensate for the new buttons
	local shiftAmmount = #self.manageElements * (menuButtonSize + menuButtonPadding) / 2
	menuButtonsView.baseOffset = menuButtonsView.baseOffset + vec3(-shiftAmmount, 0, 0)
end

function uiManager:hideAllManageElements()
	--- Hides all the manage elements.
	-- This is usually called when switching to a native manage element, or
	-- when the manage UI closes.

	for _, element in ipairs(self.manageElements) do

		uiStandardButton:setSelected(element.button, false)
		element.view.hidden = true
	end
end


-- ==========================================================================================
-- Action Elements.
-- ==========================================================================================

function uiManager:registerActionElement(element)
	--- Action Elements are rendered alongside the radial menu, in a vertical tray.
	--- @param element table - The element class represnting this action element.

	table.insert(uiManager.actionElements, element)
end

function uiManager:initActionView(gameUI, hubUI, world)
	--- This function is called when the Radial Menu is opened for the first time,
	--- and will be used to generate the action element view.
	--- @param gameUI - The general GameUI which holds most/all in-game UI
	--- @param hubUI - Unknown
	--- @param world - Unknown
	
	-- Create a view container for the views to be rendered in.
	self.actionContainerView = View.new(gameUI.view)
	self.actionContainerView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
	self.actionContainerView.baseOffset = vec3(500, 0, 0) -- TODO: Try not to hard-code magic numbers!
end

function uiManager:renderActionElements(baseObjectInfo, multiSelectAllObjects, lookAtPos, isTerrain)
	--- This function is called when the Radial Menu is opened, and will be used to render
	--- the action elements, based on their own internal logic and structure.
	--- TODO: Consider adding a priority function.
	--- @param baseObjectInfo table - Object info for single objects.localecategory
	--- @param multiSelectAllObjects table - Object info for multi-select objects
	--- @param lookAtPos unknown - 
	
	-- Does this destroy the internal view?
	-- TODO: No it doesn't, maybe cause refs are still kept in the container view.
	
	for _, element in ipairs(self.actionElementsRendered) do
		self.actionContainerView:removeSubview(element)
	end
	self.actionElementsRendered = {}

	
	local vertical_offset = 0
	for i,element in ipairs(self.actionElements) do
		if element:visibilityFilter(baseObjectInfo, multiSelectAllObjects, lookAtPos, isTerrain) then
			-- TODO: Consider moving this into it's own function.

			local buttonWidth = 300
			local buttonHeight = 40
			local buttonSize = vec2(buttonWidth, buttonHeight)

			local button = uiStandardButton:create(self.actionContainerView, buttonSize)
			button.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
			button.baseOffset = vec3(0, vertical_offset, 5)
			
			-- You have two options for setting the name
			local elementName = element.name
			if elementName == nil and element.getName ~= nil then
				elementName = element:getName(baseObjectInfo, multiSelectAllObjects, lookAtPos, isTerrain)
			end

			uiStandardButton:setText(button, elementName)
			uiStandardButton:setClickFunction(button, function()
				element:onClick(baseObjectInfo, multiSelectAllObjects, lookAtPos, isTerrain)
			end)

			-- You have two options for setting the iconModelName
			local iconModelName = element.iconModelName
			if iconModelName == nil and element.getIconModelName ~= nil then
				iconModelName = element:getIconModelName(baseObjectInfo, multiSelectAllObjects, lookAtPos, isTerrain)
			end

			if iconModelName then
				uiStandardButton:setIconModel(button, iconModelName)
			end


			table.insert(self.actionElementsRendered, button)
			vertical_offset = vertical_offset + buttonHeight + 5
		end
	end
end

function uiManager:showActionElements()
	self.actionContainerView.hidden = false
end

function uiManager:hideActionElements()
	self.actionContainerView.hidden = true
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
		if element.initGameElement ~= nil then
			element:initGameElement(gameUI)
			element.view.hidden = true
		end
	end
end

-- Calls update on all GameElements
-- @param gameUI: The gameUI object.
function uiManager:updateGameElements(gameUI)
	for _, element in pairs(self.gameElements) do
		if element.updateGameElement ~= nil then element:updateGameElement(gameUI) end
	end
end

-- ==========================================================================================
-- Generic Handling
-- ==========================================================================================

-- TODO: This needs to be made more generic, so that it can be used for other UI elements.
-- TODO: Or maybe it should be moved to a separate file?

--- Whether or not a custom GameView panel is displayed.
function uiManager:hasUIPanelDisplayed()
	for _, element in pairs(self.gameElements) do
		if not element.view.hidden then return true end
	end

	for _, element in pairs(self.manageElements) do
		if not element.view.hidden then return true end
	end
	return false
end

-- Module return
return uiManager