--
-- Generated from sign.lt
--
local enc = require("losty.enc")
local base64enc = ngx.encode_base64
local hmac = ngx.hmac_sha1
return function(secret)
    if not secret then
        error("secret is required to sign/unsign", 2)
    end
    local K = {}
    K.sign = function(key, data, func)
        if not key then
            error("a key is required to sign()", 2)
        end
        local obj = {key = key, data = data}
        local str = enc.encode(obj, func)
        local sig = base64enc(hmac(secret, str))
        return str .. "." .. sig
    end
    K.unsign = function(key, message, func)
        if key then
            if message then
                local str, sig = string.match(message, "^(.*)%.(.*)$")
                if str then
                    if sig == base64enc(hmac(secret, str)) then
                        local obj = enc.decode(str, func)
                        if obj.key == key then
                            return obj.data
                        end
                        return nil, "invalid key"
                    end
                    return nil, "invalid signature"
                end
                return nil, "invalid message"
            end
            return nil, "missing message"
        end
        return nil, "missing key"
    end
    return K
end
