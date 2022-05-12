# uiManager

UI in Sapiens is fairly complex. The uiManager doesn't help you build UIs, it just helps you manage their state. For example:
* Giving you mouse control when the UI is active
* Allowing you to press ESC to close the current UI (coming soon)
* Preventing OTHER ui from showing on top of your currently active UI (coming soon)

### Requiring
```lua
local uiManager = mjrequire "hammerstone/uiManager".
```

### Using
The uiManager relies on the concept of 'views'. A view is a place where UI can be put. For example, a `GameView` covers (almost) the whole screen and captures the mouse.

#### Views

##### GameView
You should build your GameView in it's own module, then register it like this:

```lua
local exampleGameView = mjrequire "exampleMod/exampleGameView"
uiManager:registerGameView(exampleGameView);
```

After registering as a GameView, your UI will start receiving lifecycle, and automatic integration into Sapiens UI state:
```lua
--- Called automatically when the UI gets loaded. 
function exampleGameView:init(gameUI) ... 
```
You should build your UI against gameUI like this: 
```lua
self.mainView = View.new(gameUI.view)
```
Required properties:
* name - The name of the UI. Will be used for some things.
* mainView - The top-level UI View that you add into gameUI (will be used for hiding, etc)
