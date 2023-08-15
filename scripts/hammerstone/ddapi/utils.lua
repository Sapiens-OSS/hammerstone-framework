local utils = {}

function utils:assertTable(t, a)
    if t == nil then
        return a
    end

    for key, value in ipairs(a) do
        if t[key] == nil then
            t[key] = value
        end
    end

    return t
end

return utils