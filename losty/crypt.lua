--
-- Generated from crypt.lt
--
local aes = require("resty.aes")
local rnd = require("resty.random")
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local SaltLen = 16
return function(key, size, mode, hash, rounds)
    size = size or 256
    mode = mode or "cbc"
    hash = hash or aes.hash.sha256
    local cipher = aes.cipher(size, mode)
    return {encrypt = function(str)
        local salt = rnd.bytes(SaltLen)
        if not salt then
            return nil, "failed to generate random bytes"
        end
        local a = aes:new(key, salt, cipher, hash, rounds)
        local ct = a and a:encrypt(str)
        if not ct then
            return nil, "encryption failed"
        end
        return encode64(salt) .. "." .. encode64(ct)
    end, decrypt = function(str)
        local s, ct = string.match(str, "^([^.]+)%.(.*)")
        if not s then
            return nil, "malformed ciphertext"
        end
        local salt = decode64(s)
        local data = decode64(ct)
        if not salt or not data then
            return nil, "malformed ciphertext"
        end
        local a = aes:new(key, salt, cipher, hash, rounds)
        return a and a:decrypt(data)
    end}
end
