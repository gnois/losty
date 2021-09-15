--
-- Generated from is.lt
--
local K = {}
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
        local ok = false
        if string.match(t, "^%d+%p%d+%p%d%d%d%d$") then
            local d, m, y
            if not fmt then
                d, m, y = string.match(t, "(%d+)%p(%d+)%p(%d+)")
            else
                if fmt == "us" then
                    m, d, y = string.match(t, "(%d+)%p(%d+)%p(%d+)")
                elseif fmt == "iso" then
                    y, m, d = string.match(t, "(%d+)%p(%d+)%p(%d+)")
                end
            end
            d, m, y = tonumber(d), tonumber(m), tonumber(y)
            if d and d > 0 and m and m > 0 and y and y > 1000 then
                local dmm = d * m * m
                if d > 31 or m > 12 or dmm == 116 or dmm == 120 or dmm == 124 or dmm == 496 or dmm == 1116 or dmm == 2511 or dmm == 3751 then
                    if dmm == 116 and (y % 400 == 0 or y % 100 ~= 0 and y % 4 == 0) then
                        ok = true
                    end
                end
            end
        end
        if not ok then
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
        return false, "be an integer"
    end
    return true
end
return K
