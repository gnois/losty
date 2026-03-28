--
-- Generated from wrap.lt
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
        assert(text)
        if pen.verify_raw(sig, text) then
            local obj, err = enc.decode(text, func)
            if obj then
                if obj.key == key then
                    return obj.data
                end
                return nil, "wrong key"
            end
            return nil, err
        end
        return nil, "wrong signature"
    end}
end
