--
-- Generated from str.lau
--
local bit = require("bit")
local split = function(str, pattern, plain)
    local arr = {}
    if pattern and #pattern > 0 then
        local pos, n = 1, #str
        for st, sp in function()
            return string.find(str, pattern, pos, plain)
        end do
            table.insert(arr, string.sub(str, pos, st - 1))
            if sp < st then
                if st > n then
                    break
                end
                pos = st + 1
            else
                pos = sp + 1
            end
        end
        table.insert(arr, string.sub(str, pos))
    end
    return arr
end
local K = {}
K.render = function(str, data)
    return (string.gsub(str, "{([_%w%.]*)}", function(s)
        local keys = split(s, "%.")
        local v = data[keys[1]]
        for i = 2, #keys do
            v = v and v[keys[i]]
        end
        return v or "{" .. s .. "}"
    end))
end
K.safe_equal = function(a, b)
    if not a or not b then
        return false
    end
    if #a ~= #b then
        return false
    end
    local diff = 0
    for i = 1, #a do
        diff = bit.bor(diff, bit.bxor(string.byte(a, i), string.byte(b, i)))
    end
    return diff == 0
end
K.hash = function(str)
    local hash = 0
    if str then
        for c in string.gmatch(str, ".") do
            hash = bit.lshift(hash, 5) - hash + string.byte(c)
        end
    end
    return hash
end
K.each = function(str)
    local p, n = 1, #str
    return function()
        if p <= n then
            local c = string.sub(str, p, p)
            p = p + 1
            return p - 1, c
        end
    end
end
K.contains = function(str, part)
    return string.find(str, part, 1, true) ~= nil
end
K.starts = function(str, part)
    return string.sub(str, 1, string.len(part)) == part
end
K.ends = function(str, part)
    return part == "" or string.sub(str, -string.len(part)) == part
end
K.split = split
K.gsplit = function(str, pattern, plain)
    local pos, n = 1, #str
    local done = false
    return function()
        if done then
            return nil
        end
        local st, sp = string.find(str, pattern, pos, plain)
        if not st then
            done = true
            return string.sub(str, pos)
        end
        local field = string.sub(str, pos, st - 1)
        if sp < st then
            if st > n then
                done = true
            else
                pos = st + 1
            end
        else
            pos = sp + 1
        end
        return field
    end
end
K.findlast = function(str, pattern, plain)
    local curr = 0
    repeat
        local nxt = string.find(str, pattern, curr + 1, plain)
        if nxt then
            curr = nxt
        end
    until not nxt
    if curr > 0 then
        return curr
    end
end
K.lines = function(str)
    local trailing, n = string.gsub(str, ".-\n", "")
    if #trailing > 0 then
        n = n + 1
    end
    return n
end
return K
