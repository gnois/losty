--
-- Generated from rand.lt
--
local rnd = require("resty.random")
local str = require("resty.string")
local K = {}
K.key = function(secret, key)
    return ngx.encode_base64(ngx.hmac_sha1(secret, key))
end
K.least = function(length)
    local key = rnd.bytes(length)
    return str.to_hex(key)
end
return K
