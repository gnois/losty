--
-- Generated from sigurl.lt
--
local enc = require("losty.enc")
local str = require("losty.str")
local hmac = ngx.hmac_sha1
local normalize = function(secrets)
    if not secrets then
        error("secret required", 2)
    end
    if type(secrets) == "table" then
        assert(#secrets > 0, "secret list cannot be empty")
        return secrets
    end
    return {secrets}
end
local sign_with = function(secret, payload, len)
    local sig = enc.encode64(hmac(secret, payload))
    if len and len > 1 then
        return string.sub(sig, 1, len)
    end
    return sig
end
return function(secrets, length)
    secrets = normalize(secrets)
    return {sign_raw = function(value)
        assert(value)
        return sign_with(secrets[1], value, length)
    end, verify_raw = function(sig, value)
        assert(value)
        if sig then
            for _, sec in ipairs(secrets) do
                if str.safe_equal(sign_with(sec, value, length), sig) then
                    return true
                end
            end
        end
        return false
    end, sign = function(path, ttl, extra)
        assert(path, "path required")
        local exp = 0
        if ttl and ttl > 0 then
            exp = ngx.time() + ttl
        end
        local payload = enc.encode({p = path, x = extra, e = exp})
        local sig = sign_with(secrets[1], payload, length)
        return sig .. "." .. payload
    end, verify = function(token, path, extra)
        if not token then
            return false, "missing token"
        end
        local sig, payload = string.match(token, "^(.*)%.(.*)$")
        if not payload then
            return false, "malformed token"
        end
        local ok = false
        for _, sec in ipairs(secrets) do
            if str.safe_equal(sign_with(sec, payload, length), sig) then
                ok = true
                break
            end
        end
        if not ok then
            return false, "bad signature"
        end
        local obj = enc.decode(payload)
        if not obj then
            return false, "bad payload"
        end
        if path and obj.p ~= path then
            return false, "path mismatch"
        end
        if extra ~= nil and obj.x ~= extra then
            return false, "extra mismatch"
        end
        if obj.e and obj.e > 0 and obj.e <= ngx.time() then
            return false, "expired"
        end
        return true, obj
    end}
end
