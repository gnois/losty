--
-- Generated from req.lt
--
local ngx_var = ngx.var
local bit = require("bit")
local ffi = require("ffi")
local to = require("losty.to")
local proxy = require("losty.proxy")
local read_uid = function()
    local str = ngx_var.uid_set or ngx_var.uid_got
    if str then
        local ind = string.find(str, "=")
        if ind > 0 then
            local uid = string.sub(str, ind + 1)
            if string.len(uid) == 32 then
                return uid
            end
        end
    end
end
local read_request_id = function()
    return ngx_var.http_x_request_id or ngx_var.request_id or read_uid()
end
local binary = function(v)
    local int32 = ffi.typeof("int32_t")
    local int32slot = ffi.typeof("int32_t[1]")
    return ffi.string(int32slot(bit.bswap(v)), ffi.sizeof(int32))
end
local read_uid_binary = function()
    local uid = read_uid()
    if uid then
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
local userid = {id = read_uid, request_id = read_request_id, id_binary = read_uid_binary, id_base64 = function()
    local v = read_uid_binary()
    return v and ngx.encode_base64(v)
end}
local cookies = setmetatable({}, {__metatable = false, __index = function(_, name)
    local v = ngx_var["cookie_" .. name]
    return v and ngx.unescape_uri(v)
end})
local args = setmetatable({}, {__metatable = false, __index = function(_, name)
    return ngx_var["arg_" .. name]
end})
local headers = setmetatable({}, {__metatable = false, __index = function(_, name)
    local key = string.lower(string.gsub(name, "-", "_"))
    if key == "content_type" then
        return ngx_var.content_type
    end
    if key == "content_length" then
        return ngx_var.content_length
    end
    return ngx_var["http_" .. key]
end})
local client_ip = function(trusted)
    return proxy.client_ip(ngx_var, headers, trusted)
end
local forwarded = function()
    return proxy.parse_forwarded(ngx_var.http_forwarded)
end
local canonical_url = function(trusted)
    return proxy.canonical_url({vars = ngx_var, headers = headers, secure = function()
        return ngx_var.https == "on"
    end}, trusted)
end
return function()
    return setmetatable({
        vars = ngx_var
        , headers = headers
        , cookies = cookies
        , args = args
        , secure = function()
            return ngx_var.https == "on"
        end
        , client_ip = client_ip
        , forwarded = forwarded
        , canonical_url = canonical_url
    }, {__metatable = false, __index = function(tbl, key)
        local fn = userid[key]
        if fn then
            local v = fn()
            tbl[key] = v
            return v
        end
        return ngx.req[key]
    end})
end
