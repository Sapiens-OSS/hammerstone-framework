-- Used for adding locale entries to english
-- @author DecDuck

local localeManager = {}

local english = mjrequire "common/locale/english"

-- Adds an locale entry for the input groups in the key binds menu
function localeManager:addInputGroupMapping(groupKey, groupName)
    mj:insertIndexed(english.localizations, {
        key = "keygroup_" .. groupKey,
        value = groupName
    })
end

-- Adds a locale entry for the key names in the key binds menu
function localeManager:addInputKeyMapping(groupKey, keyKey, value)
    mj:insertIndexed(english.localizations, {
        key = "key_" .. groupKey .. "_" .. keyKey,
        value = value
    })
end


-- Module return
return localeManager