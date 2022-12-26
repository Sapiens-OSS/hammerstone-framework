--- Hammerstone: moduleManager.lua
--- Provides a mjrequireless interface to access modules

local moduleManager = {
	--- The list of available Sapiens Core modules.
	modules = {}
}

-- Adds a single module into the module manager
function moduleManager:addModule(moduleName, module)
	log:schema("ddapi", "New Module Available: " .. moduleName)
	moduleManager.modules[moduleName] = module
end

-- Adds a table of modules into the module manager
function moduleManager:addModules(modulesTable)
	for k, v in pairs(modulesTable) do
		moduleManager:addModule(k, v)
	end
end

function moduleManager:get(moduleName)
	return moduleManager.modules[moduleName]
end

return moduleManager