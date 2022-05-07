# Erectus Mod Framework

This framework is a modding API for the upcoming Sapiens video game. It is heavily work-in-progress, so things will definitely change.

## Why use a Framework?

The main reason to use `Erectus` is that it provides you a layer of insulation from Sapiens codebase. This means that when Sapiens updates, the mod-layer can be repaired, and all mods will start working again (within reason).

The secondary reason to use `Erectus` is that it's *designed as a modding API*, unlike Sapiens. Sapiens is a Video Game first, and a Modding Api Second. Erectus on the other hand can put full focus into topics such as:
 - Clean abstraction layers
 - Data-driven approaches to input handling, UI, etc
 - Reusability and write-one architecture

## How to use Erectus?

Erectus is a mod for Sapiens, just like any other mod. You should download it and place it into your mods folder directly, as I don't intend on doing steam workshop releases any time soon.

`Warning:` If you build a mod that relies on the Erectus framework, any users of the mod are going to need to download a copy of Erectus as well. Depending on the popularity of Erectus, this could be more or less annoying.

# Developing with Erectus

To get started, download the mod, and place it into your mods folder. Once 'installed', you can simply reference Erectus files in your own mod. An example mod can be found [here](https://github.com/SirLich/sapiens-cheat-menu).

## Bootstrapping

Before your mod can run *any* code, it must bootstrap itself by shadowing game-mode from Sapiens. I suggest shadowing `mainThread/controller.lua`. Here is an example:

```lua
local mod = {
	loadOrder = 1,
}

function mod:onload(controller)
	local yourMod = mjrequire "yourMod/yourMod"
	yourMod:init()
end

return mod
```

This example bootstrap calls `yourMod:init`, which is where you should place all of your setup logic and bindings. This is a good pattern, because it keeps the shadow as minimal as possible.

## uiManager

UI in Sapiens is fairly complex. The uiManager doesn't help you *build* UIs, it just helps you manage their state. For example:
 - Giving you mouse control when the UI is active
 - Allowing you to press `esc` to close the current UI (coming soon)
 - Preventing OTHER ui from showing on top of your currently active UI (coming soon)

### Requiring 

The Ui Manager can be required like `local uiManager = mjrequire "erectus/uiManager"`. 

### Using

You should build your UI in it's own module. This module can then be registered as a GameView (other views coming soon):

```lua
local cheatUI = mjrequire "cheatManager/cheatUI"
uiManager.registerGameView(cheatUI);
```

After registering as a game-view, your UI will start receiving lifecycle, and automatic integration into Sapiens UI state:

```lua
--- Called automatically when the UI gets loaded. 
function cheatUI:init(gameUI) ... 
```

You should build your UI against `gameUI` like this: `self.mainView = View.new(gameUI.view)`

Required properties:
 - `name` - The name of the UI. Will be used for some things.
 - `mainView` - The top-level UI View that you add into `gameUI` (will be used for hiding, etc)

