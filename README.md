# Erectus Mod Framework

This framework is a modding API for the upcoming Sapiens video game. It is heavily work-in-progress, so expect many breaking changes.

## Why use a Framework?

The main reason to use Erectus is that it provides you a layer of insulation from Sapiens codebase. This means that when a breaking change is made to Sapiens, the mod-layer can be updated, and all mods that depend on the framework will work again without any changes (within reason).

The secondary reason to use Erectus is that it's *designed as a modding API*, unlike Sapiens. Sapiens is a video game first, and a modding API second. Erectus, on the other hand, can put full focus into topics such as:
 - Clean abstraction layers
 - Data-driven approaches to input handling, UI, etc
 - Reusability and write-once architecture

## How to use Erectus?

Erectus is a mod for Sapiens, just like any other mod. You should download it and place it into your mods folder directly, as I don't intend on doing steam workshop releases any time soon.

**Warning**: If you build a mod that depends on the Erectus framework, any users of the mod are going to need to install Erectus as well. Depending on the popularity of Erectus, this could be more or less annoying.

# Developing with Erectus

To get started, download the mod, and place it into your mods folder. Once 'installed', you can simply reference Erectus files in your own mod. An example mod can be found [here](https://github.com/SirLich/sapiens-cheat-menu).

For Sapiens-related modding, use the offical wiki [here](https://github.com/Majic-Jungle/sapiens-mod-creation/wiki)

## Bootstrapping

Before your mod can run any code, it must bootstrap itself by shadowing game-mode from Sapiens. It is recommended to shadow `mainThread/controller.lua`. Here is an example:

```lua
local mod = {
	loadOrder = 1,
}

function mod:onload(controller)
	local exampleMod = mjrequire "exampleMod/exampleMod"
	exampleMod:init()
end

return mod
```

This example bootstrap calls `exampleMod:init`, which is where you should place all of your setup logic and bindings. This is a good pattern, because it keeps the shadow as minimal as possible.

## uiManager

UI in Sapiens is fairly complex. The uiManager doesn't help you *build* UIs, it just helps you manage their state. For example:
 - Giving you mouse control when the UI is active
 - Allowing you to press `ESC` to close the current UI (coming soon)
 - Preventing OTHER ui from showing on top of your currently active UI (coming soon)

### Requiring 

The uiManager can be required like this: `local uiManager = mjrequire "erectus/uiManager"`. 

### Views

Views are types of UI components. For example, there are `GameView`s which are fullscreen, mouse-capturing menus. There are `(replace here)` views which adds to the main in-game menu. Each view has a seperate function to register. 

#### GameView

You should build your GameView in it's own module, then register it like this:

```lua
local exampleGameView = mjrequire "exampleMod/exampleGameView"
uiManager.registerGameView(exampleGameView);
```

After registering as a GameView, your UI will start receiving lifecycle, and automatic integration into Sapiens UI state:

```lua
--- Called automatically when the UI gets loaded. 
function cheatUI:init(gameUI) ... 
```

You should build your UI against `gameUI` like this: `self.mainView = View.new(gameUI.view)`

Required properties:
 - `name` - The name of the UI. Will be used for some things.
 - `mainView` - The top-level UI View that you add into `gameUI` (will be used for hiding, etc)

