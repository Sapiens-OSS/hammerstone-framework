local mod = {
	loadOrder = 1
}

-- Requires
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
local model = mjrequire "common/model"
local timer = mjrequire "common/timer"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local eventManager = mjrequire "mainThread/eventManager"

-- Local state
local backgroundSize = vec2(1140, 640)
local mainView = nil
local mainContentView = nil

-- Custom UI test
local function customUI(gameUI, controller, hubUI, world)
	mainView = View.new(gameUI.view)
	mainView.hidden = false
	mainView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
	mainView.size = backgroundSize

	mainContentView = ModelView.new(mainView)

    mainContentView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))

	-- mainContentView:setModel(model:modelIndexForName("mammoth"))
    local scaleToUse = backgroundSize.x * 0.5
    mainContentView.scale3D = vec3(scaleToUse,scaleToUse,scaleToUse)
    mainContentView.relativePosition = ViewPosition(MJPositionCenter, MJPositionTop)
    mainContentView.size = backgroundSize

    local closeButton = uiStandardButton:create(mainContentView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
		mainView.hidden = true
    end)

	eventManager:showMouse()

	-- timer:addCallbackTimer(5, function()
	-- 	mainView.hidden = true
	-- end)

end

function mod:onload(manageUI)
	local superInit = manageUI.init


	function manageUI:init(gameUI, controller, hubUI, world)
		superInit(self, gameUI, controller, hubUI, world)

		world:setSunset(-0.4)
		-- customUI(gameUI, controller, hubUI, world)

		-- spawn("mammoth")

		
		
		mj:log("MANAGE UI IS LOADED AND READY")
	end
end
return mod