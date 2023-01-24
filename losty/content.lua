--
-- Generated from content.lt
--
local cjson = require("cjson")
local etag = require("losty.etag")
local strz = require("losty.str")
local body = require("losty.body")
local accept = require("losty.accept")
local dispatch = require("losty.dispatch")
local HTML = "text/html"
local JSON = "application/json"
local reject = function(_, res)
    res.status = ngx.HTTP_NOT_ACCEPTABLE
end
local html = function(req, res)
    local out = req.next()
    res.headers["Content-Type"] = HTML
    res.nocache()
    return out
end
local json = function(req, res)
    local out = req.next()
    res.headers["Content-Type"] = JSON
    out = cjson.encode(out)
    local cachectrl = res.headers["Cache-Control"]
    if cachectrl and (strz.contains(cachectrl, "no-cache") or strz.contains(cachectrl, "no-store")) then
        return out
    end
    local tag = etag(out, true)
    if tag then
        if tag == req.headers["If-None-Match"] then
            res.status = ngx.HTTP_NOT_MODIFIED
            return 
        end
        res.headers["ETag"] = tag
    end
    return out
end
local dual = function(...)
    local handlers = {...}
    return function(req, res)
        res.headers["Vary"] = "Accept"
        local pref = accept(req.headers["Accept"], {HTML, JSON})
        if tostring(pref[1]) == HTML then
            return dispatch(handlers, req, res)
        end
        return json(req, res)
    end
end
local form = function(req, res)
    local val, err = body.prepare(req)
    if val or "DELETE" == req.vars.request_method then
        return req.next(val)
    end
    res.status = ngx.HTTP_BAD_REQUEST
    return {fail = err or "no request body"}
end
return {form = form, reject = reject, html = html, json = json, dual = function(...)
    return dual(html, ...), reject
end}
