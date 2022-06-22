--- This file contains a modding interface for creating, displaying, and managing UI elements.
-- It is not intended to build UI elements directly, but to provide a common interface for
-- UI elements to be created and displayed, allowing them to flawlessly combine with
-- base game UI.
-- @author SirLich


-- Module setup
local uiManager = {
	-- The UI Elements that are displayed in the GameSlot
	gameElements = {},

	-- The UI Elements that are displayed in the ActionSlot
	actionElements = {},

	-- The UI Elements that are displayed in the ManageSlot
	manageElements = {},
}


-- Sapiens
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"
local logger = mjrequire "hammerstone/logging"
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
		logger:log("Adding Manage Button: " .. element.name)

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

		mj:log("Outside of lambda: ", element.name)


		uiStandardButton:setClickFunction(button, function()
			mj:log("Inside of lambda ", element.name)

			-- Default behavior is to hide the menu.
			-- After hiding, we must re-show the buttons.
			manageUI:hide()
			manageButtonsUI:setSelectedButton(nil)
			manageButtonsUI.menuButtonsView.hidden = false

			uiStandardButton:setSelected(element.button, true)

			-- Default behavior is to show the element view.
			element.view.hidden = false

			-- manageUI:show()
			-- manageUI.mainView.hidden = true

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

	logger:log("Hiding all manage elements.")

	for _, element in ipairs(self.manageElements) do

		uiStandardButton:setSelected(element.button, false)
		element.view.hidden = true
	end
end


-- ==========================================================================================
-- Action Elements.
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
		element.view.hidden = true
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