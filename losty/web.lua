--
-- Generated from web.lt
--
local json = require("cjson.safe")
local status = require("losty.status")
local accept = require("losty.accept")
local router = require("losty.router")
local dispatch = require("losty.dispatch")
local req = require("losty.req")
local res = require("losty.res")
local HTML = "text/html"
local JSON = "application/json"
return function()
    local rt = router()
    local route = function(prefix)
        local r = {}
        for _, method in ipairs({
            "get"
            , "post"
            , "put"
            , "delete"
            , "patch"
            , "options"
        }) do
            r[method] = function(path, f, ...)
                if prefix and prefix ~= "/" then
                    path = prefix .. path
                end
                rt.set(string.upper(method), path, f, ...)
            end
        end
        return r
    end
    local must_no_body = function(method, code)
        return method == "HEAD" or code == 204 or code == 205 or code == 304
    end
    local run = function(errors)
        local q = req()
        local r = res()
        local body
        local method = q.method
        if method == "HEAD" then
            method = "GET"
        end
        local handlers, matches = rt.match(method, q.uri)
        if handlers then
            q.match = matches
            local ok, trace = xpcall(function()
                body = dispatch(handlers, q, r)
            end, function(err)
                return debug.traceback(err, 2)
            end)
            if ok then
                if r.status == 0 then
                    error("response status required", 2)
                end
                if r.status >= 200 and r.status < 300 or body then
                    if not must_no_body(q.method, r.status) and not r.headers["Content-Type"] then
                        error("Content-Type header required", 2)
                    end
                end
            else
                r.status = 500
                ngx.log(ngx.ERR, trace)
            end
        else
            r.status = 404
        end
        if not body and r.status >= 400 then
            local pref = accept(q.headers["Accept"], {HTML, JSON})
            local ctype = tostring(pref[1])
            if q.method ~= "HEAD" then
                if ctype == JSON then
                    body = json.encode({fail = status(r.status)})
                else
                    if errors == true then
                        ngx.exit(r.status)
                    elseif errors then
                        body = errors[r.status]
                    end
                    if not body then
                        ctype = "text/plain"
                        body = status(r.status)
                    end
                end
            end
            r.headers["Content-Type"] = ctype
        end
        r.send()
        if body and not must_no_body(q.method, r.status) then
            if "function" == type(body) then
                local co = coroutine.create(body)
                repeat
                    local ok, val = coroutine.resume(co)
                    if ok and val then
                        ngx.print(val)
                        ngx.flush(true)
                    end
                until not ok
            else
                ngx.print(body)
            end
        end
        ngx.eof()
    end
    return {route = route, run = run}
end
