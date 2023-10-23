--- Hammerstone: serverGOM.lua
--- @author SirLich

--- Hammerstone
local moduleManager = mjrequire "hammerstone/state/moduleManager"
local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"

local mod = {
    loadOrder = 1,
}

--- Allows you to add a new 'object set'
--- @param key  - The key to add, such as "Moas"
local function addObjectSet(serverGOM, key)
	serverGOM.objectSets[key] = serverGOM:createObjectSet(key)
end


function mod:onload(serverGOM)
	serverGOM.addObjectSet = addObjectSet

	-- DDAPI Stuff
	local super_createObjectSets = serverGOM.createObjectSets
    serverGOM.createObjectSets = function(serverGOM_)
        super_createObjectSets(serverGOM_)
		ddapiManager:markObjectAsReadyToLoad("objectSets")
	end

	moduleManager:addModule("serverGOM", serverGOM)

end

return mod