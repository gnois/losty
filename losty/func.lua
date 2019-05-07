--
-- Generated from func.lt
--
local trace = function(f)
    local helper = function(...)
        print("end", f)
        return ...
    end
    return function(...)
        print("begin", f)
        return helper(f(...))
    end
end
local K = {}
K.map = function(lst, func)
    local result = {}
    for i, v in ipairs(lst) do
        result[i] = func(v)
    end
    return result
end
K.map_pairs = function(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        local key, val = func(k, v)
        result[key] = val
    end
    return result
end
K.filter = function(lst, func)
    local result = {}
    for _, v in ipairs(lst) do
        if func(v) then
            table.insert(result, v)
        end
    end
    return result
end
K.filter_pairs = function(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        if func(v) then
            result[k] = v
        end
    end
    return result
end
K.curry = function(func)
    return function(a)
        return function(...)
            return func(a, ...)
        end
    end
end
K.bindl = function(func, ...)
    local args = {...}
    return function(...)
        return func(unpack(args), ...)
    end
end
K.bindr = function(func, ...)
    local args = {...}
    return function(...)
        return func(..., unpack(args))
    end
end
K.uncurry = function(func)
    return function(...)
        local args = {...}
        local f = func(args[1])
        return f(unpack(args, 2))
    end
end
K.partition = function(lst, func)
    local pass = {}
    local fail = {}
    for _, v in ipairs(lst) do
        if func(v) then
            table.insert(pass, v)
        else
            table.insert(fail, v)
        end
    end
    return pass, fail
end
K.partition_pairs = function(tbl, func)
    local pass = {}
    local fail = {}
    for k, v in pairs(tbl) do
        if func(k, v) then
            pass[k] = v
        else
            fail[k] = v
        end
    end
    return pass, fail
end
K.zip = function(keys, values)
    local tbl = {}
    local count = #keys
    if count ~= #values then
        error("The lists of keys and values provided to zip() must have the same number of elements", 2)
    end
    for i = 1, count do
        local key = keys[i]
        if tbl[key] ~= nil then
            error("Cannot have two identical keys in the list provided to zip()", 2)
        end
        tbl[key] = values[i]
    end
    return tbl
end
K.unzip = function(tbl)
    local keys = {}
    local values = {}
    for k, v in pairs(tbl) do
        keys.insert(k)
        values.insert(v)
    end
    return keys, values
end
K.flatten = function(list)
    local result = {}
    for _, v in ipairs(list) do
        if K.istable(v) then
            local flattened = K.flatten(v)
            for __, fv in ipairs(flattened) do
                table.insert(result, fv)
            end
        else
            table.insert(result, v)
        end
    end
    return result
end
K.head = function(list)
    if list then
        return list[1]
    end
    return nil
end
K.tail = function(list)
    local head, tail = K.decons(list)
    if head then
        return tail
    end
    return nil
end
K.decons = function(list)
    if list then
        local count = #list
        if count > 0 then
            local tail = {}
            for i = 2, count do
                tail[i - 1] = list[i]
            end
            return list[1], tail
        end
    end
    return nil
end
K.foldl = function(func, value, list)
    if list and #list > 0 then
        local head, tail = K.decons(list)
        return K.foldl(func, func(value, head), tail)
    end
    return value
end
K.foldr = function(func, value, list)
    if list and #list > 0 then
        local head, tail = K.decons(list)
        return func(head, K.foldr(func, value, tail))
    end
    return value
end
K.flip = function(func)
    return function(a, b, ...)
        return func(b, a, ...)
    end
end
K.identity = function(...)
    return ...
end
return K
