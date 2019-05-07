--
-- Generated from str.lt
--
local K = {}
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
K.split = function(str, pattern, plain)
    local arr = {}
    if pattern and #pattern > 0 then
        local pos = 1
        for st, sp in function()
            return string.find(str, pattern, pos, plain)
        end do
            table.insert(arr, string.sub(str, pos, st - 1))
            pos = sp + 1
        end
        table.insert(arr, string.sub(str, pos))
    end
    return arr
end
K.gsplit = function(str, pattern, plain)
    local pos
    local st, sp = 0, 0
    return function()
        if sp then
            pos = sp + 1
            st, sp = string.find(str, pattern, pos, plain)
            if st then
                return string.sub(str, pos, st - 1)
            end
            return string.sub(str, pos)
        end
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
