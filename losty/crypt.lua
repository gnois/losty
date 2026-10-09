--
-- Generated from crypt.lau
--
local aes = require("resty.aes")
local rnd = require("resty.random")
local encode64 = ngx.encode_base64
local decode64 = ngx.decode_base64
local hmac = ngx.hmac_sha1
local IvLen = 16
return function(key, size, mode)
    if "string" ~= type(key) then
        error("key must be a string", 2)
    end
    size = size or 256
    mode = mode or "cbc"
    local cipher = aes.cipher(size, mode)
    if not cipher then
        error("unsupported cipher: size=" .. tostring(size) .. " mode=" .. tostring(mode), 2)
    end
    local k = hmac(key, "crypt-key|1") .. hmac(key, "crypt-key|2")
    local aeskey = string.sub(k, 1, size / 8)
    return {encrypt = function(str)
        local iv = rnd.bytes(IvLen)
        if not iv then
            return nil, "failed to generate random bytes"
        end
        local a, err = aes:new(aeskey, nil, cipher, {iv = iv})
        if not a then
            return nil, err or "encryption failed"
        end
        local ct = a:encrypt(str)
        if not ct then
            return nil, "encryption failed"
        end
        return encode64(iv) .. "." .. encode64(ct)
    end, decrypt = function(str)
        if "string" ~= type(str) then
            return nil, "malformed ciphertext"
        end
        local s, ct = string.match(str, "^([^.]+)%.(.*)")
        if not s then
            return nil, "malformed ciphertext"
        end
        local iv = decode64(s)
        local data = decode64(ct)
        if not iv or #iv ~= IvLen or not data then
            return nil, "malformed ciphertext"
        end
        local a, err = aes:new(aeskey, nil, cipher, {iv = iv})
        if not a then
            return nil, err or "decryption failed"
        end
        local out = a:decrypt(data)
        if not out then
            return nil, "decryption failed"
        end
        return out
    end}
end
