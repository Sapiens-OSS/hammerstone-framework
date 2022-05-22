# uiManager

UI in Sapiens is fairly complex. The uiManager doesn't help you build UIs, it just helps you manage their state. For example:
* Giving you mouse control when the UI is active
* Allowing you to press ESC to close the current UI (coming soon)
* Preventing OTHER ui from showing on top of your currently active UI (coming soon)

### Requiring
```lua
local uiManager = mjrequire "hammerstone/ui/uiManager"
```

### Using
The uiManager relies on the concept of 'views'. A view is a place where UI can be put. For example, a `GameView` covers (almost) the whole screen and captures the mouse.

#### Elements

##### Action Elements
Action Elements are rendered beside the radial menu that appears when selecting an object in the world. To register an Action Element, call `registerActionElement` on the `uiManager` like this:
```lua
local exampleActionElement = mjrequire "exampleMod/exampleActionElement"
uiManager:registerActionElement(exampleActionElement);
```
The Action Element module should look something like this:
```lua
-- Module setup
local exampleActionElement = {
	-- Required by the UI Manager
	view = nil,

	--  Required by the UI Manager
	name = "Example Action Element"
}

-- Requires
-- Add requires here

-- This function is called automatically from the UI manager
function exampleActionElement:initActionElement(viewContainer, gameUI, hubUI, world)
	-- Create a parent container
	self.view = View.new(viewContainer)

    -- Add any button/other UI components here
end

-- Module return
return exampleActionElement
```

##### Game Elements
Game Elements are shown nearly fullscreen to the user. To register a Game Elemenet, call `registerGameElement` on the `uiManager` like this:
```lua
local exampleGameElement = mjrequire "exampleMod/exampleGameElement"
uiManager:registerActionElement(exampleGameElement);
```
The Game Element module should look something like this:
```lua
local exampleActionElement = {
    gameUI = nil,
	name = "exampleActionElement",
	view = nil,
}

-- Requires
local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
-- Add more requires here

-- Local state
local backgroundWidth = 1140
local backgroundHeight = 640
local backgroundSize = vec2(backgroundWidth, backgroundHeight)

-- Called when the UI needs to be generated
function exampleActionElement:initGameElement(gameUI)
    self.view = View.new(gameUI.view)
	self.view.size = backgroundSize
	self.view.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
end

-- Called every frame
function exampleActionElement:updateGameElement(gameUI)
	
end

return exampleActionElement
```