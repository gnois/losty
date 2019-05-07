--
-- Generated from scrypt.lt
--
local ffi = require("ffi")
ffi.cdef([[
/* https://github.com/technion/libscrypt/blob/master/crypto_scrypt-hash.c  */
/*  returns +ve if succeed  */
int libscrypt_hash(char *crypted, const char* password, uint32_t N, uint8_t r, uint8_t p);

/* https://github.com/technion/libscrypt/blob/master/crypto_scrypt-check.c  */
/*  returns -ve if error, 0 if not match, else +ve  */
int libscrypt_check(char *crypted, const char *password);
]])
local cstrz = ffi.typeof("char[?]")
local const_cstrz = ffi.typeof("const char[?]")
local scrypt = ffi.load("scrypt")
local SCRYPT_MCF_LEN = 128
local SCRYPT_N = 16384
local SCRYPT_r = 8
local SCRYPT_p = 2
local K = {}
K.hash = function(password)
    if password then
        local out = cstrz(SCRYPT_MCF_LEN)
        local pwd = const_cstrz(#password, password)
        if scrypt.libscrypt_hash(out, pwd, SCRYPT_N, SCRYPT_r, SCRYPT_p) > 0 then
            return ffi.string(out)
        end
    end
end
K.check = function(hashed, pwd)
    if hashed and pwd then
        local gold = cstrz(#hashed, hashed)
        local sand = const_cstrz(#pwd, pwd)
        return scrypt.libscrypt_check(gold, sand) > 0
    end
end
return K
