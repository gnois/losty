--
-- Generated from res.lt
--
local is = require("losty.is")
local tbl = require("losty.tbl")
local str = require("losty.str")
local header = function()
    local normalize = function(txt)
        return string.gsub(txt, "_", "-"):lower():gsub("^%l", string.upper):gsub("-%l", string.upper)
    end
    local headers = {}
    return {set = function()
        for k, v in pairs(headers) do
            ngx.header[k] = v
        end
    end, new = function()
        return setmetatable({delete = function(name)
            headers[name] = nil
        end}, {__metatable = false, __index = function(_, k)
            local key = normalize(k)
            return headers[key]
        end, __newindex = function(_, k, v)
            local key = normalize(k)
            tbl.add(headers, key, v)
        end})
    end}
end
local cookie = function()
    local escape = ngx.escape_uri
    local insert = table.insert
    local concat = table.concat
    local cookies = {}
    local metas = {}
    return {set = function(secure)
        for k, m in pairs(metas) do
            local val = cookies[k] or ""
            if m.encode then
                val = m.encode(val)
            else
                val = tostring(val)
            end
            local age = tonumber(m.age)
            local expires
            if age ~= 0 then
                expires = ngx.cookie_time(ngx.time() + age) or nil
            end
            if age <= 0 then
                age = nil
            end
            local txt = {k, "="}
            insert(txt, escape(val))
            if expires then
                insert(txt, "; Expires=" .. expires)
            end
            if age then
                insert(txt, "; Max-Age=" .. age)
            end
            if m.domain then
                insert(txt, "; Domain=" .. m.domain)
            end
            if m.path then
                insert(txt, "; Path=" .. m.path)
            end
            if m.samesite then
                insert(txt, "; SameSite=strict")
            end
            if m.httponly then
                insert(txt, "; HttpOnly")
            end
            if secure then
                insert(txt, "; Secure")
            end
            tbl.add(ngx.header, "Set-Cookie", concat(txt))
        end
    end, new = function()
        return setmetatable({create = function(name, age, httponly, domain, path, samesite, encode)
            metas[name] = {
                age = age
                , httponly = httponly
                , domain = domain
                , path = path
                , samesite = samesite
                , encode = encode
            }
            cookies[name] = {}
            return cookies[name]
        end, delete = function(name, httponly, domain, path)
            metas[name] = {age = -24 * 3600, httponly = httponly, domain = domain, path = path}
            cookies[name] = "null"
        end}, {__metatable = false, __index = function(_, name)
            return cookies[name]
        end, __newindex = function(_, name, val)
            if not metas[name] then
                error("call create('" .. name .. "', ...) before using response cookie")
            end
            cookies[name] = val
        end})
    end}
end
return function()
    local headers = header()
    local cookies = cookie()
    local res = {status = nil, body = nil, headers = headers.new(), cookies = cookies.new()}
    res.render = function(template, data)
        res.body = (string.gsub(template, "{([_%w%.]*)}", function(s)
            local keys = str.split(s, "%.")
            local v = data[keys[1]]
            for i = 2, #keys do
                v = v[keys[i]]
            end
            return v or "{" .. s .. "}"
        end))
    end
    res.nocache = function()
        res.headers["Cache-Control"] = "no-cache"
    end
    res.cache = function(sec)
        res.headers["Cache-Control"] = "max-age=" .. sec
    end
    res.redirect = function(url, same_method)
        if same_method then
            res.status = 307
        else
            res.status = ngx.HTTP_SEE_OTHER
        end
        res.headers["Location"] = url
    end
    res.ok = function(body)
        res.status = ngx.HTTP_OK
        res.body = body
    end
    return {send_headers = function(secure)
        if res.status then
            ngx.status = res.status
        end
        headers.set()
        cookies.set(secure)
        ngx.send_headers()
    end, send_body = function()
        if is.func(res.body) then
            local co = coroutine.create(res.body)
            repeat
                local ok, val = coroutine.resume(co)
                if ok and val then
                    ngx.print(val)
                    ngx.flush(true)
                end
            until not ok
        else
            ngx.print(res.body)
        end
    end, eof = function()
        ngx.eof()
    end, create = function()
        return res
    end}
end
