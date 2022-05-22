# Logger
The logger is very simple, it merely adds a level of distinction to your log messages.

### Including
```lua
local logger = mjrequire "hammerstone/logging"
```

### Using
Log message:
```lua
logger:log("Example Message")
```
Warn message:
```lua
logger:warn("Example Message")
```
Error message:
```lua
logger:error("Example Message")
```