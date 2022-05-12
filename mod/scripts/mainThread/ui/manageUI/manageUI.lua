-- Module Setup
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

local logger = mjrequire "hammerstone/logging"

-- Local state

-- Shadow
function mod:onload(manageUI)

	-- Handl initalization
	local superInit = manageUI.init
	function manageUI:init(gameUI, controller, hubUI, world)
		superInit(self, gameUI, controller, hubUI, world)
	end
end


-- Module Return
return mod