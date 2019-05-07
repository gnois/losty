--
-- Generated from enc.lt
--
local json = require("cjson.safe")
local K = {}
K.encode = function(obj, func)
    local str, err = json.encode(obj)
    if str then
        if func then
            str = func(str)
        end
        return ngx.encode_base64(str)
    end
    return str, err
end
K.decode = function(str, func)
    str = ngx.decode_base64(str)
    if func then
        str = func(str)
    end
    return json.decode(str)
end
return K
