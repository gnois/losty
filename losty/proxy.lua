--
-- Generated from proxy.lt
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
local cidr_rule = function(txt)
    local ip, p = string.match(txt or "", "^([^/]+)/(%d+)$")
    if not ip then
        return nil
    end
    local base = ipv4_u32(ip)
    if not base then
        return nil
    end
    p = tonumber(p)
    if p < 0 or p > 32 then
        return nil
    end
    local mask
    if p == 0 then
        mask = 0
    else
        mask = bit.tobit(bit.lshift(0xffffffff, 32 - p))
    end
    return {base = bit.band(base, mask), mask = mask}
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
    local cidrs = {}
    for _, v in ipairs(trusted) do
        if v then
            v = to.trim(v)
            local c = cidr_rule(v)
            if c then
                cidrs[#cidrs + 1] = c
            else
                exact[v] = true
            end
        end
    end
    return function(ip)
        if exact[ip] then
            return true
        end
        local n = ipv4_u32(ip)
        if n then
            for _, c in ipairs(cidrs) do
                if bit.band(n, c.mask) == c.base then
                    return true
                end
            end
        end
        return false
    end
end
local forwarded_chain = function(header)
    local chain = {}
    for _, e in ipairs(parse_forwarded(header)) do
        local f = e["for"]
        if f then
            f = string.gsub(f, "^\"(.*)\"$", "%1")
            if string.sub(f, 1, 1) == "[" then
                f = string.match(f, "^%[([^%]]+)%]") or f
            else
                f = string.match(f, "^([^:]+)") or f
            end
            chain[#chain + 1] = f
        end
    end
    return chain
end
local xff_chain = function(header)
    local chain = {}
    for ip in string.gmatch(header or "", "[^,]+") do
        chain[#chain + 1] = to.trim(ip)
    end
    return chain
end
local client_ip = function(vars, headers, trusted)
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
    return chain[1] or remote
end
local first = function(csv)
    if not csv then
        return nil
    end
    local x = string.match(csv, "^%s*([^,]+)")
    return x and to.trim(x)
end
local canonical_url = function(q, trusted)
    local vars = q.vars
    local headers = q.headers
    local remote = vars.remote_addr
    local is_trusted = trustfn(trusted)
    local trusted_remote = is_trusted and is_trusted(remote)
    local fwd = trusted_remote and parse_forwarded(vars.http_forwarded) or {}
    local f0 = fwd[1] or {}
    local scheme = trusted_remote and (f0["proto"] or first(vars.http_x_forwarded_proto)) or (q.secure() and "https" or "http")
    scheme = lower(scheme or "http")
    local host = trusted_remote and (f0["host"] or first(vars.http_x_forwarded_host)) or headers["Host"] or vars.host
    host = host or ""
    local uri = vars.request_uri or vars.uri or "/"
    if string.sub(uri, 1, 1) ~= "/" then
        uri = "/" .. uri
    end
    return scheme .. "://" .. host .. uri
end
return {parse_forwarded = parse_forwarded, trustfn = trustfn, client_ip = client_ip, canonical_url = canonical_url}
