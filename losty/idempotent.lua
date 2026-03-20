--
-- Generated from idempotent.lt
--
local locker = require("losty.lock")
local json = require("cjson.safe")
local crc32 = ngx.crc32_short
local intmax = 2147483647
return function(lock_name, dict_name, key)
    local cache = ngx.shared[dict_name]
    if not cache then
        error("missing lua_shared_dict " .. tostring(dict_name), 2)
    end
    local lock = locker(lock_name)
    local ctx_key = "losty_idemp_" .. dict_name .. "_" .. key
    local start = function(id, expire, crc)
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
        local crc = c or 1
        expiry = expiry or 0
        local ok, err = lock.lock(key, secs)
        if ok then
            ngx.ctx[ctx_key] = {locked = true, crc = crc, expire = expiry}
            if c == nil then
                return start(id, expiry, crc), nil
            end
            if "number" == type(val) then
                return val, nil
            end
            local out = json.decode(val)
            return out.state, out.data
        end
        ngx.ctx[ctx_key] = nil
        return ok, err
    end, release = function()
        local st = ngx.ctx[ctx_key]
        if st and st.locked then
            lock.unlock(key)
            ngx.ctx[ctx_key] = nil
            return true
        end
        return false, "not locked by request"
    end, advance = function()
        local st = ngx.ctx[ctx_key]
        if st and st.locked and lock.locked(key) then
            return cache:incr(key, 1)
        end
        return false, "not locked by request"
    end, save = function(state, data)
        local st = ngx.ctx[ctx_key]
        if st and st.locked and lock.locked(key) then
            local val = state
            if data ~= nil then
                val = json.encode({state = state, data = data})
            end
            local ok, err = cache:replace(key, val, st.expire, st.crc)
            if ok then
                return state
            end
            return ok, err
        end
        return false, "not locked by request"
    end}
end
