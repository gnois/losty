--
-- Generated from lock.lt
--
return function(lock_name)
    local lock = ngx.shared[lock_name]
    if not lock then
        error("missing lua_shared_dict " .. lock_name)
    end
    return {lock = function(key, sec)
        return lock:add(key, true, sec)
    end, locked = function(key)
        return true == lock:get(key)
    end, unlock = function(key)
        lock:delete(key)
    end}
end
