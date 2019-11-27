--
-- Generated from sess.lt
--
local json = require("cjson.safe")
local aes = require("resty.aes")
local rnd = require("resty.random")
local str = require("losty.str")
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local hmac = ngx.hmac_sha1
return function(name, secret, key)
    if not name then
        error("session name required", 2)
    end
    if not secret then
        error("session secret required", 2)
    end
    local name_ = name .. "_"
    local salt = rnd.bytes(8)
    local encrypt = function(value)
        local k = hmac(secret, salt)
        local d = json.encode(value)
        local h = hmac(k, table.concat({salt, d, key}))
        local a = aes:new(k, salt)
        return encode64(a:encrypt(d)) .. "|" .. encode64(h)
    end
    local decrypt = function(s, txt)
        if s and txt then
            local x = str.split(txt, "|")
            if x and x[1] and x[2] then
                local d = decode64(x[1])
                local h = decode64(x[2])
                if d and h then
                    s = decode64(s)
                    local k = hmac(secret, s)
                    local a = aes:new(k, s)
                    d = a:decrypt(d)
                    if d then
                        if hmac(k, table.concat({s, d, key})) == h then
                            return json.decode(d)
                        end
                    end
                end
            end
        end
    end
    local make = function(res)
        return res.cookie(name, false, nil, "/")
    end
    local make_ = function(res)
        return res.cookie(name_, true, nil, "/")
    end
    return {read = function(req)
        return decrypt(req.cookies[name], req.cookies[name_])
    end, create = function(req, res, age)
        make(res)(age, true, req.secure, encode64(salt))
        return make_(res)(age, true, req.secure, encrypt)
    end, delete = function(res)
        make(res)(-100)
        make_(res)(-100)
    end}
end
