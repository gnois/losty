--
-- Generated from web.lt
--
local json = require("cjson.safe")
local request = require("losty.req")
local response = require("losty.res")
local status = require("losty.status")
local choose = require("losty.accept")
local router = require("losty.router")
local dispatch = require("losty.dispatch")
math.randomseed(ngx.time())
local HTML = "text/html"
local JSON = "application/json"
return function()
    local rtr = router()
    local route = function(root)
        local r = {}
        for _, method in pairs({
            "get"
            , "post"
            , "put"
            , "delete"
            , "patch"
            , "options"
        }) do
            r[method] = function(path, f, ...)
                if string.sub(path, 1, 1) ~= "/" then
                    error("routed path " .. path .. " should start with '/'")
                end
                if root then
                    path = root .. path
                end
                rtr.set(string.upper(method), path, f, ...)
            end
        end
        return r
    end
    local must_no_body = function(req, code)
        return req.method == "HEAD" or code == 204 or code == 205 or code == 304
    end
    local run = function(errors)
        local req = request()
        local resp = response()
        local res = resp.create()
        local method = req.method
        if method == "HEAD" then
            method = "GET"
        end
        local handlers, params = rtr.match(method, req.uri)
        if handlers then
            req.params = params
            local ok, trace = xpcall(function()
                dispatch(handlers, req, res)
            end, function(err)
                return debug.traceback(err, 2)
            end)
            if ok then
                if not res.status then
                    error("Response status is missing", 2)
                end
                if res.status >= 200 and res.status < 300 or res.body and #res.body > 0 then
                    if not must_no_body(req, res.status) and not res.headers["Content-Type"] then
                        error("Content-Type header is missing", 2)
                    end
                end
            else
                res.status = 500
                ngx.log(ngx.ERR, trace)
            end
        else
            res.status = 404
        end
        if not res.body and res.status >= 400 then
            local pref = choose(req.headers["Accept"], {HTML, JSON})
            local ctype = tostring(pref[1])
            if req.method ~= "HEAD" then
                if ctype == JSON then
                    res.body = json.encode({fail = status(res.status)})
                else
                    if errors == true then
                        ngx.exit(res.status)
                    elseif errors then
                        res.body = errors[res.status]
                    end
                    if not res.body or #res.body < 1 then
                        ctype = "text/plain"
                        res.body = status(res.status)
                    end
                end
            end
            res.headers["Content-Type"] = ctype
        end
        resp.send_headers(req.secure)
        if not must_no_body(req, res.status) then
            resp.send_body()
        end
        resp.eof()
    end
    return {route = route, run = run}
end
