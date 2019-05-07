--
-- Generated from to.lt
--
local K = {}
local to = function(convert, atype)
    return function(t)
        local x = convert(t)
        if x then
            return x
        end
        return nil, "be " .. atype
    end
end
K.str = to(tostring, "a string")
K.num = to(tonumber, "a number")
K.int = to(function(t)
    local i = tonumber(t)
    if i and math.floor(i) == i then
        return i
    end
end, "an integer")
K.capital = function(str)
    str = tostring(str)
    return string.gsub(str, "^%l", string.upper)
end
K.trimmed = function(str)
    str = tostring(str)
    if #str > 200 then
        return str:gsub("^%s+", ""):reverse():gsub("^%s+", ""):reverse()
    else
        return string.match(str, "^%s*(.-)%s*$")
    end
end
return K
