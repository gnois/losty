--
-- Generated from sess.lt
--
local json = require("cjson.safe")
local aes = require("resty.aes")
local rnd = require("resty.random")
local str = require("losty.str")
local base64enc = ngx.encode_base64
local base64dec = ngx.decode_base64
local hmac = ngx.hmac_sha1
return function(secret, key)
    if not secret or not key then
        error("secret and key is required for session", 2)
    end
    local encrypt = function(value)
        local salt = rnd.bytes(8)
        local d, err = json.encode(value)
        if d then
            local k = hmac(secret, salt)
            local h = hmac(k, table.concat({salt, d, key}))
            local a = aes:new(k, salt)
            d = a:encrypt(d)
            local x = {base64enc(salt), base64enc(d), base64enc(h)}
            return table.concat(x, "|")
        end
        return d, err
    end
    local decrypt = function(s)
        if s then
            local x = str.split(s, "|")
            if x and x[1] and x[2] and x[3] then
                local salt = base64dec(x[1])
                local d = base64dec(x[2])
                local h = base64dec(x[3])
                if salt and d and h then
                    local k = hmac(secret, salt)
                    local a = aes:new(k, salt)
                    d = a:decrypt(d)
                    if d then
                        if hmac(k, table.concat({salt, d, key})) == h then
                            return json.decode(d)
                        end
                    end
                end
            end
        end
    end
    local K = {}
    K.create = function(res, expiry)
        expiry = expiry or 24 * 3600
        return res.cookies.create("sess", expiry, true, nil, "/", encrypt)
    end
    K.read = function(req)
        return req.cookies.parse("sess", decrypt)
    end
    K.delete = function(res)
        res.cookies.delete("sess", true, nil, "/")
    end
    return K
end
