-- --- Hammerstone: evolvingObject.lua.
-- --- @Author SirLich

-- local mod = {
-- 	-- A low load-order makes the most since, as we need these methods to be available
-- 	-- for other shadows.
-- 	loadOrder = 0,
-- }

-- -- Sapiens
-- local typeMaps = mjrequire "common/typeMaps"
-- local gameObject = mjrequire "common/gameObject"

-- -- Hammerstone
-- local log = mjrequire "hammerstone/logging"
-- local objectManager = mjrequire "hammerstone/object/objectManager"
-- local moduleManager = mjrequire "hammerstone/state/moduleManager"

-- function mod:onload(evolvingObject)
-- 	--- Allows adding an evolvingObject.
-- 	-- @param key: The key to add, which must correspond to a gameObject key, such as 'palmFrond'.
-- 	-- @param objectData: The object to add, containing all fields.
-- 	function evolvingObject:addEvolvingObject(key, objectData)
-- 		local index = typeMaps:keyToIndex(key, gameObject.validTypes)

-- 		if not index then
-- 			log:error("Attempting to add evolving object which isn't a GameObject:", key)
-- 		else
-- 			evolvingObject.evolutions[index] = objectData
-- 		end

-- 		return index
-- 	end

-- 	local super_init = evolvingObject.init
-- 	evolvingObject.init = function(evolvingObject, dayLength, yearLength)
-- 		-- Expose
-- 		evolvingObject.dayLength = dayLength
-- 		evolvingObject.yearLength = yearLength
-- 		super_init(evolvingObject, dayLength, yearLength)
		
-- 		objectManager:markObjectAsReadyToLoad("evolvingObject")
-- 	end

-- 	moduleManager:addModule("evolvingObject", evolvingObject)
-- end

-- return mod


-- --------------


-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local objectManager = mjrequire "hammerstone/object/objectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local evolvingObject = {}

-- Called when the file loads (equivalent to function call at the top of onload)
function evolvingObject:preload(self)
	mj:log("ttt PRELOAD")
end

-- Called when the file loads (equivalent to function call at the bottom of onload)
function evolvingObject:postload(self)
	mj:log("ttt POSTLOAD")
	moduleManager:addModule("evolvingObject", self)
end


-- Automatically made available
function evolvingObject:addEvolvingObject(key, objectData)
	mj:log("ttt ADD EVOLVING OBJECT")
	local index = typeMaps:keyToIndex(key, gameObject.validTypes)

	if not index then
		log:error("Attempting to add evolving object which isn't a GameObject:", key)
	else
		self.evolutions[index] = objectData
	end

	return index
end

-- Automatically works as a shadow. Super is passed in.
function evolvingObject:init(super, dayLength, yearLength)
	mj:log("ttt INIT")
	mj:log(self)
	mj:log(super)
	mj:log(dayLength)
	mj:log(yearLength)

	self.dayLength = dayLength
	self.yearLength = yearLength

	super(self, dayLength, yearLength)

	objectManager:markObjectAsReadyToLoad("evolvingObject")
end

local shadow_version = shadow:shadow(evolvingObject, 0)

mj:log("ttt RETURNING OUTER MODULE: ")
mj:log(shadow_version)
return shadow_version