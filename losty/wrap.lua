--
-- Generated from wrap.lt
--
local enc = require("losty.enc")
local surl = require("losty.surl")
return function(secret, key, length)
    if not (secret and key) then
        error("secret and key required", 2)
    end
    local pen = surl(secret, length)
    return {wrap = function(data, func)
        local obj = {key = key, data = data}
        local text = enc.encode(obj, func)
        return pen.sign(text), text
    end, unwrap = function(sig, text, func)
        assert(text)
        if pen.verify(sig, text) then
            local obj = enc.decode(text, func)
            if obj.key == key then
                return obj.data
            end
            return nil, "wrong key"
        end
        return nil, "wrong signature"
    end}
end
