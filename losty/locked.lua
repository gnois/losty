--
-- Generated from locked.lt
--
local locker = require("resty.lock")
return function(lock_name, key, expiry, read, write, ...)
    local val, err = read(key)
    if val ~= nil then
        return val
    end
    local lock = locker:new(lock_name, {exptime = expiry})
    local ok
    ok, err = lock:lock(key)
    if not ok then
        return nil, err
    end
    val, err = read(key)
    if val == nil then
        val, err = write(...)
    end
    ok, err = lock:unlock()
    return val, err
end
