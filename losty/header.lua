--
-- Generated from header.lau
--
local strz = require("losty.str")
local to = require("losty.to")
local ngx_header = ngx.header
local insert; insert = function(tb, v)
    if "table" == type(v) then
        for _, x in ipairs(v) do
            insert(tb, x)
        end
    else
        table.insert(tb, v)
    end
end
local push = function(tb, k, v)
    local old = tb[k]
    if nil == old then
        tb[k] = v
    elseif "table" == type(old) then
        insert(old, v)
        tb[k] = old
    else
        local oldt = {old}
        insert(oldt, v)
        tb[k] = oldt
    end
end
local TOKEN = "^[%w!#$%%&'*+.^_`|~-]+$"
local bad; bad = function(v)
    if "table" == type(v) then
        for _, x in ipairs(v) do
            local b = bad(x)
            if b then
                return b
            end
        end
        return nil
    end
    local c = string.match(tostring(v), "[%z\1-\8\10-\31\127]")
    if c then
        return string.byte(c)
    end
end
local headers = setmetatable({}, {__metatable = false, __index = function(_, k)
    return ngx_header[k]
end, __newindex = function(_, k, v)
    if "string" ~= type(k) or not string.match(k, TOKEN) then
        error("header name must be a http token (RFC 9110)", 2)
    end
    local t = type(v)
    if nil == v or t == "table" and next(v) == nil then
        ngx_header[k] = nil
    elseif t == "string" or t == "number" or t == "table" then
        local b = bad(v)
        if b then
            error(string.format("header '%s' value contains illegal byte 0x%02X", k, b), 2)
        end
        push(ngx_header, k, v)
    else
        error("header value must be a string, number or array of them, got " .. t, 2)
    end
end})
local vary = function(name)
    if "string" ~= type(name) or not string.match(name, TOKEN) then
        error("vary name must be a http token (RFC 9110)", 2)
    end
    local cur = ngx_header["Vary"]
    local txt = cur
    if "table" == type(cur) then
        txt = table.concat(cur, ", ")
    end
    if txt then
        local low = string.lower(name)
        for _, one in ipairs(strz.split(txt, ",")) do
            local seen = to.trim(one)
            if string.lower(seen) == low then
                return 
            end
        end
        ngx_header["Vary"] = txt .. ", " .. name
    else
        ngx_header["Vary"] = name
    end
end
local nocache = function()
    ngx_header["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    ngx_header["Pragma"] = "no-cache"
    ngx_header["Expires"] = ngx.http_time(ngx.time() - 86400)
end
local cache = function(status, sec)
    ngx.status = status
    if status < 400 then
        ngx_header["Cache-Control"] = "max-age=" .. sec
        local n = tonumber(sec)
        if n then
            ngx_header["Expires"] = ngx.http_time(ngx.time() + n)
        end
        ngx_header["Pragma"] = nil
    end
end
local redirect = function(url, same_method)
    if same_method then
        ngx.status = ngx.HTTP_TEMPORARY_REDIRECT
    else
        ngx.status = ngx.HTTP_SEE_OTHER
    end
    headers["Location"] = url
end
return {
    insert = insert
    , push = push
    , vary = vary
    , headers = headers
    , nocache = nocache
    , cache = cache
    , redirect = redirect
}
