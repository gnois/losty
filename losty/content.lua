--
-- Generated from content.lt
--
local cjson = require("cjson")
local etag = require("losty.etag")
local strz = require("losty.str")
local body = require("losty.body")
local accept = require("losty.accept")
local dispatch = require("losty.dispatch")
local statuses = require("losty.status")
local HTML = "text/html"
local JSON = "application/json"
local PROBLEM = "application/problem+json"
local with_text_charset = function(mime)
    if mime then
        local txt = string.lower(mime)
        if string.find(txt, "^text/") and not string.find(txt, ";%s*charset%s*=") then
            return mime .. "; charset=utf-8"
        end
    end
    return mime
end
local mime = function(kind)
    local ctype = with_text_charset(kind)
    return function(req, res)
        res.headers["Content-Type"] = ctype
        return req.next()
    end
end
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
local problem = function(req, res)
    local out = req.next()
    res.headers["Content-Type"] = PROBLEM
    if type(out) == "table" then
        if out.type == nil then
            out.type = "about:blank"
        end
        local code = tonumber(out.status) or res.status
        if code and code > 0 then
            if out.status == nil then
                out.status = code
            end
            if out.title == nil then
                out.title = statuses.text(code)
            end
        end
        out = cjson.encode(out)
    end
    return out
end
local form = function(req, res)
    local val, err = body.prepare(req)
    if val or "DELETE" == req.vars.request_method then
        return req.next(val)
    end
    res.status = ngx.HTTP_BAD_REQUEST
    return {fail = err or "no request body"}
end
return {
    form = form
    , reject = reject
    , mime = mime
    , text = function(kind)
        return mime(kind or "text/plain")
    end
    , html = html
    , json = json
    , problem = problem
    , dual = function(...)
        return dual(html, ...), reject
    end
}
