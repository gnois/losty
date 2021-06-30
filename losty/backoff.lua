--
-- Generated from backoff.lt
--
local ffi = require("ffi")
ffi.cdef([[
    struct backoff_req_rec {
        uint64_t        first;  /* first request time in milliseconds */
        unsigned        count;  /* number of requests since first */
    };
]])
local rec_ptr_type = ffi.typeof("struct backoff_req_rec*")
local rec_size = ffi.sizeof("struct backoff_req_rec")
local _M = {_VERSION = "0.07"}
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
    local initial = self.initial
    local now = ngx.now() * 1000
    local delay = 0
    local rec
    local v = dict:get(key)
    if v then
        if type(v) ~= "string" or #v ~= rec_size then
            return nil, "shdict abused by other users"
        end
        rec = ffi.cast(rec_ptr_type, v)
        local elapsed = now - tonumber(rec.first)
        local exp = math.pow(2, rec.count + initial) * 1000
        local wait = exp + math.random(0, math.ceil(exp / 3))
        delay = wait - elapsed
    end
    if commit then
        if rec then
            rec.count = rec.count + 1
        else
            rec = ffi.new("struct backoff_req_rec")
            rec.first = now
            rec.count = 1
        end
        dict:set(key, ffi.string(rec, rec_size))
    end
    return delay / 1000
end
_M.uncommit = function(self, key)
    assert(key)
    local dict = self.dict
    local v = dict:get(key)
    if not v then
        return nil, "not found"
    end
    if type(v) ~= "string" or #v ~= rec_size then
        return nil, "shdict abused by other users"
    end
    local rec = ffi.cast(rec_ptr_type, v)
    if rec.count > 0 then
        rec.count = rec.count - 1
    else
        rec.first = 0
        rec.count = 0
    end
    dict:set(key, ffi.string(rec, rec_size))
    return true
end
return _M
