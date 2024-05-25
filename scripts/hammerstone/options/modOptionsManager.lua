--- Hammerstone: modOptionsManager.lua
--- @author: Witchy

-- Sapiens

-- Hammerstone
local json = mjrequire "hammerstone/utils/json"
local log = mjrequire "hammerstone/logging"

local world = nil

local modOptionsList = hmt {}
local clientModOptions = nil
local listeners = {}

local databaseKey = "hammerstone_modOptions"

local modOptionsManager = {}

local function saveClientModOptions()
    local clientWorldSettingsDatabase = world:getClientWorldSettingsDatabase()
    clientWorldSettingsDatabase:setDataForKey(clientModOptions, databaseKey)
end

local function optionsErrorHandler(hmTable_, errorCode, parentTable, fieldKey, msg, ...)
    log:schema("options", "ERROR in mod options: " .. msg, " ", debug.traceback())
    os.exit(1)
end

local function initOptionsForMod(configKey, modOptions)
    clientModOptions[configKey] = clientModOptions[configKey] or {}

    for optionName, option in pairs(modOptions) do
        if not clientModOptions[configKey][optionName] and option.default_value then
            clientModOptions[configKey][optionName] = option.default_value
        end

        if option.options then
            initOptionsForMod(configKey, option.options)
        end
    end
end

function modOptionsManager:init(modManager)
    log:schema("options", "Initializing mod options")
    local mods = modManager.enabledModDirNamesAndVersionsByType.world

    for i, mod in ipairs(mods) do
        local optionsPath = mod.path .. "/hammerstone/options"
        modOptionsManager:findOptionsFiles(optionsPath)
    end
end

function modOptionsManager:registerUI()
    log:schema("options", "Registering mod options UI...")

    local uiManager = mjrequire "hammerstone/ui/uiManager"
    local modOptionsUI = mjrequire "hammerstone/options/modOptionsUI"

    modOptionsUI:setModOptionsManager(self)
    uiManager:registerManageElement(modOptionsUI)
end

function modOptionsManager:findOptionsFiles(path)
    local optionsPaths = fileUtils.getDirectoryContents(path)

    for j, optionsPath in ipairs(optionsPaths) do
        local fullPath = path .. "/" .. optionsPath

        if fullPath:find("%.json$") then
            log:schema("options", "Found json mod options file at ", fullPath)
            local jsonString = fileUtils.getFileContents(fullPath)

            local modOptions = hmt(json:decode(jsonString), optionsErrorHandler)
            modOptionsList[modOptions:getStringValue("configKey")] = modOptions
        elseif fullPath:find("%.lua$") then
            log:schema("options", "Found lua mod options file at ", fullPath)
            local chunk, errMsg = loadfile(fullPath)

            if not chunk then
                log:schema("mod options", "ERROR: Failed to load string as lua file: ", errMsg)
                return
            end

            local function errorHandler(errMsg2)
                log:schema("mod options", "ERROR: Failed to execute the lua file: ", errMsg2)
            end

            local ok, modOptions = xpcall(chunk, errorHandler)

            if ok and not modOptions then
                log:schema("mod options", "ERROR: The config file returned nothing")
            elseif ok then
                modOptions = hmt(modOptions, optionsErrorHandler)
                local configKey = modOptions:getStringValue("configKey")
                modOptionsList[configKey] = modOptions

                if modOptions:hasKey("listener") then
                    listeners[configKey] = modOptions:get("listener"):ofType("function"):getValue()
                end
            end
        else
            modOptionsManager:findOptionsFiles(fullPath)
        end
    end
end

function modOptionsManager:setWorld(world_)
    world = world_

    local clientWorldSettingsDatabase = world:getClientWorldSettingsDatabase()
    clientModOptions = clientWorldSettingsDatabase:dataForKey(databaseKey) or {}

    for configKey, modOptions in pairs(modOptionsList) do
        initOptionsForMod(configKey, modOptions:getTable("options"))
    end

    saveClientModOptions()

    local modOptionsUI = mjrequire "hammerstone/options/modOptionsUI"
    modOptionsUI:initOptions()
end

function modOptionsManager:hasOptions()
    return modOptionsList:length() > 0
end

function modOptionsManager:getModOptions()
    return modOptionsList
end

function modOptionsManager:getModOptionsValues(configKey)
    return clientModOptions[configKey]
end

function modOptionsManager:getModOptionsValue(configKey, optionKey)
    return (clientModOptions[configKey] or {})[optionKey]
end

function modOptionsManager:setModOptionsValues(configKey, values)
    clientModOptions[configKey] = values
    saveClientModOptions()

    if listeners[configKey] then listeners[configKey](values) end
end

function modOptionsManager:resetModOptions(modOptions)
    --TODO : Need to plug listener
    clientModOptions[modOptions.configKey] = {}

    initOptionsForMod(modOptions.configKey, modOptions.options)
    saveClientModOptions()

    return clientModOptions[modOptions.configKey]
end

function modOptionsManager:setModOptionsValue(configKey, optionKey, value)
    clientModOptions[configKey][optionKey] = value
    saveClientModOptions()

    if listeners[configKey] then listeners[configKey]({ { optionKey = optionKey, value = value } }) end
end

return modOptionsManager
