--
-- Generated from content.lt
--
local json = require("cjson")
local sha1 = require("resty.sha1")
local str = require("resty.string")
local strz = require("losty.str")
local body = require("losty.body")
local choose = require("losty.accept")
local dispatch = require("losty.dispatch")
local HTML = "text/html"
local JSON = "application/json"
local reject = function(req, res)
    res.status = 406
end
local dual = function(vary)
    return function(...)
        local hn = {...}
        return function(req, res, ...)
            if vary then
                res.headers["Vary"] = "Accept"
            end
            local pref = choose(req.headers["Accept"], {HTML, JSON})
            if tostring(pref[1]) == JSON then
                local out = req.next()
                res.headers["Content-Type"] = JSON
                json.encode_empty_table_as_object(false)
                res.body = json.encode(out)
                local cachectrl = res.headers["Cache-Control"]
                if cachectrl and (strz.contains(cachectrl, "no-cache") or strz.contains(cachectrl, "no-store")) then
                    return 
                end
                local sha = sha1:new()
                if sha:update(res.body) then
                    local digest = sha:final()
                    local etag = str.to_hex(digest)
                    etag = "W/\"" .. etag .. "\""
                    if etag == req.headers["If-None-Match"] then
                        res.status = 304
                        res.body = nil
                    else
                        res.headers["ETag"] = etag
                    end
                end
            else
                dispatch(hn, req, res, ...)
            end
        end
    end
end
local header = function(req, res)
    res.headers["Content-Type"] = HTML
    res.nocache()
    return req.next()
end
local form = function(req, res)
    local val, fail = body.buffered(req)
    if val or req.method == "DELETE" then
        return req.next(val)
    end
    res.status = 400
    return {fail = fail or req.method .. " should have request body"}
end
return {header = header, form = form, html = function(vary, ...)
    return dual(vary)(header, ...), reject
end, json = dual(false)(reject), reject = reject}
