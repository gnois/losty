--
-- Generated from res.lau
--
local cjson = require("cjson")
local hdr = require("losty.header")
local exec = function(uri, args)
    if not uri then
        error("uri required", 2)
    end
    return {__ngx_exec = true, uri = uri, args = args}
end
return function()
    local jar = {}
    local order, o = {}, 0
    local unsafe = function(txt)
        if not txt then
            return false
        end
        return string.match(txt, "[%c;]") ~= nil
    end
    local cookie = function(name, httponly, domain, path)
        if not name or string.match(name, "[%c;=,%s\"]") then
            error("cookie name must be a http token (RFC 6265)", 2)
        end
        if unsafe(domain) or unsafe(path) then
            error("cookie domain/path must not contain ';' or control characters", 2)
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
        val = val and ngx.escape_uri(tostring(val)) or ""
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
            if unsafe(ss) then
                error("cookie samesite must not contain ';' or control characters", 2)
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
            hdr.headers["Set-Cookie"] = arr
        end
        return ngx.send_headers()
    end
    local cookies = setmetatable({}, {__index = jar, __newindex = function()
        error("use response.cookie() to update response cookies", 2)
    end})
    return setmetatable({
        headers = hdr.headers
        , nocache = hdr.nocache
        , cache = hdr.cache
        , vary = hdr.vary
        , cookie = cookie
        , cookies = cookies
        , redirect = hdr.redirect
        , exec = exec
        , send = send
    }, {__metatable = false, __index = function(_, k)
        if "status" == k then
            return ngx.status
        end
    end, __newindex = function(t, k, v)
        if "status" == k then
            ngx.status = v
        else
            rawset(t, k, v)
        end
    end})
end
