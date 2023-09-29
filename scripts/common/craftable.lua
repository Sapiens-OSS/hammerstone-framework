--- Hammerstone: craftable.lua
-- @author SirLich

local mod = {
    -- A low low order makes sense, since we want to make these methods available to other mods.
    loadOrder = 0
}

-- Sapiens
local constructable = mjrequire "common/constructable"
local actionSequence = mjrequire "common/actionSequence"
local tool = mjrequire "common/tool"


-- Hammerstone
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local buildSequenceData = {
    bringOnlySequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
    },
    bringAndMoveSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
        },
    },
    clearObjectsSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
        },
    },
    clearObjectsAndTerrainSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
        },
    },
    plantSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
            actionSequenceTypeIndex = actionSequence.types.dig.index,
            requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
            subModelAddition = {
                modelName = "plantHole"
            },
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
            actionSequenceTypeIndex = actionSequence.types.dig.index,
            requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
            disallowCompletionWithoutSkill = true,
            subModelAddition = {
                modelName = "plantHole"
            },
        },
    },
    fillSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.moveComponents.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.actionSequence.index,
            actionSequenceTypeIndex = actionSequence.types.dig.index,
            requiredToolIndex = tool.types.dig.index, --must be available at the site, so this must be after constructable.sequenceTypes.bringResources
            disallowCompletionWithoutSkill = true,
        },
    },
    clearAndBringSequence = {
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearObjects.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.clearTerrain.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringResources.index,
        },
        {
            constructableSequenceTypeIndex = constructable.sequenceTypes.bringTools.index,
        },
    }
}



function mod:onload(craftable)
    local super_load = craftable.load
    craftable.load = function(craftable_, gameObject, flora)
        super_load(craftable_, gameObject, flora)
        objectManager:markObjectAsReadyToLoad("craftable")
    end

    -- This is just exposing the build sequences from the 'buildable.lua' and making them available in craftable.lua, since this is where
    -- hammerstone currently pulls from.
    for key, value in pairs(buildSequenceData) do
        craftable[key] = value
    end

    moduleManager:addModule("craftable", craftable)
end

return mod