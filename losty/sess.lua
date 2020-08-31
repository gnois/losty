--
-- Generated from sess.lt
--
local json = require("cjson.safe")
local aes = require("resty.aes")
local rnd = require("resty.random")
local str = require("losty.str")
local Len = 8
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
    local encrypt = function(value)
        local salt = rnd.bytes(Len)
        local d, err = json.encode(value)
        if d then
            local k = hmac(secret, salt)
            local a = aes:new(k, salt)
            local sig = hmac(k, table.concat({salt, d, key}))
            local data = a:encrypt(d)
            return encode64(data) .. "|" .. encode64(salt), encode64(sig)
        end
        return "", err
    end
    local decrypt = function(payload, sig)
        if payload and sig then
            local x = str.split(payload, "|")
            if x and x[1] and x[2] then
                local data = decode64(x[1])
                local salt = decode64(x[2])
                if data and salt and #salt == Len then
                    local k = hmac(secret, salt)
                    local a = aes:new(k, salt)
                    local d = a and a:decrypt(data)
                    if d then
                        if hmac(k, table.concat({salt, d, key})) == decode64(sig) then
                            return json.decode(d)
                        end
                    end
                end
            end
        end
    end
    local name_ = name .. "_"
    local make = function(res)
        return res.cookie(name, false, nil, "/")
    end
    local make_ = function(res)
        return res.cookie(name_, true, nil, "/")
    end
    local signature
    local signing = function()
        return signature
    end
    local encrypting = function(value)
        local payload
        payload, signature = encrypt(value)
        return payload
    end
    return {read = function(req)
        return decrypt(req.cookies[name_], req.cookies[name])
    end, create = function(req, res, age)
        local secure = req.secure()
        local data = make_(res)(age, nil, secure, encrypting)
        make(res)(age, nil, secure, signing)
        return data
    end, delete = function(res)
        make(res)(-100)
        make_(res)(-100)
    end}
end
