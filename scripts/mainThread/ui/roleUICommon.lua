--- Hammerstone: roleUICommon.lua.
--- @Author earmuffs

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0
}

-- Hammerstone
local log = mjrequire "hammerstone/logging"

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local skill = mjrequire "common/skill"

function mod:onload(roleUICommon)

    local super_mjInit = roleUICommon.mjInit
    roleUICommon.mjInit = function()
        super_mjInit()

        if skill.roleUICommonSkills ~= nil then
            for _, v in pairs(skill.roleUICommonSkills) do
                if skill.types[v.skillTypeIndex] ~= nil then
                    if roleUICommon.skillUIColumns[v.column][v.row] == nil
                        and roleUICommon.skillUIColumns[v.column][v.row].skillTypeIndex == nil then
                        
                        roleUICommon.skillUIColumns[v.column][v.row] = {
                            skillTypeIndex = v.skillTypeIndex,
                            requiredSkillTypes = v.requiredSkillTypes,
                        }
                    else
                        local existingSkill = skill.types[roleUICommon.skillUIColumns[v.column][v.row].skillTypeIndex].key
                        log:schema("ddapi", "ERROR: Position at (" .. v.row .. ", " .. v.column .. ") is already used by: " .. existingSkill)
                    end
                else
                    log:schema("ddapi", "ERROR: Skill was not properly created")
                end
            end
        end

        roleUICommon:createDerivedTreeDependencies()
    end

    local waited = false
    local super_createDerivedTreeDependencies = roleUICommon.createDerivedTreeDependencies
    roleUICommon.createDerivedTreeDependencies = function()
        if not waited then
            waited = true
        else
            -- Only call this the second time
            super_createDerivedTreeDependencies()
        end
    end
end

return mod