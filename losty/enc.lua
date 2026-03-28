--
-- Generated from enc.lt
--
local json = require("cjson.safe")
local enc_url_chars = {["+"] = "-", ["/"] = "_", ["="] = "~"}
local dec_url_chars = {["-"] = "+", _ = "/", ["~"] = "="}
local encode64 = function(value)
    local s = ngx.encode_base64(value)
    return (string.gsub(s, "[+/=]", enc_url_chars))
end
local decode64 = function(value)
    local s = (string.gsub(value, "[-_~]", dec_url_chars))
    return ngx.decode_base64(s)
end
return {encode64 = encode64, decode64 = decode64, encode = function(obj, func)
    assert(obj)
    local str, err = json.encode(obj)
    if not str then
        return nil, err
    end
    if func then
        str, err = func(str)
        if not str then
            return nil, err
        end
    end
    return encode64(str)
end, decode = function(str, func)
    assert(str)
    str = decode64(str)
    if not str then
        return nil, "invalid base64"
    end
    if func then
        str = func(str)
        if not str then
            return nil, "decryption failed"
        end
    end
    return json.decode(str)
end}
