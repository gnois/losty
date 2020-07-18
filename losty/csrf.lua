--
-- Generated from csrf.lt
--
local rnd = require("resty.random")
local str = require("resty.string")
local wrap = require("losty.wrap")
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local Name = "csrf"
local Len = 8
local make = function(res)
    return res.cookie(Name, true, nil, "/")
end
local least = function(length)
    local key = rnd.bytes(length)
    return str.to_hex(key)
end
local write = function(req, res)
    local key = least(Len)
    make(res)(nil, true, req.secure(), encode64(key))
    return key
end
local read = function(req)
    local key = req.cookies[Name]
    if key then
        return decode64(key)
    end
end
return function(secret)
    return {create = function(req, res, expiry)
        local key = read(req)
        if not key then
            key = write(req, res)
        end
        expiry = expiry or 0
        if expiry > 0 then
            expiry = ngx.time() + expiry
        end
        local bag = wrap(secret, key)
        local sig, data = bag.wrap(expiry)
        return sig .. "." .. data
    end, check = function(req, res, token)
        local key = read(req)
        if token and key and #key > Len then
            local bag = wrap(secret, key)
            local sig, data = string.match(token, "^(.*)%.(.*)$")
            if data then
                local expiry = bag.unwrap(sig, data)
                if expiry then
                    if expiry == 0 or expiry > ngx.time() then
                        return true
                    end
                    make(res)(-10)
                    return false, "token expired"
                end
            end
        end
        return false, "forbidden"
    end}
end
