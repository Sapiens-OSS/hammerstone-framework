--- Hammerstone: manageButtonsUI.lua
--- Used to initialize the 'manageElements' in the UI Manager.
--- @author SirLich

local manageButtonsUI = { loadOrder = 1 }

-- Vanilla
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiToolTip = mjrequire "mainThread/ui/uiCommon/uiToolTip"

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local shadow = mjrequire "hammerstone/utils/shadow"
local uiController = mjrequire "hammerstone/ui/uiController"

-- @shadow
function manageButtonsUI:init(super, gameUI, manageUI, hubUI_, world)
	-- Interface with the uiManager
	uiManager:initManageElementButtons(self, manageUI)

	-- Add to menuButtonCount to get the right spacing
	for modeIndex, modeType in ipairs(manageUI.modeTypes) do
		if modeIndex == manageUI.modeTypes.build or
			modeIndex == manageUI.modeTypes.options or
			modeIndex == manageUI.modeTypes.tribe then
			goto continue
		end

		self.menuButtonCount = self.menuButtonCount + 1
		mj:log("inserted " .. modeType .. " at modeIndex " .. modeIndex .. " into manage button ui")
		::continue::
	end

	-- Super
	super(self, gameUI, manageUI, hubUI_, world)

	-- Copy padding calculations from vanilla base game
	-- May need updating when the padding changes
	local menuButtonSize = self.menuButtonSize
    local menuButtonPaddingRatio = self.menuButtonPaddingRatio

    local menuButtonPadding = menuButtonSize * menuButtonPaddingRatio

	local toolTipOffset = self.toolTipOffset

	-- Fetch view we want to insert our buttons into
	local menuButtonsViewResults = uiController:searchViews("menuButtonsView")
	local menuButtonsView = menuButtonsViewResults[1]

	-- Add our buttons
	local lastButton = self.menuButtonsByManageUIModeType[manageUI.modeTypes.options] -- anchor our buttons to the (current) last button
	for modeIndex in ipairs(manageUI.modeTypes) do
		-- avoid re-inserting the game's manage buttons
		if modeIndex == manageUI.modeTypes.build or
			modeIndex == manageUI.modeTypes.options or
			modeIndex == manageUI.modeTypes.tribe then
			goto continue
		end

		mj:log("manageButtonsUI: modeIndex=", modeIndex, " title=", manageUI.modeInfos[modeIndex].title)
		table.insert(self.orderedModes, modeIndex)

		local horizontalPos =
			MJPositionOuterRight -- (removed because we can never handle modeIndex 1) modeIndex == 1 and MJPositionInnerLeft or MJPositionOuterRight

		local button = uiStandardButton:create(menuButtonsView, vec2(menuButtonSize, menuButtonSize),
			uiStandardButton.types.markerLike)
		button.relativePosition = ViewPosition(horizontalPos, MJPositionCenter)
		button.baseOffset = vec3(menuButtonPadding, 0, 0)

		uiStandardButton:setIconModel(button, manageUI.modeInfos[modeIndex].icon)
		uiToolTip:add(button.userData.backgroundView, ViewPosition(MJPositionCenter, MJPositionBelow),
			manageUI.modeInfos[modeIndex].title, nil, toolTipOffset, nil, button)

		if lastButton then
			button.relativeView = lastButton
		end

		if manageUI.modeInfos[modeIndex].keyboardShortcut then
			uiToolTip:addKeyboardShortcut(button.userData.backgroundView, "game",
				manageUI.modeInfos[modeIndex].keyboardShortcut, nil, nil)
		end

		uiStandardButton:setClickFunction(button, function()
			manageUI:show(modeIndex)
			if manageUI.modeInfos[modeIndex].onClick then
				manageUI.modeInfos[modeIndex].onClick()
			end
		end)

		self.menuButtonsByManageUIModeType[modeIndex] = button
		lastButton = button
		::continue::
	end
end

return shadow:shadow(manageButtonsUI)
