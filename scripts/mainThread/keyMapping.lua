local mod = {
    loadOrder = 0
}

function mod:onload(keyMapping)

    local super_mjInit = keyMapping.mjInit

    keyMapping.mjInit = function(self)

        super_mjInit(self)


        keyMapping.addMapping("debug", "showLog", keyMapping.keyCodes.g, nil)

    end


end

return mod