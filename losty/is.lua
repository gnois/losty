--
-- Generated from is.lau
--
local K = {}
local DAYS = {
    31
    , 28
    , 31
    , 30
    , 31
    , 30
    , 31
    , 31
    , 30
    , 31
    , 30
    , 31
}
K.null = function(t)
    if t == nil or t == ngx.null then
        return true
    end
    return nil, "be null"
end
K.nonull = function(t)
    if t ~= nil and t ~= ngx.null then
        return true
    end
    return nil, "not be null"
end
local typeof = function(expected)
    return function(v)
        if type(v) == expected then
            return true
        end
        return nil, "be a " .. expected
    end
end
K.tbl = typeof("table")
K.num = typeof("number")
K.str = typeof("string")
K.bool = typeof("boolean")
K.func = typeof("function")
K.array = function(of)
    return function(t)
        if type(t) ~= "table" then
            return false, "be an array"
        end
        local i = 0
        for _ in pairs(t) do
            i = i + 1
            if t[i] == nil then
                return false, "be an array"
            end
            if of then
                local ok, err = of(t[i])
                if not ok then
                    return false, err .. " array"
                end
            end
        end
        return true, i
    end
end
K.len = function(min, max)
    return function(t)
        local l = string.len(t)
        if l < min or l > max then
            return false, "be between " .. min .. " to" .. max .. " characters"
        end
        return true
    end
end
K.atleast = function(min)
    return function(t)
        local l = string.len(t)
        if l < min then
            return false, "be at least " .. min .. " characters"
        end
        return true
    end
end
K.atmost = function(max)
    return function(t)
        local l = string.len(t)
        if l > max then
            return false, "be at most " .. max .. " characters"
        end
        return true
    end
end
K.email = function(t)
    if not string.match(t, "[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?") then
        return false, "be a valid email address"
    end
    return true
end
K.date = function(fmt)
    return function(t)
        local a, b, c = string.match(t, "^(%d+)%p(%d+)%p(%d%d%d%d)$")
        if not a then
            return false, "be a valid date"
        end
        local d, m, y
        if not fmt then
            d, m, y = tonumber(a), tonumber(b), tonumber(c)
        elseif fmt == "us" then
            m, d, y = tonumber(a), tonumber(b), tonumber(c)
        elseif fmt == "iso" then
            y, m, d = tonumber(a), tonumber(b), tonumber(c)
        else
            return false, "be a valid date"
        end
        if m < 1 or m > 12 or d < 1 or y <= 1000 then
            return false, "be a valid date"
        end
        local dim = DAYS[m]
        if m == 2 and (y % 400 == 0 or y % 100 ~= 0 and y % 4 == 0) then
            dim = 29
        end
        if d > dim then
            return false, "be a valid date"
        end
        return true
    end
end
K.has = function(pattern, what)
    return function(t)
        if string.find(t, pattern) then
            return true
        end
        return false, "have " .. (what or pattern)
    end
end
K.match = function(pattern, what)
    return function(t)
        if string.match(t, pattern) then
            return true
        end
        return false, "match " .. (what or pattern)
    end
end
K.min = function(n)
    return function(t)
        if t < n then
            return false, "be greater than " .. n
        end
        return true
    end
end
K.max = function(n)
    return function(t)
        if t > n then
            return false, "be less than " .. n
        end
        return true
    end
end
K.int = function(t)
    if math.floor(t) == t then
        return true
    end
    return false, "be an integer"
end
return K
