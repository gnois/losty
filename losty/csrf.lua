--
-- Generated from csrf.lt
--
local wrap = require("losty.wrap")
local rnd = require("losty.rand")
local Name = "csrf"
local make = function(res)
    return res.cookie(Name, true, nil, "/")
end
local write = function(req, res)
    local key = rnd.least(8)
    make(res)(nil, true, req.secure, key)
    return key
end
local read = function(req)
    return req.cookies[Name]
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
        if key and token then
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
