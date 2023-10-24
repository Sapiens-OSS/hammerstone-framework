--- Hammerstone: material.lua
--- @author earmuffs, SirLich

local materialShadow = {
	loadOrder = 0
}

-- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

--- @implements
function materialShadow:postload(parent)
    moduleManager:addModule("material", parent)
end

--- Allows adding a material.
--- @param key string: The key to add, such as 'leather'.
--- @param color mjm.vec3: The vec3 containing rgb values, from 0 to 1.
--- @param roughness number: How glossy the material should be, from 0 to 1.
--- @param metal number: How reflective the material should be, from 0 to 1.
function materialShadow:addMaterial(key, color, roughness, metal, materialB)
    local newMaterial = {
        key = key,
        color = color,
        roughness = roughness,
        metal = metal or 0.0
    }

    -- TODO make this use the 'merge' function (move to utils?)
    if materialB ~= nil then
        newMaterial.colorB = materialB.color
        newMaterial.roughnessB = materialB.roughness
        newMaterial.metalB = materialB.metal
    end

    mj:insertIndexed(self.types, newMaterial)
end

--- Adds a material, automatically creating materialB from a mixed variant of the main material
function materialShadow:addMaterialMixed(key, color, roughness, metal, mixRatio)
    
end

return shadow:shadow(materialShadow)