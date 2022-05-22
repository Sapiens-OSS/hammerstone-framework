# localeManager
The localeManager adds readable text to many entries throughout the game. Currently, it only adds to the english locale, but will support more languages in the future. 

### Including
```lua
local localeManager = mjrequire "hammerstone/locale/localeManager"
```

### Using
There are several functions that add different kinds of locales:
##### Input Key Mapping
This locale names a key in the rebind menu:
```lua
localeManager:addInputKeyMapping("groupName", "keyBindName", "Plaintext Name (can use anything)")
```
##### Input Group Name
This locale sets the group name in the rebind menu:
```lua
localeManager:addInputGroupMapping("groupName", "Plaintext Name (can use anything)")
```