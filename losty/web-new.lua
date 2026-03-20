--
-- Generated from web-new.lt
--
local router = require("losty.router")
local dispatch = require("losty.dispatch")
local statuses = require("losty.status")
local req = require("losty.req")
local res = require("losty.res")
local METHODS = {
    "GET"
    , "POST"
    , "PUT"
    , "DELETE"
    , "PATCH"
    , "OPTIONS"
}
local apps = {}
local new = function()
    local rt = router()
    local sealed = false
    local route = function(prefix)
        if sealed then
            error("routes are sealed; define routes only in setup callback", 2)
        end
        local r = {}
        for _, meth in ipairs(METHODS) do
            r[string.lower(meth)] = function(path, f, ...)
                if sealed then
                    error("routes are sealed; define routes only in setup callback", 2)
                end
                if prefix and prefix ~= "/" then
                    path = prefix .. path
                end
                rt.set(meth, path, f, ...)
            end
        end
        return r
    end
    local run = function(error_page, check)
        local handlers, body, ok, trace
        local q = req()
        local r = res()
        local method = q.vars.request_method
        handlers, q.match = rt.match(method == "HEAD" and "GET" or method, q.vars.uri)
        if handlers then
            ok, trace = xpcall(function()
                body = dispatch(handlers, q, r)
            end, function(err)
                return debug.traceback(err, 2)
            end)
            if not ok then
                r.status = 500
                ngx.log(ngx.ERR, trace)
            end
        else
            r.status = 404
        end
        local code = r.status
        if error_page == true and body == nil and code >= 400 then
            ngx.exit(code)
            return code, trace
        end
        if check then
            if code == 0 then
                error("Response status required")
            end
            if body ~= nil or code >= 200 and code < 300 then
                if not statuses.is_empty(code) and r.headers["Content-Type"] == nil then
                    error("Content-Type header required")
                end
            end
        end
        local err
        ok, err = r.send()
        if ok then
            if method ~= "HEAD" and not statuses.is_empty(code) and body ~= nil then
                ok, err = ngx.print(body)
            end
            if ok then
                ok, err = ngx.eof()
            end
        end
        if not ok then
            ngx.log(ngx.ERR, err)
        end
        return code, err or trace
    end
    local api = {route = route, run = run}
    return {api = api, seal = function()
        sealed = true
    end}
end
local serve = function(setup, key)
    if type(setup) ~= "function" then
        error("setup must be a function", 2)
    end
    if not key then
        local info = debug.getinfo(2, "Sl") or {}
        key = tostring(info.short_src or "?") .. ":" .. tostring(info.currentline or 0)
    else
        key = tostring(key)
    end
    local app = apps[key]
    if not app then
        app = new()
        apps[key] = app
        setup(app.api)
        app.seal()
    end
    return app.api.run
end
return {serve = serve}
