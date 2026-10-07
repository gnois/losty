--
-- Generated from wrap.lau
--
local enc = require("losty.enc")
local sigurl = require("losty.sigurl")
return function(secret, key, length)
    if not (secret and key) then
        error("secret and key required", 2)
    end
    local pen = sigurl(secret, length)
    return {wrap = function(data, func)
        local obj = {key = key, data = data}
        local text, err = enc.encode(obj, func)
        if text then
            return pen.sign_raw(text), text
        end
        return nil, err
    end, unwrap = function(sig, text, func)
        if not text then
            return nil, "missing token"
        end
        if not pen.verify_raw(sig, text) then
            return nil, "wrong signature"
        end
        local obj, err = enc.decode(text, func)
        if not obj then
            return nil, err
        end
        if type(obj) == "table" and obj.key == key then
            return obj.data
        end
        return nil, "wrong key"
    end}
end
