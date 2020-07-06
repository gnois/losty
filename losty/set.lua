--
-- Generated from set.lt
--
local set
set = function(items)
    if items and "table" ~= type(items) then
        error("Argument to set() must be nil, an empty table or a table of {key1 = true, key2 = true, ...}")
    else
        items = {}
    end
    return {
        add = function(key)
            items[key] = true
        end
        , del = function(key)
            items[key] = nil
        end
        , has = function(key)
            return items[key] ~= nil
        end
        , map = function(fx)
            if fx then
                local other = {}
                for k, _ in ipairs(items) do
                    other[fx(k)] = true
                end
                return set(other)
            end
            return set(items)
        end
        , any = function()
            local n = 0
            local x
            for k, _ in pairs(items) do
                n = n + 1
                if math.random() < 1 / n then
                    x = k
                end
            end
            return x
        end
        , each = function()
            return next, items, nil
        end
        , length = function()
            local n = 0
            for _ in pairs(items) do
                n = n + 1
            end
            return n
        end
    }
end
return function(...)
    local args = {...}
    if #args == 1 and "table" == type(args[1]) then
        return set(args[1])
    end
    local s = set()
    for _, v in ipairs(args) do
        s.add(v)
    end
    return s
end
