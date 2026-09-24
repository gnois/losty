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
    return string.match(tag, "^%s*[Ww]?/\"(.-)\"%s*$")
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
    if matches(req.headers["If-None-Match"], tag) then
        res.status = ngx.HTTP_NOT_MODIFIED
        return 
    end
    return out
end
return setmetatable({etag = etag, matches = matches, check = check}, {__metatable = false, __call = function(_, payload, weak)
    return etag(payload, weak)
end})
