# Developing

## Bootstrapping
Bootstrap is particularly important with Hammerstone as without it, Hammerstone has no idea that your mod actually exists. The recommended way of bootstrapping is shadowing `controller.lua` like this:
```lua
-- Using the Hammerstone Framework
local mod = {
	loadOrder = 1, -- Have to load after Hammerstone (with it's load order of 0)
}

function mod:onload(controller)
	local exampleMod = mjrequire "exampleMod/exampleMod"
	exampleMod:init() -- Call all your actual bootstrap code here from exampleMod/exampleMod
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