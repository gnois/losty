--
-- Generated from wrap.lt
--
local enc = require("losty.enc")
local surl = require("losty.surl")
local hmac = ngx.hmac_sha1
return function(secret, key)
    if not (secret and key) then
        error("secret and key required", 2)
    end
    local pen = surl(secret)
    return {wrap = function(data, func, length)
        local obj = {key = key, data = data}
        return pen.sign(str, length), enc.encode(obj, func)
    end, unwrap = function(sig, text, func, length)
        assert(text)
        if pen.verify(sig, text, length) then
            local obj = enc.decode(text, func)
            if obj.key == key then
                return obj.data
            end
            return nil, "wrong key"
        end
        return nil, "wrong signature"
    end}
end
