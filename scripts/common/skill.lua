--- Hammerstone: skill.lua.
--- @Author earmuffs, Witchy

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local skill = {
    moddedSkills = {} -- so that roleUI can find them later
}

function skill:postload(base)
    moduleManager:addModule("skill", base)
end

function skill:addSkill(newSkill)
    typeMaps:insert("skill", self.types, newSkill)
    self.validTypes = typeMaps:createValidTypesArray("skill", self.types)

    table.insert(self.moddedSkills, newSkill)

    if newSkill.isDefault then 
        table.insert(self.defaultSkills, newSkill)
    end
end

return shadow:shadow(skill, 0)