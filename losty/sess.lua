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
    local name_s = name .. "_"
    local salt = rnd.bytes(8)
    local encrypt = function(value)
        local k = hmac(secret, salt)
        local d = json.encode(value)
        local h = hmac(k, table.concat({salt, d, key}))
        local a = aes:new(k, salt)
        return encode64(a:encrypt(d)) .. "|" .. encode64(h)
    end
    local decrypt = function(txt, s)
        if txt and s then
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
        return res.cookie(name, true, nil, "/")
    end
    local make_s = function(res)
        return res.cookie(name_s, false, nil, "/")
    end
    return {read = function(req)
        return decrypt(req.cookies[name], req.cookies[name_s])
    end, create = function(req, res, age)
        make_s(res)(age, true, req.secure, encode64(salt))
        return make(res)(age, true, req.secure, encrypt)
    end, delete = function(res)
        make_s(res)(-100)
        make(res)(-100)
    end}
end
