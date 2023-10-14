-- Hammerstone
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local modules = moduleManager.modules

local knowledgeManager = {
    settings = {
        configPath = "/hammerstone/knowledge",
        configFiles = {},
    }, 
    loaders = {}
}

function knowledgeManager:init(ddapiManager_)
    knowledgeManager.loaders.skill = {
		disabled = true,
        rootComponent = "hs_skill",
        moduleDependencies = {
            "skill"
        },
        loadFunction = knowledgeManager.generateSkill
    }
    
    knowledgeManager.loaders.research = {
		disabled = true,
        rootComponent = "hs_research",
        moduleDependencies = {
            "research", 
            "skill", 
            "resource", 
            "order", 
            "constructable", 
            "tool"
        }, 
        dependencies = {
            "skill", 
            "resource", 
            "order", 
            "buildable", 
            "craftable"
        }, 
        loadFunction = knowledgeManager.generateResearch
    }
end

---------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------------
function knowledgeManager:generateSkill(objDef, description, components, identifier, rootComponent)
	local newSkill = {
		name = description:getString("identifier"):asLocalizedString(utils:getNameKey("skill", identifier)), 
		description = description:getStringOrNil("description"):asLocalizedString(utils:getDescriptionKey("skill", identifier)),
		icon = description:getString("icon"), 
		noCapacityWithLimitedGeneralAbility = rootComponent:getBooleanOrNil("limiting"):default(true):getValue(), 
		isDefault = rootComponent:getBooleanOrNil("start_learned"):default(false):getValue(), 
		parentSkills = rootComponent:getTableOrNil("parents"):asTypeIndex(modules["skill"].types), 
		childSkills = rootComponent:getTableOrNil("children"):asTypeIndex(modules["skill"].types), 
	}

	if rootComponent:hasKey("props") then
		newSkill = rootComponent:getTable("props"):mergeWith(newSkill):clear()
	end

	modules["skill"]:addSkill(newSkill)
end

---------------------------------------------------------------------------------------
-- Research
---------------------------------------------------------------------------------------
function knowledgeManager:generateResearch(objDef, description, components, identifier, rootComponent)
	local newResearch = {
		skillTypeIndex = rootComponent:getStringOrNil("skill"):asTypeIndex(modules["skill"].types), 
		requiredToolTypeIndex = rootComponent:getStringOrNil("tool"):asTypeIndex(modules["tool"].types),
		orderTypeIndex = rootComponent:getStringOrNil("order"):asTypeIndex(modules["order"].types), 
		heldObjectOrderTypeIndex = rootComponent:getStringOrNil("order_object"):asTypeIndex(modules["order"].types),
		constructableTypeIndex = rootComponent:getStringOrNil("constructable"):asTypeIndex(modules["constructable"].types),
		allowResearchEvenWhenDark = rootComponent:getBooleanOrNil("need_light"):default(false):with(function (value) return not value end):getValue(), 
		disallowsLimitedAbilitySapiens = rootComponent:getBooleanOrNil("limited"):default(true):getValue(), 
		initialResearchSpeedLearnMultiplier = rootComponent:getNumberValueOrNil("speed"), 
		researchRequiredForVisibilityDiscoverySkillTypeIndexes = rootComponent:getTableOrNil("needed_skills"):asTypeIndex(modules["skill"].types), 
		shouldRunWherePossibleWhileResearching = rootComponent:getBooleanValueOrNil("should_run"), 
	}

	if rootComponent:hasKey("resources") then
		local addConstructables = rootComponent:getBooleanValueOrNil("add_constructables")
		if addConstructables then
			newResearch.resourceTypeIndexes = rootComponent:getTable("resources"):selectKeys(function(key) return key:asTypeIndex(modules["resource"].types) end, true)
			newResearch.constructableTypeIndexArraysByBaseResourceTypeIndex = rootComponent:selectPairs(
				function(key, value)
					return 	key:asTypeIndex(modules["resource"].types), 
							value:asTypeIndex(modules["constructable"].types)
				end, hmtPairsMode.KeysAndValues)
		else
			newResearch.resourceTypeIndexes = rootComponent:getTable("resources"):asTypeIndex(modules["resource"].types)
		end
	end

	if rootComponent:hasKey("props") then
		newResearch = rootComponent:getTable("props"):mergeWith(newResearch):clear()
	end

	modules["research"]:addResearch(identifier, newResearch)
end

return knowledgeManager