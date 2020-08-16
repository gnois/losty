--
-- Generated from idempotent.lt
--
local locker = require("losty.lock")
local json = require("cjson.safe")
local crc32 = ngx.crc32_short
local abs = math.abs
return function(lock_name, cache_name, key)
    local cache = ngx.shared[cache_name]
    if not cache then
        error("missing lua_shared_dict " .. cache_name)
    end
    local lock = locker(lock_name)
    local crc = 1
    local start = function(id, expiry)
        if id ~= nil then
            crc = abs(crc32(id))
        end
        local ok, err = cache:safe_add(key, 1, expiry, crc)
        if ok then
            return 1, crc
        end
        return ok, err
    end
    local get = function(id)
        local val, flags = cache:get(key)
        if "number" == type(flags) then
            if id == nil and flags == 1 then
                return val, flags
            end
            if id and abs(crc32(id)) ~= flags then
                return val, "identity mismatch"
            end
        end
        return val, flags
    end
    return {acquire = function(id, secs, expiry)
        local val, c = get(id)
        if "string" == type(c) then
            return nil, c
        end
        crc = c
        local ok, err = lock.lock(key, secs)
        if ok then
            if c == nil then
                return start(id, expiry), nil
            end
            if "number" == type(val) then
                return val, nil
            end
            local result = json.decode(val)
            return result.status, result.body
        end
        return ok, err
    end, release = function()
        lock.unlock(key)
    end, advance = function()
        if lock.locked(key) then
            return cache:incr(key, 1)
        end
        return false, "not locked"
    end, complete = function(status, body, expiry)
        if lock.locked(key) then
            local str = json.encode({status = status, body = body})
            return cache:set(key, str, expiry, crc)
        end
        return false, "not locked"
    end}
end
