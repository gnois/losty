--
-- Generated from idempotent.lt
--
local locker = require("losty.lock")
local json = require("cjson.safe")
local crc32 = ngx.crc32_short
local intmax = 2147483647
return function(lock_name, cache_name, key)
    local cache = ngx.shared[cache_name]
    if not cache then
        error("missing lua_shared_dict " .. cache_name)
    end
    local lock = locker(lock_name)
    local crc = 1
    local expire = 0
    local start = function(id)
        if id ~= nil then
            crc = crc32(id) % intmax
        end
        local ok, err = cache:safe_add(key, 1, expire, crc)
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
            if id and crc32(id) % intmax ~= flags then
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
        expire = expiry or 0
        local ok, err = lock.lock(key, secs)
        if ok then
            if c == nil then
                return start(id), nil
            end
            if "number" == type(val) then
                return val, nil
            end
            local out = json.decode(val)
            return out.state, out.data
        end
        return ok, err
    end, release = function()
        lock.unlock(key)
    end, advance = function()
        if lock.locked(key) then
            return cache:incr(key, 1)
        end
        return false, "not locked"
    end, save = function(state, data)
        if lock.locked(key) then
            local val = state
            if data ~= nil then
                val = json.encode({state = state, data = data})
            end
            local ok, err = cache:replace(key, val, expire, crc)
            if ok then
                return state
            end
            return ok, err
        end
        return false, "not locked"
    end}
end
