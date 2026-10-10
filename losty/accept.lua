--
-- Generated from accept.lau
--
local bit = require("bit")
local to = require("losty.to")
local gmatch = string.gmatch
local lower = string.lower
local concat = table.concat
local as_string = function(v)
    local t = type(v)
    if t == "string" or v == nil then
        return v
    end
    if t == "table" then
        return concat(v, ",")
    end
    return tostring(v)
end
local fields = function(s, sep)
    local acc, a = {}, 0
    local buf, n = {}, 0
    local quoted = false
    local esc = false
    for c in gmatch(s, ".") do
        if esc then
            esc = false
            n = n + 1
            buf[n] = c
        elseif c == "\\" and quoted then
            esc = true
            n = n + 1
            buf[n] = c
        elseif c == "\"" then
            quoted = not quoted
            n = n + 1
            buf[n] = c
        elseif c == sep and not quoted then
            a = a + 1
            acc[a] = concat(buf, "")
            buf, n = {}, 0
        else
            n = n + 1
            buf[n] = c
        end
    end
    a = a + 1
    acc[a] = concat(buf, "")
    return acc
end
local split = function(str, sep)
    local acc, a = {}, 0
    for _, each in ipairs(fields(str, sep)) do
        local x = to.trim(each)
        if #x > 0 then
            a = a + 1
            acc[a] = x
        end
    end
    return acc
end
local params_of = function(details)
    local params = {}
    local q = 1
    if details then
        for _, param in ipairs(split(details, ";")) do
            local k, v = string.match(param, "^(.-)=(.*)$")
            if k and v then
                k = lower(k)
                if k == "q" then
                    local n = tonumber(v)
                    if not n or n < 0 or n > 1 then
                        return 
                    end
                    q = n
                else
                    params[k] = v
                end
            end
        end
    end
    return params, q
end
local media_re = [[^%s*([^%s/;]+)/([^%s;]+)%s*;?(.*)$]]
local sorted_keys = function(t)
    local keys, n = {}, 0
    for k in pairs(t) do
        n = n + 1
        keys[n] = k
    end
    table.sort(keys, function(a, b)
        return a < b
    end)
    return keys
end
local media_mt = {__tostring = function(m)
    local out, n = {m.media .. "/" .. m.subtype}, 1
    for _, k in ipairs(sorted_keys(m.params)) do
        n = n + 1
        out[n] = k .. "=" .. (m.params[k] or "")
    end
    return concat(out, ";")
end}
local parse_media = function(mt, i)
    local media, subtype, details = string.match(mt, media_re)
    if media then
        local params, q = params_of(details)
        if params then
            return setmetatable({media = lower(media), subtype = lower(subtype), q = q, i = i, params = params}, media_mt)
        end
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
local best = function(i, accepts, spec_of)
    local prio = {i = i, o = 0, q = 0, s = 0}
    for _, spec in ipairs(accepts) do
        local one = spec_of(spec)
        if one then
            if one.s > prio.s then
                prio = one
            elseif one.s == prio.s and one.q > prio.q then
                prio = one
            elseif one.s == prio.s and one.q == prio.q and one.o < prio.o then
                prio = one
            end
        end
    end
    return prio
end
local prioritize = function(media, i, accepts)
    local parsed = parse_media(media, i)
    local mt = {media = parsed and parsed.media or media, subtype = parsed and parsed.subtype or "", q = parsed and parsed.q or 1, i = i, params = parsed and parsed.params or {}}
    setmetatable(mt, media_mt)
    local prio = best(i, accepts, function(spec)
        return specify(mt, i, spec)
    end)
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
    accept = as_string(accept)
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
local simple_re = [[^%s*([^%s;]+)%s*;?(.*)$]]
local parse_simple = function(str, i)
    local token, details = string.match(str, simple_re)
    if token then
        local params, q = params_of(details)
        if params then
            return {token = token, q = q, i = i}
        end
    end
end
local lang_mt = {__tostring = function(m)
    return m.full
end}
local parse_lang = function(str, i)
    local r = parse_simple(str, i)
    if r then
        local full = r.token
        local dash = string.find(full, "%-")
        local prefix = full
        local suffix
        if dash then
            prefix = string.sub(full, 1, dash - 1)
            suffix = string.sub(full, dash + 1)
        end
        return setmetatable({full = lower(full), prefix = lower(prefix), suffix = suffix and lower(suffix), q = r.q, i = i}, lang_mt)
    end
end
local parse_accept_lang = function(accept)
    local acc, a = {}, 0
    for i, lang in ipairs(split(accept, ",")) do
        local m = parse_lang(lang, i)
        if m then
            a = a + 1
            acc[a] = m
        end
    end
    return acc
end
local specify_lang = function(lang, i, spec)
    if lang then
        local s = 0
        if spec.full == lang.full then
            s = bit.bor(s, 4)
        elseif spec.prefix == lang.full then
            s = bit.bor(s, 2)
        elseif spec.full == lang.prefix then
            s = bit.bor(s, 1)
        elseif spec.full ~= "*" then
            return 
        end
        return {i = i, o = spec.i, q = spec.q, s = s}
    end
end
local prioritize_lang = function(lang, i, accepts)
    local text = as_string(lang) or ""
    local parsed = parse_lang(text, i)
    local m = {full = parsed and parsed.full or lower(text), prefix = parsed and parsed.prefix or lower(text), q = parsed and parsed.q or 1, i = i}
    setmetatable(m, lang_mt)
    local prio = best(i, accepts, function(spec)
        return specify_lang(m, i, spec)
    end)
    m.i = prio.i
    m.o = prio.o
    m.q = prio.q
    m.s = prio.s
    return m
end
local language = function(accept, avails)
    accept = as_string(accept)
    if not accept or #accept == 0 then
        accept = "*"
    end
    local acc = parse_accept_lang(accept)
    if avails then
        local prio = {}
        for i, av in ipairs(avails) do
            prio[i] = prioritize_lang(av, i, acc)
        end
        acc = prio
    end
    return sort_with_q(acc)
end
local charset_mt = {__tostring = function(m)
    return m.charset
end}
local parse_charset = function(str, i)
    local r = parse_simple(str, i)
    if r then
        return setmetatable({charset = lower(r.token), q = r.q, i = i}, charset_mt)
    end
end
local parse_accept_charset = function(accept)
    local acc, a = {}, 0
    for i, c in ipairs(split(accept, ",")) do
        local m = parse_charset(c, i)
        if m then
            a = a + 1
            acc[a] = m
        end
    end
    return acc
end
local specify_charset = function(cset, i, spec)
    if cset then
        local s = 0
        if spec.charset == cset.charset then
            s = 1
        elseif spec.charset ~= "*" then
            return 
        end
        return {i = i, o = spec.i, q = spec.q, s = s}
    end
end
local prioritize_charset = function(cset, i, accepts)
    local text = as_string(cset) or ""
    local parsed = parse_charset(text, i)
    local m = {charset = parsed and parsed.charset or lower(text), q = parsed and parsed.q or 1, i = i}
    setmetatable(m, charset_mt)
    local prio = best(i, accepts, function(spec)
        return specify_charset(m, i, spec)
    end)
    m.i = prio.i
    m.o = prio.o
    m.q = prio.q
    m.s = prio.s
    return m
end
local charset = function(accept, avails)
    accept = as_string(accept)
    if not accept or #accept == 0 then
        accept = "*"
    end
    local acc = parse_accept_charset(accept)
    if avails then
        local prio = {}
        for i, av in ipairs(avails) do
            prio[i] = prioritize_charset(av, i, acc)
        end
        acc = prio
    end
    return sort_with_q(acc)
end
local encoding_mt = {__tostring = function(m)
    return m.encoding
end}
local parse_encoding = function(str, i)
    local r = parse_simple(str, i)
    if r then
        return setmetatable({encoding = lower(r.token), q = r.q, i = i}, encoding_mt)
    end
end
local parse_accept_encoding = function(accept)
    local acc, a = {}, 0
    local identity = false
    local min_q = 1
    for i, e in ipairs(split(accept, ",")) do
        local m = parse_encoding(e, i)
        if m then
            a = a + 1
            acc[a] = m
            if m.encoding == "identity" or m.encoding == "*" then
                identity = true
            end
            if m.q > 0 and m.q < min_q then
                min_q = m.q
            end
        end
    end
    if not identity then
        a = a + 1
        acc[a] = setmetatable({encoding = "identity", q = min_q, i = a}, encoding_mt)
    end
    return acc
end
local specify_encoding = function(enc, i, spec)
    if enc then
        local s = 0
        if spec.encoding == enc.encoding then
            s = 1
        elseif spec.encoding ~= "*" then
            return 
        end
        return {i = i, o = spec.i, q = spec.q, s = s}
    end
end
local prioritize_encoding = function(enc, i, accepts)
    local text = as_string(enc) or ""
    local parsed = parse_encoding(text, i)
    local m = {encoding = parsed and parsed.encoding or lower(text), q = parsed and parsed.q or 1, i = i}
    setmetatable(m, encoding_mt)
    local prio = best(i, accepts, function(spec)
        return specify_encoding(m, i, spec)
    end)
    m.i = prio.i
    m.o = prio.o
    m.q = prio.q
    m.s = prio.s
    return m
end
local encoding = function(accept, avails)
    accept = as_string(accept)
    if not accept or #accept == 0 then
        accept = ""
    end
    local acc = parse_accept_encoding(accept)
    if avails then
        local prio = {}
        for i, av in ipairs(avails) do
            prio[i] = prioritize_encoding(av, i, acc)
        end
        acc = prio
    end
    return sort_with_q(acc)
end
return setmetatable({media = choose, language = language, charset = charset, encoding = encoding}, {__metatable = false, __call = function(_, accept, avails)
    return choose(accept, avails)
end})
