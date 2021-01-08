--
-- Generated from surl.lt
--
local enc = require("losty.enc")
local hmac = ngx.hmac_sha1
return function(secret, length)
    if not secret then
        error("secret required", 2)
    end
    if length then
        assert(length > 1, "signed url length must be greater than 1")
    end
    return {sign = function(str)
        assert(str)
        local sig = enc.encode64(hmac(secret, str))
        if length then
            return string.sub(sig, 1, length)
        end
        return sig
    end, verify = function(sig, str)
        assert(str)
        if sig then
            local mac = enc.encode64(hmac(secret, str))
            if length then
                return string.sub(sig, 1, length) == string.sub(mac, 1, length)
            end
            return sig == mac
        end
        return false
    end}
end
