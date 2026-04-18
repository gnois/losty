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
local hmac = ngx.hmac_sha1
local Cipher = aes.cipher(128, "cbc")
local Key_len = 16
local normalize_secrets = function(secret)
    if "table" == type(secret) then
        assert(#secret > 0, "session secret list cannot be empty")
        return secret
    end
    return {secret}
end
local derive = function(secret, salt)
    return {enc = string.sub(hmac(secret, "enc|" .. salt), 1, Key_len), mac = hmac(secret, "mac|" .. salt)}
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
        if salt then
            local d, err = json.encode(value)
            if d then
                local a, data
                local k = derive(secrets[1], salt)
                a, err = aes:new(k.enc, nil, Cipher, {iv = salt})
                if a then
                    data, err = a:encrypt(d)
                    if data then
                        local mac_input = key and table.concat({salt, data, key}) or table.concat({salt, data})
                        local sig = hmac(k.mac, mac_input)
                        return encode64(data) .. "|" .. encode64(salt), encode64(sig)
                    end
                end
            end
            return nil, err
        end
        return nil, "failed to generate random bytes"
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
                        local mac_input = key and table.concat({salt, data, key}) or table.concat({salt, data})
                        if str.safe_equal(hmac(k.mac, mac_input), decode64(sig)) then
                            local a, err = aes:new(k.enc, nil, Cipher, {iv = salt})
                            if a then
                                local d
                                d, err = a:decrypt(data)
                                if d then
                                    return json.decode(d)
                                end
                            end
                            return nil, err
                        end
                    end
                    return nil, "unmatched signature"
                end
            end
        end
        return nil, "invalid payload"
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
        local payload, err
        payload, signature = encrypt(value)
        if not payload then
            ngx.log(ngx.ERR, "sess encrypt failed: ", err)
        end
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
