--
-- Generated from locked.lt
--
local locker = require("resty.lock")
local f = function(lock_name, key, expiry, read, write, ...)
    local val, err = read(key)
    if val == nil then
        local lock = locker:new(lock_name, {exptime = expiry})
        local ok
        ok, err = lock:lock(key)
        if ok then
            val, err = read(key)
            if val == nil then
                local write_ok, wval, werr = pcall(write, key, ...)
                if write_ok then
                    val, err = wval, werr
                else
                    err = wval
                    val = nil
                end
            end
            lock:unlock()
        end
    end
    return val, err
end
return f
