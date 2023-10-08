--- Hammerstone: planHelper.lua
-- Hammerstone
local shadow = mjrequire "hammerstone/utils/shadow"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local objectManager = mjrequire "hammerstone/ddapi/objectManager"

local planHelper = {}

function planHelper:postload(base)
	moduleManager:addModule("planHelper", planHelper)
end

function planHelper:init(super)
	super()
	objectManager:markObjectAsReadyToLoad("planHelper_object")
	objectManager:markObjectAsReadyToLoad("planHelper_behavior")
end

--- Allows you to set the available plans for an object.
-- @warning If called before `planHelper:init` then it may be reversed. This is because some object types (i.e., resources) have their plans set on load.
-- @param gameObjectIndex The index of the game object to set the plan for.
-- @param availablePlans The plans to add to this object. e.g, planHelper.availablePlansForNonResourceCarcass
function planHelper:setPlansForObject(gameObjectIndex, availablePlans)
	planHelper.availablePlansFunctionsByObjectType[gameObjectIndex] = availablePlans
end

function planHelper:addTerrainPlan(terrainPlanSettings)
	for _, affectedPlanIndex in ipairs(terrainPlanSettings.affectedPlanIndexes) do
		for i, settings in ipairs(self.terrainPlanSettings) do
			if settings.planTypeIndex == affectedPlanIndex then
				table.insert(settings.affectedPlanIndexes, terrainPlanSettings.planTypeIndex)
				break
			end 
		end 
	end

	table.insert(self.terrainPlanSettings, terrainPlanSettings)
end

return shadow:shadow(planHelper, 0)