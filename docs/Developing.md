# Developing

## Bootstrapping
Bootstrap is particularly important with Hammerstone as without it, Hammerstone has no idea that your mod actually exists. The recommended way of bootstrapping is shadowing `controller.lua`, then adding your init function to the init event, like this:
```lua
-- Using the Hammerstone Framework
local mod = {
	loadOrder = 1, -- Can be anything less than 999
}

local eventManager = mjrequire "hammerstone/event/eventManager"
local eventTypes = mjrequire "hammerstone/event/eventTypes"

function mod:onload(controller)
    local exampleMod = mjrequire "exampleMod/exampleMod"
    eventManager:bind(eventTypes.init, exampleMod.init)
end

return mod
```
This format of bootstrapping is particularly good, as it keeps the shadowed file to a minimum. In `exampleMod/exampleMod.lua`, you would have something like this:
```lua
--- Mod entry point for exampleMod
-- Module setup
local exampleMod = {}

-- Includes

(Add includes here)

-- exampleMod entrypoint, called by shadowing 'controller.lua' in the main thread.
function exampleMod:init()
	mj:log("Initializing Example Mod...")
	
	(Add initalisation code here)

	mj:log("Example Mod Initialized.")
end

-- Module return
return exampleMod
```

## Components

Get started with logging with [logger](logger.md).

Get started with UI with [uiManager](uiManager.md).

Get started with input with [inputManager](inputManager.md)

Get started with localisation with [localeManager](localeManager.md)