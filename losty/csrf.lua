--
-- Generated from csrf.lt
--
local rnd = require("resty.random")
local wrap = require("losty.wrap")
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local Name = "csrf"
local Len = 16
local make = function(res)
    return res.cookie(Name, true, nil, "/")
end
local read = function(req)
    local key = req.cookies[Name]
    if key then
        return decode64(key)
    end
end
local needs_csrf = function(method)
    return not (method == "GET" or method == "HEAD" or method == "OPTIONS" or method == "TRACE")
end
local same_origin = function(req)
    local host = req.headers["Host"] or req.vars.host
    if host then
        local scheme = req.secure() and "https" or "http"
        local origin = req.headers["Origin"]
        local expect = scheme .. "://" .. host
        if origin and #origin > 0 then
            return origin == expect
        end
        local referer = req.headers["Referer"]
        if referer and #referer >= #expect then
            return string.sub(referer, 1, #expect) == expect
        end
    end
    return false
end
return function(secret, strict, samesite, force_secure)
    if samesite == nil then
        samesite = true
    end
    if force_secure == nil then
        force_secure = true
    end
    return {create = function(req, res, expiry)
        local key = read(req)
        if not key then
            key = rnd.bytes(Len)
            local secure = force_secure and true or req.secure()
            make(res)(nil, samesite, secure, encode64(key))
        end
        expiry = expiry or 0
        if expiry > 0 then
            expiry = ngx.time() + expiry
        end
        local bag = wrap(secret, key)
        local sig, data = bag.wrap(expiry)
        return sig .. "." .. data
    end, check = function(req, res, token)
        if strict and needs_csrf(req.vars.request_method) then
            if not same_origin(req) then
                return false, "origin mismatch"
            end
        end
        local key = read(req)
        if token and key and #key == Len then
            local bag = wrap(secret, key)
            local sig, data = string.match(token, "^(.*)%.(.*)$")
            if data then
                local expiry = bag.unwrap(sig, data)
                if expiry then
                    if expiry == 0 or expiry > ngx.time() then
                        return true
                    end
                    make(res)(-10)
                    return false, "expired"
                end
            end
        end
        return false, "invalid"
    end}
end
