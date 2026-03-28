--
-- Generated from res.lt
--
local cjson = require("cjson")
local ngx_header = ngx.header
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
    else
        local oldt = {old}
        insert(oldt, v)
        tb[k] = oldt
    end
end
local headers = setmetatable({}, {__metatable = false, __index = function(_, k)
    return ngx_header[k]
end, __newindex = function(_, k, v)
    if nil == v or type(v) == "table" and next(v) == nil then
        ngx_header[k] = nil
    else
        push(ngx_header, k, v)
    end
end})
local nocache = function()
    headers["Cache-Control"] = "no-cache"
end
local cache = function(status, sec)
    ngx.status = status
    if status < 400 then
        headers["Cache-Control"] = "max-age=" .. sec
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
local exec = function(uri, args)
    if not uri then
        error("uri required", 2)
    end
    return {__ngx_exec = true, uri = uri, args = args}
end
return function()
    local jar = {}
    local order, o = {}, 0
    local cookie = function(name, httponly, domain, path)
        if not name then
            error("cookie must have a name", 2)
        end
        local c = {_name = name, _httponly = httponly, _domain = domain, _path = path}
        local data = setmetatable({}, {__metatable = false, __index = c, __call = function(t, age, samesite, secure, value)
            c._age = age
            c._samesite = samesite
            c._secure = secure
            c._value = value
            return t
        end})
        if jar[name] then
            ngx.log(ngx.NOTICE, "Overwriting cookie " .. name)
        else
            o = o + 1
            order[o] = name
        end
        jar[name] = data
        return data
    end
    local bake = function(c)
        local val = c._value
        if val then
            if "function" == type(val) then
                val = val(c)
            end
        elseif next(c) ~= nil then
            val = cjson.encode(c)
        end
        val = val and ngx.escape_uri(val) or ""
        local z = {c._name .. "=" .. val}
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
        local secure = c._secure
        if ss ~= nil then
            if "boolean" == type(ss) then
                ss = ss and "strict" or "none"
            else
                ss = string.lower(ss)
            end
            z[y] = "SameSite=" .. ss
            y = y + 1
            if ss == "none" then
                secure = true
            end
        end
        if c._httponly then
            z[y] = "HttpOnly"
            y = y + 1
        end
        if secure then
            z[y] = "Secure"
        end
        return table.concat(z, ";")
    end
    local send = function()
        local arr = {}
        if o > 0 then
            for n, k in ipairs(order) do
                arr[n] = bake(jar[k])
            end
            headers["Set-Cookie"] = arr
        end
        return ngx.send_headers()
    end
    local cookies = setmetatable({}, {__index = jar, __newindex = function()
        error("use response.cookie() to update response cookies", 2)
    end})
    return setmetatable({
        headers = headers
        , nocache = nocache
        , cache = cache
        , cookie = cookie
        , cookies = cookies
        , redirect = redirect
        , exec = exec
        , send = send
    }, {__metatable = false, __index = function(_, k)
        if "status" == k then
            return ngx.status
        end
    end, __newindex = function(_, k, v)
        if "status" == k then
            ngx.status = v
        end
    end})
end
