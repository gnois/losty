--
-- Generated from tbl.lt
--
local dump = function(value)
    local seen = {}
    local dmp
    dmp = function(val, depth)
        if not depth then
            depth = 0
        end
        if val == nil then
            return "nil\n"
        end
        if val == ngx.null then
            return "<ngx.null>\n"
        end
        local t = type(val)
        if t == "table" then
            if seen[val] then
                return "recursive <" .. tostring(val) .. ">..."
            end
            seen[val] = true
            depth = depth + 1
            local lines, len = {}, 0
            for k, v in pairs(val) do
                len = len + 1
                lines[len] = string.rep(" ", depth * 2) .. tostring(k) .. " = " .. dmp(v, depth)
            end
            seen[val] = false
            if len > 0 then
                return "{\n" .. table.concat(lines, "\n") .. "\n" .. string.rep(" ", (depth - 1) * 2) .. "}"
            end
            return "{}"
        end
        if t == "string" then
            return "\"" .. val .. "\""
        end
        return tostring(val)
    end
    return dmp(value)
end
local K = {}
K.dump = dump
K.show = function(value)
    print(dump(value))
end
K.find = function(arr, v)
    for i, k in ipairs(arr) do
        if k == v then
            return i
        end
    end
end
K.stack = function()
    local t = {}
    return {push = function(x)
        t[#t + 1] = x
    end, pop = function()
        if #t > 0 then
            local x = t[#t]
            t[#t] = nil
            return x
        end
    end}
end
local merge
merge = function(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k] or false) == "table" then
            merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end
K.merge = merge
K.concats = function(...)
    local tb = {}
    local n = 1
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        for j = 1, #t do
            tb[n] = t[j]
            n = n + 1
        end
    end
    return tb
end
K.reverse_inplace = function(arr)
    local i, j = 1, #arr
    while i < j do
        arr[i], arr[j] = arr[j], arr[i]
        i = i + 1
        j = j - 1
    end
end
K.val2key = function(t)
    local o = {}
    for k, v in pairs(t) do
        o[v] = k
    end
    return o
end
K.keys = function(t)
    local keys, n = {}, 0
    for k, _ in pairs(t) do
        n = n + 1
        keys[n] = k
    end
    return keys
end
return K
