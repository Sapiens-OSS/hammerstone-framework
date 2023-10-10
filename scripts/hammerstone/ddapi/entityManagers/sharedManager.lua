-- Hammerstone
local log = mjrequire "hammerstone/logging"
local utils = mjrequire "hammerstone/ddapi/ddapiUtils"
local moduleManager = mjrequire "hammerstone/state/moduleManager"

local modules = moduleManager.modules

local sharedManager = {
    settings = {
        configPath = "/hammerstone/shared/",
			unwrap = "hammerstone:global_definitions",
			luaGetter = "getGlobalConfigs",
			configFiles = {},
    }, 
    loaders = {}
}

function sharedManager:init(ddapiManager_)
    sharedManager.loaders.objectSets = {
        shared_unwrap = "hs_object_sets",
        shared_getter = "getObjectSets",
        waitingForStart = true, -- Custom start in serverGOM.lua
        moduleDependencies = {
            "serverGOM"
        },
        loadFunction = sharedManager.generateObjectSets
    }
    
    sharedManager.loaders.resourceGroups = {
        shared_unwrap = "hs_resource_groups",
        shared_getter = "getResourceGroups",
        moduleDependencies = {
            "resource",
            "gameObject"
        },
        dependencies = {
            "resource",
            --"gameObject" -> Handled through typeIndexMap
        },
        loadFunction = sharedManager.generateResourceGroup
    }
    
    sharedManager.loaders.seats = {
        shared_unwrap = "hs_seat_types",
        shared_getter = "getSeatTypes",
        moduleDependencies = {
            "seat"
        },
        loadFunction = sharedManager.generateSeat
    }
    
    sharedManager.loaders.material = {
        shared_unwrap = "hs_materials",
        shared_getter = "getMaterials",
        moduleDependencies = {
            "material"
        },
        loadFunction = sharedManager.generateMaterial
    }
    
    sharedManager.loaders.-- Custom models are esentially handling 
    customModel = {
        waitingForStart = true, -- See model.lua
        shared_unwrap = "hs_model_remaps",
        shared_getter = "getModelRemaps",
        moduleDependencies = {
            "model"
        },
        loadFunction = sharedManager.generateCustomModel
    }
end

---------------------------------------------------------------------------------
-- Object Sets
---------------------------------------------------------------------------------

function sharedManager:generateObjectSets(key)
	modules["serverGOM"]:addObjectSet(key:getValue())
end

---------------------------------------------------------------------------------
-- Resource Groups
---------------------------------------------------------------------------------

function sharedManager:generateResourceGroup(groupDefinition)	
	local identifier = groupDefinition:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local name = groupDefinition:getStringOrNil("name"):asLocalizedString(utils:getNameKey("group", identifier))
	local plural = groupDefinition:getStringOrNil("plural"):asLocalizedString(utils:getPluralKey("group", identifier))

	local newResourceGroup = {
		key = identifier,
		name = name,
		plural = plural,
		displayGameObjectTypeIndex = groupDefinition:getString("display_object"):asTypeIndexMap(modules["gameObject"].typeIndexMap),
		resourceTypes = groupDefinition:getTable("resources"):asTypeIndex(modules["resource"].types, "Resource Types")
	}

	modules["resource"]:addResourceGroup(identifier, newResourceGroup)
end

---------------------------------------------------------------------------------
-- Seat
---------------------------------------------------------------------------------

function sharedManager:generateSeat(seatType)
	local identifier = seatType:getStringValue("identifier")
	log:schema("ddapi", "  " .. identifier)

	local newSeat = {
		key = identifier,
		comfort = seatType:getNumberOrNil("comfort"):default(0.5):getValue(),
		nodes = seatType:getTable("nodes"):select(
			function(node)
				return {
					placeholderKey = node:getStringValue("key"),
					nodeTypeIndex = node:getString("type"):asTypeIndex(modules["seat"].nodeTypes)
				}
			end
		,true):clear()
	}

	modules["typeMaps"]:insert("seat", modules["seat"].types, newSeat)
end

---------------------------------------------------------------------------------
-- Material
---------------------------------------------------------------------------------

function sharedManager:generateMaterial(material)
	local function loadMaterialFromTbl(tbl)
		-- Allowed
		if tbl:isNil() then
			return nil
		end

		return {
			color = tbl:getTable("color"):asVec3(),		
			roughness = tbl:getNumberOrNil("roughness"):default(1):getValue(), 
			metal = tbl:getNumberOrNil("metal"):default(0):getValue(),
		}
	end

	local identifier = material:getString("identifier"):isNotInTypeTable(modules["material"].types):getValue()

	log:schema("ddapi", "  " .. identifier)
	
	local materialData = loadMaterialFromTbl(material)
	local materialDataB = loadMaterialFromTbl(material:getTableOrNil("b_material"))
	modules["material"]:addMaterial(identifier, materialData.color, materialData.roughness, materialData.metal, materialDataB)
end

---------------------------------------------------------------------------------
-- Custom Model
---------------------------------------------------------------------------------

function sharedManager:generateCustomModel(modelRemap)
	local model = modelRemap:getStringValue("model")
	local baseModel = modelRemap:getStringValue("base_model")
	log:schema("ddapi", baseModel .. " --> " .. model)

	local materialRemaps = modelRemap:getTableOrNil("material_remaps"):default({}):getValue()
	
	-- Ensure exists
	if modules["model"].remapModels[baseModel] == nil then
		modules["model"].remapModels[baseModel] = {}
	end
	
	-- Inject so it's available
	modules["model"].remapModels[baseModel][model] = materialRemaps

	return materialRemaps
end

return sharedManager