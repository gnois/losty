--
-- Generated from csrf.lt
--
local sign = require("losty.sign")
local enc = require("losty.enc")
local rnd = require("losty.rand")
local Name = "csrf"
local make = function(res)
    return res.cookie(Name, false, nil, "/")
end
local write = function(req, res)
    local c = make(res)(nil, true, req.secure, enc.encode)
    c.key = rnd.least(8)
    return c.key
end
local read = function(req)
    local c = enc.decode(req.cookies[Name])
    return c and c.key
end
return function(secret)
    local sg = sign(secret)
    return {create = function(req, res, expiry)
        local key = read(req)
        if not key then
            key = write(req, res)
        end
        expiry = expiry or 0
        if expiry > 0 then
            expiry = ngx.time() + expiry
        end
        return sg.sign(key, expiry)
    end, check = function(req, res, token)
        local key = read(req)
        if key and token then
            local expiry, err = sg.unsign(key, token)
            if expiry and (expiry == 0 or expiry > ngx.time()) then
                return true
            end
            make(res)(-10)
            return false, "token expired"
        end
        return false, "forbidden"
    end}
end
