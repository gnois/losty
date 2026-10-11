--
-- Generated from proxy.lau
--
local bit = require("bit")
local to = require("losty.to")
local lower = string.lower
local split_quoted = function(txt, sep)
    local out = {}
    if not txt then
        return out
    end
    local q = false
    local esc = false
    local acc = {}
    for i = 1, #txt do
        local c = string.sub(txt, i, i)
        if esc then
            acc[#acc + 1] = c
            esc = false
        elseif c == "\\" and q then
            esc = true
        elseif c == "\"" then
            q = not q
            acc[#acc + 1] = c
        elseif c == sep and not q then
            out[#out + 1] = to.trim(table.concat(acc, ""))
            acc = {}
        else
            acc[#acc + 1] = c
        end
    end
    out[#out + 1] = to.trim(table.concat(acc, ""))
    return out
end
local unquote = function(v)
    if not v then
        return v
    end
    if string.sub(v, 1, 1) == "\"" and string.sub(v, -1, -1) == "\"" then
        v = string.sub(v, 2, -2)
    end
    return v
end
local parse_forwarded = function(header)
    local out = {}
    for _, elem in ipairs(split_quoted(header, ",")) do
        if #elem > 0 then
            local e = {}
            for _, part in ipairs(split_quoted(elem, ";")) do
                local k, v = string.match(part, "^%s*([^=]+)%s*=%s*(.-)%s*$")
                if k and v then
                    e[lower(to.trim(k))] = unquote(to.trim(v))
                end
            end
            if next(e) then
                out[#out + 1] = e
            end
        end
    end
    return out
end
local ipv4_u32 = function(ip)
    local a, b, c, d = string.match(ip or "", "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then
        return nil
    end
    a = tonumber(a)
    b = tonumber(b)
    c = tonumber(c)
    d = tonumber(d)
    if a > 255 or b > 255 or c > 255 or d > 255 then
        return nil
    end
    return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(c, 8), d)
end
local hex16 = function(s)
    if #s < 1 or #s > 4 or string.find(s, "[^0-9a-fA-F]") then
        return nil
    end
    return tonumber(s, 16)
end
local v6_part = function(txt)
    local out = {}
    if txt == "" then
        return out
    end
    local groups = {}
    for g in string.gmatch(txt, "[^:]+") do
        groups[#groups + 1] = g
    end
    if table.concat(groups, ":") ~= txt then
        return nil
    end
    for i = 1, #groups do
        local g = groups[i]
        if string.find(g, ".", 1, true) then
            if i ~= #groups then
                return nil
            end
            local n = ipv4_u32(g)
            if not n then
                return nil
            end
            out[#out + 1] = bit.rshift(n, 16)
            out[#out + 1] = bit.band(n, 0xffff)
        else
            local w = hex16(g)
            if w == nil then
                return nil
            end
            out[#out + 1] = w
        end
    end
    return out
end
local ipv6_words = function(ip)
    local s = ip
    if not s then
        return nil
    end
    if string.sub(s, 1, 1) == "[" then
        s = string.match(s, "^%[([^%]]+)%]") or s
    end
    if not string.find(s, ":", 1, true) or string.find(s, "[^0-9a-fA-F:%.]") then
        return nil
    end
    local at = string.find(s, "::", 1, true)
    local left, right = s, nil
    if at then
        left = string.sub(s, 1, at - 1)
        right = string.sub(s, at + 2)
        if string.find(right, "::", 1, true) then
            return nil
        end
    end
    local words = v6_part(left)
    if not words then
        return nil
    end
    if right then
        local tail = v6_part(right)
        if not tail then
            return nil
        end
        local fill = 8 - #words - #tail
        if fill < 1 then
            return nil
        end
        for _ = 1, fill do
            words[#words + 1] = 0
        end
        for _, w in ipairs(tail) do
            words[#words + 1] = w
        end
    end
    if #words ~= 8 then
        return nil
    end
    return words
end
local v6_match = function(words, rule)
    for i = 1, 8 do
        local bits = rule.p - (i - 1) * 16
        if bits > 0 then
            local m
            if bits >= 16 then
                m = 0xffff
            else
                m = bit.band(0xffff, bit.lshift(0xffff, 16 - bits))
            end
            if bit.band(words[i], m) ~= rule.base[i] then
                return false
            end
        end
    end
    return true
end
local cidr_rule = function(txt)
    local ip, p = string.match(txt or "", "^([^/]+)/(%d+)$")
    if not ip then
        return nil
    end
    p = tonumber(p)
    if string.find(ip, ":", 1, true) then
        local words = ipv6_words(ip)
        if not words or p < 0 or p > 128 then
            return nil
        end
        local v6base = {}
        for i = 1, 8 do
            local bits = p - (i - 1) * 16
            if bits <= 0 then
                v6base[i] = 0
            elseif bits >= 16 then
                v6base[i] = words[i]
            else
                v6base[i] = bit.band(words[i], bit.band(0xffff, bit.lshift(0xffff, 16 - bits)))
            end
        end
        return {v6 = true, base = v6base, p = p}
    end
    local v4base = ipv4_u32(ip)
    if not v4base then
        return nil
    end
    if p < 0 or p > 32 then
        return nil
    end
    local mask
    if p == 0 then
        mask = 0
    else
        mask = bit.tobit(bit.lshift(0xffffffff, 32 - p))
    end
    return {base = bit.band(v4base, mask), mask = mask}
end
local trustfn = function(trusted)
    if not trusted then
        return nil
    end
    if type(trusted) == "function" then
        return trusted
    end
    if type(trusted) ~= "table" then
        error("trusted must be function or array of IP/CIDR strings", 2)
    end
    local exact = {}
    local rules = {}
    for _, v in ipairs(trusted) do
        if v then
            v = to.trim(v)
            local rule = cidr_rule(v)
            if not rule and string.find(v, ":", 1, true) then
                rule = cidr_rule(v .. "/128")
            end
            if rule then
                rules[#rules + 1] = rule
            else
                exact[lower(v)] = true
            end
        end
    end
    return function(ip)
        if ip and exact[lower(ip)] then
            return true
        end
        if ip then
            local v4 = ipv4_u32(ip)
            if v4 then
                for _, rule in ipairs(rules) do
                    if not rule.v6 and bit.band(v4, rule.mask) == rule.base then
                        return true
                    end
                end
            elseif string.find(ip, ":", 1, true) then
                local words = ipv6_words(ip)
                if words then
                    for _, rule in ipairs(rules) do
                        if rule.v6 and v6_match(words, rule) then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end
end
local is_ipv6_literal = function(txt)
    if not txt or not string.find(txt, ":", 1, true) then
        return false
    end
    if string.find(txt, "[^0-9a-fA-F:%.]") then
        return false
    end
    return true
end
local normalize_ip = function(raw)
    if raw then
        local ip = to.trim(raw)
        if ip == "" or ip == "unknown" or string.sub(ip, 1, 1) == "_" then
            return nil
        end
        ip = string.gsub(ip, "^\"(.*)\"$", "%1")
        if string.sub(ip, 1, 1) == "[" then
            local host = string.match(ip, "^%[([^%]]+)%]")
            if host and host ~= "" then
                if is_ipv6_literal(host) then
                    return lower(host)
                end
            end
            return nil
        end
        local a, b, c, d, p = string.match(ip, "^(%d+)%.(%d+)%.(%d+)%.(%d+):(%d+)$")
        if a then
            ip = a .. "." .. b .. "." .. c .. "." .. d
        end
        if ipv4_u32(ip) then
            return ip
        end
        if is_ipv6_literal(ip) then
            return lower(ip)
        end
    end
end
local forwarded_chain = function(header)
    local chain = {}
    for _, e in ipairs(parse_forwarded(header)) do
        local f = normalize_ip(e["for"])
        if f then
            chain[#chain + 1] = f
        end
    end
    return chain
end
local xff_chain = function(header)
    local chain = {}
    for ip in string.gmatch(header or "", "[^,]+") do
        ip = normalize_ip(ip)
        if ip then
            chain[#chain + 1] = ip
        end
    end
    return chain
end
local first = function(csv)
    if csv then
        local x = string.match(csv, "^%s*([^,]+)")
        return x and to.trim(x)
    end
end
local normalize_scheme = function(raw)
    if raw then
        local s = lower(to.trim(raw))
        if s == "http" or s == "https" then
            return s
        end
    end
end
local normalize_host = function(raw)
    if raw then
        local h = to.trim(string.gsub(raw, "^\"(.*)\"$", "%1"))
        if h == "" or string.find(h, "[%s/%?#@]") or string.find(h, "[^%w%.%-%[%]:]") then
            return nil
        end
        return lower(h)
    end
end
local fallback_host = function(vars, remote)
    local host = normalize_host(vars and vars.host)
    if host then
        return host
    end
    local ip = normalize_ip(remote)
    if ip then
        if string.find(ip, ":", 1, true) then
            return "[" .. ip .. "]"
        end
        return ip
    end
    return "localhost"
end
local client_ip = function(vars, trusted)
    local remote = vars.remote_addr
    local is_trusted = trustfn(trusted)
    if not is_trusted or not is_trusted(remote) then
        return remote
    end
    local chain = forwarded_chain(vars.http_forwarded)
    if #chain < 1 then
        chain = xff_chain(vars.http_x_forwarded_for)
    end
    chain[#chain + 1] = remote
    for i = #chain, 1, -1 do
        local ip = chain[i]
        if ip and not is_trusted(ip) then
            return ip
        end
    end
    return remote
end
local canonical_url = function(q, trusted)
    local vars = q.vars
    local headers = q.headers
    local remote = vars.remote_addr
    local is_trusted = trustfn(trusted)
    local trusted_remote = is_trusted and is_trusted(remote)
    local fwd = trusted_remote and parse_forwarded(vars.http_forwarded) or {}
    local f0 = fwd[1] or {}
    local scheme = nil
    if trusted_remote then
        scheme = normalize_scheme(f0["proto"]) or normalize_scheme(first(vars.http_x_forwarded_proto))
    end
    if not scheme then
        scheme = q.secure() and "https" or "http"
    end
    local host = nil
    if trusted_remote then
        host = normalize_host(f0["host"]) or normalize_host(first(vars.http_x_forwarded_host))
    end
    if not host then
        host = normalize_host(headers["Host"]) or fallback_host(vars, remote)
    end
    local uri = vars.request_uri or vars.uri or "/"
    if string.sub(uri, 1, 1) ~= "/" then
        uri = "/" .. uri
    end
    return scheme .. "://" .. host .. uri
end
return {parse_forwarded = parse_forwarded, trustfn = trustfn, client_ip = client_ip, canonical_url = canonical_url}
