--
-- Generated from surl.lt
--
local hmac = ngx.hmac_sha1
local enc_url_chars = {["+"] = "-", ["/"] = "_", ["="] = "~"}
local dec_url_chars = {["-"] = "+", _ = "/", ["~"] = "="}
local enc64 = function(value)
    local s = ngx.encode_base64(value)
    return (string.gsub(s, "[+/=]", enc_url_chars))
end
local dec64 = function(value)
    local s = (string.gsub(value, "[-_~]", dec_url_chars))
    return ngx.decode_base64(s)
end
return function(secret)
    if not secret then
        error("secret is required to sign/verify", 2)
    end
    local K = {enc64 = enc64, dec64 = dec64}
    K.sign = function(fragment, length)
        assert(fragment)
        local mac = hmac(secret, fragment)
        mac = enc64(mac)
        if length then
            assert(length > 1)
            return string.sub(mac, 1, length)
        end
        return mac
    end
    K.verify = function(mac, fragment, length)
        assert(fragment)
        if mac then
            local dst = enc64(hmac(secret, fragment))
            if length then
                assert(length > 1)
                return string.sub(mac, 1, length) == string.sub(dst, 1, length)
            end
            return mac == dst
        end
        return false
    end
    return K
end
