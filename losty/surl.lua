--
-- Generated from surl.lt
--
local enc = require("losty.enc")
local hmac = ngx.hmac_sha1
return function(secret)
    if not secret then
        error("secret required", 2)
    end
    return {sign = function(fragment, length)
        assert(fragment)
        local sig = enc.encode64(hmac(secret, fragment))
        if length then
            assert(length > 1)
            return string.sub(sig, 1, length)
        end
        return sig
    end, verify = function(sig, fragment, length)
        assert(fragment)
        if sig then
            local mac = enc.encode64(hmac(secret, fragment))
            if length then
                assert(length > 1)
                return string.sub(sig, 1, length) == string.sub(mac, 1, length)
            end
            return sig == mac
        end
        return false
    end}
end
