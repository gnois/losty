--
-- Generated from to.lt
--
local K = {try = function(...)
    local funs = {...}
    return function(val)
        local v, err = val
        for _, fn in ipairs(funs) do
            v, err = fn(v)
            if v == nil then
                return nil, "cannot " .. err
            end
        end
        return v
    end
end}
local to = function(fn, atype)
    return function(t)
        local x = fn(t)
        if x then
            return x
        end
        return nil, "convert to " .. atype
    end
end
K.str = to(tostring, "string")
K.num = to(tonumber, "number")
K.int = to(function(t)
    local i = tonumber(t)
    if i and math.floor(i) == i then
        return i
    end
end, "integer")
K.capital = function(str)
    return string.gsub(str, "^%l", string.upper), "capitalize first letter"
end
K.trim = function(str)
    if #str > 200 then
        return str:gsub("^%s+", ""):reverse():gsub("^%s+", ""):reverse(), "trim string"
    else
        return string.match(str, "^%s*(.-)%s*$"), "trim string"
    end
end
return K
