# inputManager
The inputManager is provides an easy way to add input to your mod. 

### Including
```lua
local uiManager = mjrequire "hammerstone/input/inputManager"
```

### Using
The input system in Sapiens is fully rebindable, so we have to use strings to keep track of inputs. There are also categorisation in the form of groups.

#### Groups
The built in groups for Sapiens are as follows:
* Menu [`menu`]: Contains menu navigation controls
* Game [`game`]: Contains hotkeys for opening various in-game menus
* Movement [`movement`]: Contains forward, backwards, left & right, among other things
* Building [`building`]: Contains various building shortcuts & hotkeys. 
* Text Entry [`textEntry`]: Contains keys like send and backspace.
* Multi-select [`multiSelect`]: Contains the subtract modifier for multiselect. 
* Debug [`debug`]: Contains various debug controls
* Cinematic Camera [`cinematicCamera`]: Contains all the control for the cinematic camera

When adding a key mapping, you have to use one of these groups:
```lua
inputManager:addMapping("groupName", ...
```

##### Adding a group
Hammerstone has support for adding a group like this:
```lua
inputManager:addGroup("groupName")
```
To make sure it shows up properly in game, use the [localeManager](localeManager.md)

#### Key Codes
Sapiens uses key codes instead of strings to determine default keys. The keyCodes can be accessed with:
```lua
local keyCodes = mjrequire "mainThread/keyMapping".keyCodes
```
<details>
  <summary>Full list of all keycodes</summary>
##### Every key code
* backspace
* tab
* key_return
* escape
* space
* exclaim
* quotedbl
* hash
* dollar
* percent
* ampersand
* quote
* leftparen
* rightparen
* asterisk
* plus
* comma
* minus
* period
* slash
* key_0
* key_1
* key_2
* key_3
* key_4
* key_5
* key_6
* key_7
* key_8
* key_9
* colon
* semicolon
* less
* equals
* greater
* question
* at
* leftbracket
* backslash
* rightbracket
* caret
* underscore
* backquote
* a
* b
* c
* d
* e
* f
* g
* h
* i
* j
* k
* l
* m
* n
* o
* p
* q
* r
* s
* t
* u
* v
* w
* x
* y
* z
* delete
* capslock
* f1
* f2
* f3
* f4
* f5
* f6
* f7
* f8
* f9
* f10
* f11
* f12
* printscreen
* scrolllock
* pause
* insert
* home
* pageup
* key_end
* pagedown
* right
* left
* down
* up
* numlockclear
* kp_divide
* kp_multiply
* kp_minus
* kp_plus
* kp_enter
* kp_1
* kp_2
* kp_3
* kp_4
* kp_5
* kp_6
* kp_7
* kp_8
* kp_9
* kp_0
* kp_period
* application
* power
* kp_equals
* f13
* f14
* f15
* f16
* f17
* f18
* f19
* f20
* f21
* f22
* f23
* f24
* execute
* help
* menu
* select
* stop
* again
* undo
* cut
* copy
* paste
* find
* mute
* volumeup
* volumedown
* kp_comma
* kp_equalsas400
* alterase
* sysreq
* cancel
* clear
* prior
* return2
* separator
* out
* oper
* clearagain
* crsel
* exsel
* kp_00
* kp_000
* thousandsseparator
* decimalseparator
* currencyunit
* currencysubunit
* kp_leftparen
* kp_rightparen
* kp_leftbrace
* kp_rightbrace
* kp_tab
* kp_backspace
* kp_a
* kp_b
* kp_c
* kp_d
* kp_e
* kp_f
* kp_xor
* kp_power
* kp_percent
* kp_less
* kp_greater
* kp_ampersand
* kp_dblampersand
* kp_verticalbar
* kp_dblverticalbar
* kp_colon
* kp_hash
* kp_space
* kp_at
* kp_exclam
* kp_memstore
* kp_memrecall
* kp_memclear
* kp_memadd
* kp_memsubtract
* kp_memmultiply
* kp_memdivide
* kp_plusminus
* kp_clear
* kp_clearentry
* kp_binary
* kp_octal
* kp_decimal
* kp_hexadecimal
* lctrl
* lshift
* lalt
* lgui
* rctrl
* rshift
* ralt
* rgui
* mode
* audionext
* audioprev
* audiostop
* audioplay
* audiomute
* mediaselect
* www
* mail
* calculator
* computer
* ac_search
* ac_home
* ac_back
* ac_forward
* ac_stop
* ac_refresh
* ac_bookmarks
* brightnessdown
* brightnessup
* displayswitch
* kbdillumtoggle
* kbdillumdown
* kbdillumup
* eject
* sleep
</details>

#### Adding a mapping
The full process for adding a mapping is as follows. First, add the mapping:
```lua
inputManager:addMapping("groupName", "keyBindName", keyCodes.[default key], keyCodes.[secondary key] or nil)
```
Next, use the [localeManager](localeManager.md) to make sure the names show up properly in-game. Then, bind a function to it:
```lua
inputManager:addKeyChangedCallback("groupName", "keyBindName", function (isDown, isRepeat)
   -- Do whatever you want
end)
```
Everything should be working now!

