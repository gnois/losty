--
-- Generated from sess.lt
--
local json = require("cjson.safe")
local aes = require("resty.aes")
local rnd = require("resty.random")
local str = require("losty.str")
local Len = 16
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local hmac = ngx.hmac_sha256 or ngx.hmac_sha1
if not hmac then
    error("ngx.hmac_sha256 or ngx.hmac_sha1 required", 2)
end
local Cipher = aes.cipher(256, "cbc")
local Hash = aes.hash.sha256
local normalize_secrets = function(secret)
    if "table" == type(secret) then
        assert(#secret > 0, "session secret list cannot be empty")
        return secret
    end
    return {secret}
end
local derive = function(secret, salt)
    return {enc = hmac(secret, "enc|" .. salt), mac = hmac(secret, "mac|" .. salt)}
end
return function(name, secret, key, samesite, force_secure)
    if not name then
        error("session name required", 2)
    end
    if not secret then
        error("session secret required", 2)
    end
    local secrets = normalize_secrets(secret)
    samesite = samesite or "lax"
    if force_secure == nil then
        force_secure = true
    end
    local encrypt = function(value)
        local salt = rnd.bytes(Len)
        local d, err = json.encode(value)
        if d then
            local k = derive(secrets[1], salt)
            local a = aes:new(k.enc, salt, Cipher, Hash)
            local sig = hmac(k.mac, table.concat({salt, d, key}))
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
                    for _, sec in ipairs(secrets) do
                        local k = derive(sec, salt)
                        local a = aes:new(k.enc, salt, Cipher, Hash)
                        local d = a and a:decrypt(data)
                        if d then
                            if str.safe_equal(hmac(k.mac, table.concat({salt, d, key})), decode64(sig)) then
                                return json.decode(d)
                            end
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
        local secure = force_secure and true or req.secure()
        local data = make_(res)(age, samesite, secure, encrypting)
        make(res)(age, samesite, secure, signing)
        return data
    end, delete = function(res)
        make(res)(-100)
        make_(res)(-100)
    end}
end
