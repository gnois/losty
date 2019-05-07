--
-- Generated from locked.lt
--
local rlock = require("resty.lock")
return function(lock, key, done, create, ...)
    local val, err = done(key)
    if val ~= nil then
        return val
    end
    local locker = rlock:new(lock)
    local elapsed
    elapsed, err = locker:lock(key)
    if not elapsed then
        ngx.log(ngx.ERR, "Fail to acquire '", key, "' from ", lock, ": ", err)
        return nil, err
    end
    ngx.log(ngx.INFO, "Acquired '", key, "' from ", lock, " after ", elapsed, " seconds")
    val, err = done(key)
    if val == nil then
        val, err = create(...)
    end
    local ok
    ok, err = locker:unlock()
    if not ok then
        ngx.log(ngx.ERR, "Fail to release '", key, "' from ", lock, ": ", err)
        return nil, err
    end
    return val, err
end
