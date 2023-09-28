-- --- Hammerstone: evolvingObject.lua.
-- --- @Author SirLich

-- Sapiens
local typeMaps = mjrequire "common/typeMaps"
local gameObject = mjrequire "common/gameObject"

-- Hammerstone
local log = mjrequire "hammerstone/logging"
local objectManager = mjrequire "hammerstone/object/legacyObjectManager"
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local shadow = mjrequire "hammerstone/utils/shadow"

local evolvingObject = {}

-- Called when the file loads (equivalent to function call at the bottom of onload)
function evolvingObject:postload(self)
	moduleManager:addModule("evolvingObject", self)
end


-- Automatically made available
function evolvingObject:addEvolvingObject(key, objectData)
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
	self.dayLength = dayLength
	self.yearLength = yearLength

	super(self, dayLength, yearLength)

	objectManager:markObjectAsReadyToLoad("evolvingObject")
end

return shadow:shadow(evolvingObject, 0)