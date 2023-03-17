--- Hammerstone: locale.lua
--- @author earmuffs

local mod = {
	loadOrder = 1
}


local function getOrReturn(key)
end

function mod:onload(locale)

    -- Turn this on for verbose log output
    local debug = false

    local addedLocaleData = {}
    local currentLocaleKey = nil

    --- Fetches a localization string, or returns the string itself.
    --- @param key - The localization key, such as 'skill_gathering_description'
    function locale:getUnchecked(key)
        local potential_translation = locale:get(key)

        if potential_translation:find("missing localization", 1, true) ~= nil then
            return key
        end
        
        return potential_translation
    end

    -- Use this method to add dynamic locale keys
    function locale:addKey(localeKey, key, value)

        -- Only add the key if the locale exists
        if not locale.availableLocalizations[localeKey] then
            if debug then
                mj:log("Locale not available for key " .. localeKey)
            end
            return
        end

        if not addedLocaleData[localeKey] then
            addedLocaleData[localeKey] = {}
        end

        addedLocaleData[localeKey][key] = value
    end

    local super_get = locale.get
    locale.get = function(_locale, key, inputsArrayOrNil)
        
        local localeData = addedLocaleData[currentLocaleKey]

        -- Check if requested locale and key exist
        if localeData and localeData[key] then
            if type(localeData[key]) == "function" then
                return localeData[key](inputsArrayOrNil)
            else
                return localeData[key]
            end
        end

        -- If an added key doesn't exist
        return super_get(_locale, key, inputsArrayOrNil)
    end

    local super_loadLocalizations = locale.loadLocalizations
    locale.loadLocalizations = function(_locale, localizationsKey)
        currentLocaleKey = localizationsKey
        return super_loadLocalizations(_locale, localizationsKey)
    end

    if debug then
        local super_mjInit = locale.mjInit
        locale.mjInit = function()
            super_mjInit()

            locale:addKey("en_us", "localization_testkey_1", "Hammerstone localization test 1 loaded.")
            locale:addKey("en_us", "localization_testkey_2", function(values)
                return values.string
            end)
            mj:log(locale:get("localization_testkey_1"))
            mj:log(locale:get("localization_testkey_2", { string = "Hammerstone localization test 2 loaded." }))

            locale:addKey("fr_fr", "localization_testkey_1", "Hammerstone test 1 de localisation chargé.")
            mj:log(addedLocaleData)
        end
    end
end

return mod
