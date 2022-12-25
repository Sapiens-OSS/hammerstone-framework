--- Hammerstone: skill.lua.
--- @Author earmuffs

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0,

    -- Extra skills passed to roleUICommon.lua to generate skill trees
    roleUICommonSkills = {},
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local log = mjrequire "hammerstone/logging"

local loaded = false

function mod:onload(skill)
	--- Allows adding a skill.
	--- @param key: The key to add, such as 'stoneBuilding'
	--- @param skillInfo: The table containing all fields required to add a skill.
	function skill:addSkill(key, skillInfo)
        local typeIndexMap = typeMaps.types.skill

		local index = typeIndexMap[key]
		if not index then
            log:schema(nil, "    ERROR: Attempt to add skill type that isn't in typeIndexMap: " .. key)
		else
			if skill.types[key] then
                log:schema(nil, "    WARNING: Overwriting skill type:" .. key)
			end
	
			skillInfo.key = key
            skillInfo.index = index
            skill.types[key] = skillInfo
            skill.types[index] = skillInfo
    
            if skillInfo.startLearned then
                skill.defaultSkills[index] = true
            end

            table.insert(skill.roleUICommonSkills, {
                skillTypeIndex = skill.types[key].index,
                row = 1,
                column = 2,
            })
		end
		return index
	end
end

return mod