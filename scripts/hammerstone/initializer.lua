--- Hammerstone : initializer.lua
--- Provides an entry point for other scripts.
--- This script is run at the earliest stage possible of the game's life cycle
--- @author Witchy

mjrequire "hammerstone/globals"

local ddapiManager = mjrequire "hammerstone/ddapi/ddapiManager"
local modOptionsManager = mjrequire "hammerstone/options/modOptionsManager"

local initilizer = {}

function initilizer:init(modManager)
    ddapiManager:init(modManager)
    modOptionsManager:init(modManager)
end

return initilizer