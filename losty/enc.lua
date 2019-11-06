--
-- Generated from enc.lt
--
local json = require("cjson.safe")
local K = {}
K.encode = function(obj, func)
    if obj then
        local str, err = json.encode(obj)
        if str then
            if func then
                str = func(str)
            end
            return ngx.encode_base64(str)
        end
        return str, err
    end
end
K.decode = function(str, func)
    if str then
        str = ngx.decode_base64(str)
        if func then
            str = func(str)
        end
        return json.decode(str)
    end
end
return K
