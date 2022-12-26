--- Hammerstone: skill.lua.
--- @Author earmuffs

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local log = mjrequire "hammerstone/logging"

local loaded = false

function mod:onload(skill)

    local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("skill", skill)

	--- Allows adding a skill.
	--- @param key: The key to add, such as 'stoneBuilding'
	--- @param skillInfo: The table containing all fields required to add a skill.
	--- @param skillInfo.identifier
	--- @param skillInfo.name
	--- @param skillInfo.description
	--- @param skillInfo.icon
	--- @param skillInfo.row
	--- @param skillInfo.column
	--- @param skillInfo.startLearned
	--- @param skillInfo.impactedByLimitedGeneralAbility
	function skill:addSkill(key, skillInfo)
        local typeIndexMap = typeMaps.types.skill

		local index = typeIndexMap[key]
		if not index then
            log:schema(nil, "    ERROR: Attempt to add skill type that isn't in typeIndexMap: " .. key)
		else
			if skill.types[key] then
                log:schema(nil, "    WARNING: Overwriting skill type:" .. key)
			end

            local info = {
                key = key,
                index = index,
                name = skillInfo.name,
                description = skillInfo.description,
                icon = skillInfo.icon,
                startLearned = skillInfo.startLearned,
                partialCapacityWithLimitedGeneralAbility = skillInfo.partialCapacityWithLimitedGeneralAbility,
            }

            skill.types[key] = info
            skill.types[index] = info
    
            if skillInfo.startLearned then
                skill.defaultSkills[index] = true
            end

            -- Add skill to the skill tree
            if skill.roleUICommonSkills == nil then
                skill.roleUICommonSkills = {}
            end
            table.insert(skill.roleUICommonSkills, {
                skillTypeIndex = index,
                requiredSkillTypes = skillInfo.requiredSkillTypes,
                row = skillInfo.row,
                column = skillInfo.column,
            })
		end
		return index
	end

    objectManager:generateSkillDefinitions({
        skill = skill
    })
end

return mod