--
-- Generated from accept.lt
--
local bit = require("bit")
local to = require("losty.to")
local yield = coroutine.yield
local create = coroutine.create
local resume = coroutine.resume
local gmatch = string.gmatch
local lower = string.lower
local concat = table.concat
local parse = function(s, sep)
    local r = create(function()
        local acc, n = {}, 0
        local bracket = false
        for c in gmatch(s, ".") do
            if c == "\"" then
                bracket = not bracket
                n = n + 1
                acc[n] = c
            else
                if c == sep and not bracket then
                    if n > 0 then
                        yield(concat(acc))
                        acc, n = {}, 0
                    end
                else
                    n = n + 1
                    acc[n] = c
                end
            end
        end
        if n > 0 then
            yield(concat(acc))
        end
    end)
    return function()
        local code, res = resume(r)
        return res
    end
end
local split = function(str, sep)
    local acc, a = {}, 0
    for each in parse(str, sep) do
        local x = to.trim(each)
        if #x > 0 then
            a = a + 1
            acc[a] = x
        end
    end
    return acc
end
local media_re = [[^\s*([^\s\/;]+)\/([^;\s]+)\s*(?:;(.*))?$]]
local media_mt = {__tostring = function(m)
    local out = {m.media .. "/" .. m.subtype}
    local o = 2
    for k, v in pairs(m.params) do
        out[o] = k .. "=" .. (v or "")
        o = o + 1
    end
    return concat(out, ";")
end}
local parse_media = function(mt, i)
    local arr = ngx.re.match(mt, media_re, "jo")
    if arr then
        local m = {media = lower(arr[1]), subtype = lower(arr[2]), q = 1, i = i, params = {}}
        if arr[3] then
            local params = split(arr[3], ";")
            for _, param in ipairs(params) do
                local k, v = string.match(param, "^(.-)=(.*)$")
                if k and v then
                    k = lower(k)
                    if k == "q" then
                        m.q = tonumber(v)
                    else
                        m.params[k] = v
                    end
                end
            end
        end
        return setmetatable(m, media_mt)
    end
end
local parse_accept = function(accept)
    local medias = split(accept, ",")
    local acc, a = {}, 0
    for i, mt in ipairs(medias) do
        local m = parse_media(mt, i)
        if m then
            a = a + 1
            acc[a] = m
        end
    end
    return acc
end
local specify = function(mt, i, spec)
    if mt then
        local s = 0
        if spec.media == mt.media then
            s = bit.bor(s, 4)
        elseif spec.media ~= "*" then
            return 
        end
        if spec.subtype == mt.subtype then
            s = bit.bor(s, 2)
        elseif spec.subtype ~= "*" then
            return 
        end
        if #spec.params > 0 and not mt.params then
            return 
        end
        for k, v in pairs(spec.params) do
            local w = mt.params[k]
            if w and (v == "*" or w == v or w == string.match(v, "^\"%s*(.*)%s*\"$")) then
                s = bit.bor(s, 1)
            else
                return 
            end
        end
        return {i = i, o = spec.i, q = spec.q, s = s}
    end
end
local prioritize = function(media, i, accepts)
    local mt = parse_media(media)
    local prio = {i = i, o = 0, q = 0, s = 0}
    for _, acc in ipairs(accepts) do
        local spec = specify(mt, i, acc)
        if spec then
            if spec.s >= prio.s then
                prio = spec
            elseif spec.s == prio.s and spec.q >= prio.q then
                prio = spec
            elseif spec.s == prio.s and spec.q == prio.q and spec.o >= prio.o then
                prio = spec
            end
        end
    end
    if not mt then
        mt = setmetatable({media = media, subtype = ""}, media_mt)
    end
    mt.i = prio.i
    mt.o = prio.o
    mt.q = prio.q
    mt.s = prio.s
    return mt
end
local sort_with_q = function(list)
    local acc, a = {}, 0
    for _, l in ipairs(list) do
        if l.q > 0 then
            a = a + 1
            acc[a] = l
        end
    end
    table.sort(acc, function(x, y)
        if x.q then
            if y.q then
                if x.q ~= y.q then
                    return x.q > y.q
                end
            else
                return true
            end
        elseif y.q then
            return false
        end
        if x.s then
            if y.s then
                if x.s ~= y.s then
                    return x.s > y.s
                end
            else
                return true
            end
        elseif y.s then
            return false
        end
        if x.o then
            if y.o then
                if x.o ~= y.o then
                    return x.o < y.o
                end
            else
                return true
            end
        elseif y.o then
            return false
        end
        if x.i then
            if y.i then
                return x.i < y.i
            end
            return true
        elseif y.i then
            return false
        end
        return true
    end)
    return acc
end
local choose = function(accept, avails)
    if not accept or #accept == 0 then
        accept = "*/*"
    end
    local acc = parse_accept(accept)
    if avails then
        local prio = {}
        for i, av in ipairs(avails) do
            prio[i] = prioritize(av, i, acc)
        end
        acc = prio
    end
    return sort_with_q(acc)
end
return choose
