--
-- Generated from web.lt
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
return function()
    local rt = router()
    local route = function(prefix)
        local r = {}
        for _, meth in ipairs(METHODS) do
            r[string.lower(meth)] = function(path, f, ...)
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
    return {route = route, run = run}
end
