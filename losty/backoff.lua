--
-- Generated from backoff.lt
--
local _M = {_VERSION = "0.01"}
local mt = {__index = _M}
_M.new = function(dict_name, initial, ttl)
    local dict = ngx.shared[dict_name]
    if not dict then
        return nil, "shared dict not found"
    end
    assert(initial >= 0 and ttl > 0)
    local self = {dict = dict, initial = initial, ttl = ttl}
    return setmetatable(self, mt)
end
_M.incoming = function(self, key, commit)
    local dict = self.dict
    local now = ngx.now() * 1000
    local delay = 0
    local last, count = dict:get(key)
    if last and count then
        local elapsed = now - tonumber(last)
        local exp = math.pow(2, count + self.initial) * 1000
        local wait = exp + math.random(1, math.ceil(exp / 3))
        delay = wait - elapsed
    end
    if commit then
        if not count then
            count = 1
        else
            count = count + 1
        end
        last = now
        dict:set(key, last, self.ttl, count)
    end
    return delay / 1000, count
end
_M.uncommit = function(self, key)
    assert(key)
    local dict = self.dict
    local last, count = dict:get(key)
    if last and count then
        if count > 1 then
            count = count - 1
        end
        local ttl = dict:ttl(key)
        dict:set(key, last, ttl, count)
        return true
    end
    return nil, "not found"
end
return _M
