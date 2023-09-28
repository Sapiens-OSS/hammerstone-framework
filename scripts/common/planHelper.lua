--- Hammerstone: planHelper.lua

local mod = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/object/legacyObjectManager"

function mod:onload(planHelper)
	moduleManager:addModule("planHelper", planHelper)

	--- Allows you to set the available plans for an object.
	-- @warning If called before `planHelper:init` then it may be reversed. This is because some object types (i.e., resources) have their plans set on load.
	-- @param gameObjectIndex The index of the game object to set the plan for.
	-- @param availablePlans The plans to add to this object. e.g, planHelper.availablePlansForNonResourceCarcass
	function planHelper:setPlansForObject(gameObjectIndex, availablePlans)
		planHelper.availablePlansFunctionsByObjectType[gameObjectIndex] = availablePlans
	end

	local super_init = planHelper.init
	planHelper.init = function()
		super_init()
		objectManager:markObjectAsReadyToLoad("planHelper")
	end
end

return mod