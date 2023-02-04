--- Hammerstone: material.lua
--- @author earmuffs

local mod = {
	loadOrder = 1
}

-- Math
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3

-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

function mod:onload(material)
    --- Allows adding a material.
	--- @param key string: The key to add, such as 'leather'.
	--- @param color mjm.vec3: The vec3 containing rgb values, from 0 to 1.
	--- @param roughness number: How glossy the material should be, from 0 to 1.
	--- @param metal number: How reflective the material should be, from 0 to 1.
    function material:addMaterial(key, color, roughness, metal, materialB)
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

        mj:insertIndexed(material.types, newMaterial)
    end

    -- Load DDAPI
    objectManager:init()

	moduleManager:addModule("material", material)
end

return mod