--
-- Generated from csrf.lt
--
local sign = require("losty.sign")
local enc = require("losty.enc")
local rnd = require("losty.rand")
return function(secret)
    local sg = sign(secret)
    local K = {}
    local generate = function(expiry)
        local key = rnd.least(4)
        expiry = expiry or -1
        if expiry ~= -1 then
            expiry = ngx.time() + expiry
        end
        local token = sg.sign(key, expiry)
        return key, token
    end
    local ok = function(key, token)
        if key and token then
            local expiry, err = sg.unsign(key, token)
            if expiry and (expiry == -1 or expiry > ngx.time()) then
                return true
            end
            return false, "This page may be outdated. Please refresh your browser."
        end
        return false, "Request is forbidden"
    end
    K.generate = generate
    K.ok = ok
    K.write = function(res, expiry)
        local csrf = res.cookies.create("csrf", 0, false, nil, "/", enc.encode)
        csrf.key, csrf.token = generate(expiry)
    end
    K.read = function(req, res)
        local csrf = req.cookies.parse("csrf", enc.decode)
        res.cookies.delete("csrf", false, nil, "/")
        return ok(csrf.key, csrf.token)
    end
    return K
end
