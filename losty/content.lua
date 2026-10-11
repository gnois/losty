--
-- Generated from content.lau
--
local cjson = require("cjson")
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
    return function(req, res, nxt)
        res.headers["Content-Type"] = ctype
        return nxt()
    end
end
local reject = function(_, res)
    res.vary("Accept")
    res.status = ngx.HTTP_NOT_ACCEPTABLE
end
local html = function(req, res, nxt)
    local out = nxt()
    res.headers["Content-Type"] = HTML
    if res.headers["Cache-Control"] == nil then
        res.nocache()
    end
    return out
end
local json = function(req, res, nxt)
    res.headers["Content-Type"] = JSON
    if req.args.pretty ~= nil then
        res.pretty = true
    end
    return nxt()
end
local timing = function(opts)
    local total = not opts or opts.total ~= false
    local desc = opts and opts.total_desc or "Total Response Time"
    local origin = opts and opts.cross_origin
    return function(_, res, nxt)
        if origin then
            res.headers["Timing-Allow-Origin"] = origin == true and "*" or origin
        end
        if total then
            res.start("total", desc)
        end
        local out = nxt()
        if total then
            res.stop("total")
        end
        return out
    end
end
local dual = function(...)
    local inner = {...}
    return function(req, res, nxt, ...)
        res.vary("Accept")
        local pref = accept.media(req.headers["Accept"], {HTML, JSON})
        if not pref[1] then
            res.status = ngx.HTTP_NOT_ACCEPTABLE
            return 
        end
        if tostring(pref[1]) == HTML then
            return dispatch(inner, req, res, ...)
        end
        local outer = {json}
        for i = 2, #inner do
            outer[i] = inner[i]
        end
        return dispatch(outer, req, res, ...)
    end
end
local problem = function(req, res, nxt)
    local out = nxt()
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
local form_limit = function(max)
    return function(req, res, nxt)
        local val, reason, detail = body.prepare(req, max)
        if val or "DELETE" == req.vars.request_method then
            return nxt(val)
        end
        if reason == "too_large" then
            res.status = ngx.HTTP_REQUEST_ENTITY_TOO_LARGE
            return {fail = "request body too large"}
        end
        if reason == "unsupported" then
            res.status = ngx.HTTP_UNSUPPORTED_MEDIA_TYPE
            return {fail = "unsupported content-type " .. (detail or "")}
        end
        res.status = ngx.HTTP_BAD_REQUEST
        return {fail = reason or "no request body"}
    end
end
return {
    form = form_limit(nil)
    , form_limit = form_limit
    , reject = reject
    , mime = mime
    , timing = timing
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
