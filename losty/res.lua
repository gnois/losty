--
-- Generated from res.lau
--
local cjson = require("cjson")
local hdr = require("losty.header")
local TOKEN = "^[%w!#$%%&'*+.^_`|~-]+$"
local MT = {__metatable = false, __index = function(_, k)
    if "status" == k then
        return ngx.status
    end
end, __newindex = function(t, k, v)
    if "status" == k then
        ngx.status = v
    else
        rawset(t, k, v)
    end
end}
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
    local hooks = {}
    local defer = function(fn, ...)
        if "function" ~= type(fn) then
            error("r.defer requires function", 2)
        end
        local np = select("#", ...)
        if np == 0 then
            table.insert(hooks, fn)
        else
            local args = {...}
            table.insert(hooks, function()
                return fn(unpack(args, 1, np))
            end)
        end
    end
    local run_defers = function()
        if #hooks == 0 then
            return 
        end
        local running = hooks
        hooks = {}
        for i = #running, 1, -1 do
            local ok, err = xpcall(running[i], function(trace)
                return debug.traceback(trace, 2)
            end)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        end
    end
    local metrics, m = {}, 0
    local timers = {}
    local now = function()
        ngx.update_time()
        return ngx.now()
    end
    local check_metric = function(name)
        if "string" ~= type(name) or not string.match(name, TOKEN) then
            error("Server-Timing metric name must be a token (RFC 9110)", 3)
        end
    end
    local check_desc = function(desc)
        if "string" ~= type(desc) or string.find(desc, "\"", 1, true) or string.find(desc, "\\", 1, true) or string.match(desc, "[%z\1-\31\127]") then
            error("Server-Timing description must not contain a quote, backslash or control characters", 3)
        end
    end
    local metric = function(name, dur, desc)
        check_metric(name)
        local s = name
        if dur ~= nil then
            if "number" ~= type(dur) then
                error("Server-Timing duration must be a number", 3)
            end
            s = s .. ";dur=" .. string.format("%.1f", dur)
        end
        if desc ~= nil then
            check_desc(desc)
            s = s .. ";desc=\"" .. desc .. "\""
        end
        m = m + 1
        metrics[m] = s
    end
    local start = function(name, desc)
        check_metric(name)
        if desc ~= nil then
            check_desc(desc)
        end
        timers[name] = {t = now(), desc = desc}
    end
    local stop = function(name)
        local tm = timers[name]
        if tm then
            timers[name] = nil
            metric(name, (now() - tm.t) * 1000, tm.desc)
        end
    end
    local server_timing = function()
        local open, i = {}, 0
        for k in pairs(timers) do
            i = i + 1
            open[i] = k
        end
        for _, k in ipairs(open) do
            stop(k)
        end
        if m == 0 then
            return nil
        end
        return table.concat(metrics, ", ")
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
        , defer = defer
        , run_defers = run_defers
        , metric = metric
        , start = start
        , stop = stop
        , server_timing = server_timing
        , send = send
    }, MT)
end
