mjrequire "hammerstone/utils/hmTable"

function getHammerstoneDirectory()
    return getModDirectory("Hammerstone Directory")
end

function getModDirectory(modName)
    local modManager = mjrequire "common/modManager"

    local allMods = modManager.modInfosByTypeByDirName.world
    local enabledMods = modManager.enabledModDirNamesAndVersionsByType.world

    for _, v in pairs(enabledMods) do
        -- Crosscheck both lists so we get the correct mod
        if allMods[v.name].name == modName then
            return allMods[v.name].directory
        end
    end
end

--- http://lua-users.org/wiki/SwitchStatement
--- Usage examples: 
--[[
    c = 1
    switch(c) : caseof {
        [1]   = function (x) print(x,"one") end,
        [2]   = function (x) print(x,"two") end,
        [3]   = 12345, -- this is an invalid case stmt
        default = function (x) print(x,"default") end,
        missing = function (x) print(x,"missing") end,
    }

    print("expect to see 468:  ".. 123 +
        switch(2):caseof{
            [1] = function(x) return 234 end,
            [2] = function(x) return 345 end
        })
]]
function switch(c)
    local swtbl = {
        casevar = c,
        caseof = function (self, code)
            local f
            if (self.casevar) then
                f = code[self.casevar] or code.default
            else
                f = code.missing or code.default
            end

            if f then
                if type(f)=="function" then
                    return f(self.casevar,self)
                else
                    error("case "..tostring(self.casevar).." not a function")
                end
            end
        end
    }
    return swtbl
end

return {}