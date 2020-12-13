--
-- Generated from crypt.lt
--
local aes = require("resty.aes")
return function(key, salt, size, mode, hash, rounds)
    size = size or 128
    mode = mode or "cbc"
    hash = hash or aes.hash.md5
    local cipher = aes.cipher(size, mode)
    local a = aes:new(key, salt, cipher, hash, rounds)
    return {encrypt = function(str)
        return a:encrypt(str)
    end, decrypt = function(str)
        return a:decrypt(str)
    end}
end
