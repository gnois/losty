--
-- Generated from check.lt
--
local K = {}
K.check = function(...)
    local funs = {...}
    return function(val)
        local pass = true
        local errs = {}
        for _, fn in ipairs(funs) do
            local ok, msg = fn(val)
            if ok then
                table.insert(errs, true)
            else
                pass = false
                table.insert(errs, msg)
                if ok == nil then
                    return false, errs
                end
            end
        end
        return pass, errs
    end
end
K.message = function(subject, errs)
    local msgs = {}
    for _, v in ipairs(errs) do
        if true ~= v then
            table.insert(msgs, v)
        end
    end
    return subject .. " should " .. table.concat(msgs, " and ")
end
return K
