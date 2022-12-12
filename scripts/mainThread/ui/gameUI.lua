--- hammerstone: gameUI.lua
-- This file shadows many functions, and will interface with the uiManager to display
-- additional UIs, and to handle lifecycle events.
--- @author SirLich

local mod = {
	loadOrder = 1
}

local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"
local clientGameSettings = mjrequire "mainThread/clientGameSettings"

-- Hammerstone
local uiManager = mjrequire "hammerstone/ui/uiManager"
local debugUI   = mjrequire "hammerstone/ui/debugUI"

function mod:onload(gameUI)

	-- Initialize the uiManager
	local superInit = gameUI.init
	function gameUI:init(controller, world)
		superInit(gameUI, controller, world)
		uiManager:initGameElements(gameUI)
		debugUI:load(gameUI, controller)


		local keyMap = {
			[keyMapping:getMappingIndex("game", "testBinding")] = function(isDown, isRepeat)
				if isDown then
					clientGameSettings:changeSetting("renderLog", not clientGameSettings.values.renderLog)
				end
				return true 
			end,
		}


		local function keyChanged(isDown, mapIndexes, isRepeat)
			for i, mapIndex in ipairs(mapIndexes) do
				if keyMap[mapIndex]  then
					if keyMap[mapIndex](isDown, isRepeat) then
						return true
					end
				end
			end
			return false
		end


		eventManager:addEventListenter(keyChanged, eventManager.keyChangedListeners)


	end

	-- Update the uiManager
	local superUpdate = gameUI.update
	function gameUI:update(controller, world)
		superUpdate(gameUI, controller, world)
		uiManager:updateGameElements(gameUI)
	end

	-- Has panel displayed
	local superHasUIPanelDisplayed = gameUI.hasUIPanelDisplayed
	function gameUI:hasUIPanelDisplayed()
		return superHasUIPanelDisplayed(gameUI) or uiManager:hasUIPanelDisplayed()
	end
	
end

return mod