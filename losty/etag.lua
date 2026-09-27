--
-- Generated from etag.lau
--
local sha1 = require("resty.sha1")
local str = require("resty.string")
local strz = require("losty.str")
local etag = function(payload, weak)
    local sha = sha1:new()
    if sha:update(payload) then
        local digest = sha:final()
        local tag = str.to_hex(digest)
        if weak then
            return "W/\"" .. tag .. "\""
        end
        return "\"" .. tag .. "\""
    end
end
local opaque = function(tag)
    return string.match(tag, "^%s*[Ww]?/?\"(.-)\"%s*$")
end
local matches = function(header, tag)
    if not header then
        return false
    end
    if "*" == header then
        return true
    end
    local mine = opaque(tag)
    if not mine then
        return false
    end
    for _, one in ipairs(strz.split(header, ",")) do
        if mine == opaque(one) then
            return true
        end
    end
    return false
end
local strong_matches = function(header, tag)
    if not tag or string.match(tag, "^%s*[Ww]/") then
        return false
    end
    local mine = opaque(tag)
    if not mine then
        return false
    end
    for _, one in ipairs(strz.split(header, ",")) do
        if not string.match(one, "^%s*[Ww]/") and mine == opaque(one) then
            return true
        end
    end
    return false
end
local modified_since = function(req, res)
    local last = res.headers["Last-Modified"]
    if "string" ~= type(last) then
        return false
    end
    local since = req.headers["If-Modified-Since"]
    if "string" ~= type(since) then
        return false
    end
    local a = ngx.parse_http_time(last)
    local b = ngx.parse_http_time(since)
    if not a or not b then
        return false
    end
    return a <= b
end
local check = function(req, res, out)
    if "string" ~= type(out) or "" == out then
        return out
    end
    local code = res.status
    if not (0 == code or ngx.HTTP_OK == code) then
        return out
    end
    local method = req.vars.request_method
    if "GET" ~= method and "HEAD" ~= method then
        return out
    end
    local tag = res.headers["ETag"]
    if tag then
        if "string" ~= type(tag) then
            return out
        end
    else
        local cachectrl = res.headers["Cache-Control"]
        if "table" == type(cachectrl) then
            cachectrl = table.concat(cachectrl, ", ")
        end
        if cachectrl and strz.contains(string.lower(cachectrl), "no-store") then
            return out
        end
        tag = etag(out, true)
        if not tag then
            return out
        end
        res.headers["ETag"] = tag
    end
    local inm = req.headers["If-None-Match"]
    if inm then
        if matches(inm, tag) then
            res.status = ngx.HTTP_NOT_MODIFIED
            return 
        end
    elseif modified_since(req, res) then
        res.status = ngx.HTTP_NOT_MODIFIED
        return 
    end
    return out
end
local pass = function(req, res, tag)
    local im = req.headers["If-Match"]
    if im then
        if "*" == im then
            if not tag then
                res.status = ngx.HTTP_PRECONDITION_FAILED
                return false
            end
        elseif not strong_matches(im, tag) then
            res.status = ngx.HTTP_PRECONDITION_FAILED
            return false
        end
    end
    local inm = req.headers["If-None-Match"]
    if inm then
        if "*" == inm then
            if tag then
                res.status = ngx.HTTP_PRECONDITION_FAILED
                return false
            end
        elseif tag and matches(inm, tag) then
            res.status = ngx.HTTP_PRECONDITION_FAILED
            return false
        end
    end
    return true
end
local precondition = function(get_tag)
    if "function" ~= type(get_tag) then
        error("etag.precondition requires a tag getter function", 2)
    end
    return function(req, res, nxt)
        local method = req.vars.request_method
        if "GET" == method or "HEAD" == method then
            return nxt()
        end
        local tag = get_tag(req)
        if tag ~= nil and "string" ~= type(tag) then
            error("etag.precondition: get_tag must return a string or nil, got " .. type(tag), 2)
        end
        if not pass(req, res, tag) then
            return 
        end
        return nxt()
    end
end
return setmetatable({etag = etag, matches = matches, check = check, precondition = precondition}, {__metatable = false, __call = function(_, payload, weak)
    return etag(payload, weak)
end})
