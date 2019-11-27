--
-- Generated from req.lt
--
local bit = require("bit")
local ffi = require("ffi")
local read_uid = function()
    local str = ngx.var.uid_set or ngx.var.uid_got
    if str then
        local ind = string.find(str, "=")
        if ind > 0 then
            return string.sub(str, ind + 1)
        end
    end
    ngx.log(ngx.ERR, "req.id_xxx() functions requires nginx directive `userid on;`")
end
local binary = function(v)
    local int32 = ffi.typeof("int32_t")
    local int32slot = ffi.typeof("int32_t[1]")
    return ffi.string(int32slot(bit.bswap(v)), ffi.sizeof(int32))
end
local read_uid_binary = function()
    local uid = read_uid()
    if uid and string.len(uid) > 1 then
        local a = tonumber(string.sub(uid, 1, 8), 16)
        local b = tonumber(string.sub(uid, 9, 16), 16)
        local c = tonumber(string.sub(uid, 17, 24), 16)
        local d = tonumber(string.sub(uid, 25, 32), 16)
        a = bit.bswap(a)
        b = bit.bswap(b)
        c = bit.bswap(c)
        d = bit.bswap(d)
        local buff = {}
        buff[1] = binary(a)
        buff[2] = binary(b)
        buff[3] = binary(c)
        buff[4] = binary(d)
        local bytes16 = table.concat(buff, "")
        return bytes16
    end
end
local basic = {
    socket = function()
        return ngx.req.socket()
    end
    , headers = function()
        return ngx.req.get_headers()
    end
    , method = function()
        return ngx.req.get_method() or ngx.var.request_method
    end
    , at = function()
        return ngx.req.start_time()
    end
    , version = function()
        return ngx.req.http_version()
    end
    , args = function()
        return ngx.req.get_uri_args()
    end
    , scheme = function()
        return ngx.var.scheme or "http"
    end
    , query = function()
        return ngx.var.query_string
    end
    , host = function()
        return ngx.var.host or ngx.var.server_name
    end
    , url = function()
        return ngx.unescape_uri(ngx.var.request_uri)
    end
    , uri = function()
        return ngx.var.uri or ""
    end
    , full_uri = function(t)
        return t.scheme .. "://" .. t.host .. t.uri
    end
    , remote_addr = function(t)
        local ip = t.headers["X-Real-IP"] or t.headers["X-Forwarded-For"] or t.headers["X-Client-IP"] or ngx.var.remote_addr
        return ip
    end
    , remote_port = function()
        return ngx.var.remote_port
    end
    , secure = function(t)
        local scheme = t.headers["X-Forwarded-Proto"] or t.scheme
        return scheme == "https"
    end
    , id = read_uid
    , id_binary = read_uid_binary
    , id_base64 = function(t)
        return ngx.encode_base64(t.id_binary)
    end
}
return setmetatable({cookies = setmetatable({}, {__index = function(_, name)
    local v = ngx.var["cookie_" .. name]
    return v and ngx.unescape_uri(v)
end})}, {__metatable = false, __index = function(tbl, key)
    local f = basic[key]
    if f then
        local v = f(tbl)
        tbl[key] = v
        return v
    end
end})
