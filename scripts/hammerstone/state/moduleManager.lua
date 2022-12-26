--- Hammerstone: moduleManager.lua
--- Provides a mjrequireless interface to access modules

local moduleManager = {
	--- The list of available Sapiens Core modules.
	modules = {},

	-- List of functions to call when a new module is added
	bindings = {}
}

-- Hammerstone
local log = mjrequire "hammerstone/logging"

local function callBindings()
	for i, f in ipairs(moduleManager.bindings) do
		f(moduleManager.modules)
	end
end

-- Adds a single module into the module manager
function moduleManager:addModule(moduleName, module)
	log:schema("ddapi", "New Module Available: " .. moduleName)
	moduleManager.modules[moduleName] = module

	callBindings()
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

-- Allows you to bind to the module manager, and recieve callback every time
-- a new module is added.
-- @param f function - the function to call
function moduleManager:bind(f)
	table.insert(moduleManager.bindings, f)
end

return moduleManager