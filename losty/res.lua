--
-- Generated from res.lt
--
local empty = require("table.isempty")
local enc = require("losty.enc")
local insert
insert = function(tb, v)
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
    elseif "table" == type(v) then
        insert(v, old)
        tb[k] = v
    else
        tb[k] = {old, v}
    end
end
local headers = setmetatable({}, {__metatable = false, __index = function(_, k)
    return ngx.header[k]
end, __newindex = function(_, k, v)
    if nil == v then
        ngx.header[k] = v
    else
        push(ngx.header, k, v)
    end
end})
local jar = {}
local cookie = function(name, httponly, domain, path)
    if not name then
        error("cookie must have a name")
    end
    local c = {_name = name, _httponly = httponly, _domain = domain, _path = path}
    local data = setmetatable({}, {__metatable = false, __index = c, __call = function(t, age, samesite, secure, encoder)
        c._age = age
        c._samesite = samesite
        c._secure = secure
        c._encoder = encoder
        return t
    end})
    if jar[name] then
        ngx.log(ngx.NOTICE, "Overwriting cookie named " .. name)
    end
    jar[name] = data
    return data
end
local bake = function(c)
    local encode = c._encoder or enc.encode
    local v
    if not empty(c) then
        v = ngx.escape_uri(encode(c))
    end
    local z = {c._name .. "=" .. (v or "")}
    local y = 2
    if c._domain then
        z[y] = "Domain=" .. c._domain
        y = y + 1
    end
    if c._path then
        z[y] = "Path=" .. c._path
        y = y + 1
    end
    local a = tonumber(c._age)
    if a then
        if a ~= 0 then
            z[y] = "Expires=" .. ngx.cookie_time(ngx.time() + a)
            y = y + 1
        end
        if a > 0 then
            z[y] = "Max-Age=" .. a
            y = y + 1
        end
    end
    local ss = c._samesite
    if ss then
        if "boolean" == type(ss) and ss then
            ss = "strict"
        end
        z[y] = "SameSite=" .. ss
        y = y + 1
    end
    if c._httponly then
        z[y] = "HttpOnly"
        y = y + 1
    end
    if c._secure then
        z[y] = "Secure"
    end
    return table.concat(z, ";")
end
return setmetatable({
    headers = headers
    , cookie = cookie
    , cookies = jar
    , nocache = function()
        headers["Cache-Control"] = "no-cache"
    end
    , cache = function(sec)
        if ngx.status < 400 then
            headers["Cache-Control"] = "max-age=" .. sec
        end
    end
    , redirect = function(url, same_method)
        if same_method then
            ngx.status = ngx.HTTP_TEMPORARY_REDIRECT
        else
            ngx.status = ngx.HTTP_SEE_OTHER
        end
        headers["Location"] = url
    end
    , send = function()
        local arr, n = {}, 0
        for _, c in pairs(jar) do
            n = n + 1
            arr[n] = bake(c)
        end
        if n > 0 then
            headers["Set-Cookie"] = arr
        end
        ngx.send_headers()
    end
}, {__metatable = false, __index = function(_, k)
    if "status" == k then
        return ngx.status
    end
end, __newindex = function(_, k, v)
    if "status" == k then
        ngx.status = v
    end
end})
