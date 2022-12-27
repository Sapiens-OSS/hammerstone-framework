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

function mod:onload(material)
    --- Allows adding a material.
	--- @param key string: The key to add, such as 'leather'.
	--- @param color mjm.vec3: The vec3 containing rgb values, from 0 to 1.
	--- @param roughness number: How glossy the material should be, from 0 to 1.
	--- @param metal number: How reflective the material should be, from 0 to 1.
    -- TODO: Test these params to prove statements and make them easier to understand
    function material:addMaterial(key, color, roughness, metal)
        mj:insertIndexed(material.types, {
            key = key,
            color = color,
            roughness = roughness,
            metal = metal or 0.0
        })
    end

    -- Load DDAPI
    objectManager:init()

    local moduleManager = mjrequire "hammerstone/state/moduleManager"
	moduleManager:addModule("material", material)
end

return mod