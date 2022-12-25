--- Hammerstone: roleUICommon.lua.
--- @Author earmuffs

local mod = {
	-- A low load-order makes the most since, as we need these
	-- methods to be available for other shadows.
	loadOrder = 0
}

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local skill = mjrequire "common/skill"

function mod:onload(roleUICommon)

    local super_mjInit = roleUICommon.mjInit
    roleUICommon.mjInit = function()
        super_mjInit()
        
        for _, v in pairs(skill.roleUICommonSkills) do
            roleUICommon.skillUIColumns[v.column][v.row] = {
                skillTypeIndex = v.skillTypeIndex
            }
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