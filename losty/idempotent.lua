--
-- Generated from idempotent.lau
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
    local idcrc = function(id)
        return crc32(id) % intmax + 1
    end
    local start = function(id, expire, crc)
        if id ~= nil then
            crc = idcrc(id)
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
            if id ~= nil and idcrc(id) ~= flags then
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
        local ok, err = lock.lock(key, secs)
        if not ok then
            ngx.ctx[ctx_key] = nil
            return ok, err
        end
        val, c = get(id)
        if "string" == type(c) then
            lock.unlock(key)
            ngx.ctx[ctx_key] = nil
            return nil, c
        end
        expiry = expiry or 0
        ngx.ctx[ctx_key] = {locked = true, crc = c or 1, expire = expiry}
        if c == nil then
            local started, scrc = start(id, expiry, c or 1)
            if not started then
                lock.unlock(key)
                ngx.ctx[ctx_key] = nil
                return started, scrc
            end
            local st = ngx.ctx[ctx_key]
            st.crc = scrc
            return started, nil
        end
        if "number" == type(val) then
            return val, nil
        end
        local out = json.decode(val)
        if not out then
            return nil, "corrupt state"
        end
        return out.state, out.data
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
        if state == nil then
            return nil, "state required"
        end
        local st = ngx.ctx[ctx_key]
        if st and st.locked and lock.locked(key) then
            local val = state
            if data ~= nil then
                val = json.encode({state = state, data = data})
                if not val then
                    return nil, "failed to encode data"
                end
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
