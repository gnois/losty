--
-- Generated from cors.lau
--
local concat = table.concat
local ngx_header = ngx.header
local hdr = require("losty.header")
local to = require("losty.to")
local insert = hdr.insert
local new = function()
    local hosts = {}
    local headers = {}
    local methods = {}
    local expose_headers = {}
    local max_age = 3600
    local credentials = true
    local K = {}
    K.host = function(host)
        insert(hosts, host)
    end
    K.method = function(method)
        insert(methods, method)
    end
    K.header = function(header)
        insert(headers, header)
    end
    K.expose_header = function(header)
        insert(expose_headers, header)
    end
    K.max_age = function(age)
        max_age = age
    end
    K.credentials = function(cred)
        credentials = cred
    end
    local reflected = function(req)
        local raw = req.headers["Access-Control-Request-Headers"]
        if not raw then
            return nil
        end
        local out = {}
        for one in string.gmatch(raw, "[^,]+") do
            local t = to.trim(one)
            if t ~= "" then
                out[#out + 1] = t
            end
        end
        if #out == 0 then
            return nil
        end
        return concat(out, ",")
    end
    local run = function(req, res, nxt)
        local origin = req.headers["Origin"]
        if not origin then
            return nxt()
        end
        res.vary("Origin")
        local allowed = false
        for _, v in ipairs(hosts) do
            if ngx.re.find(origin, "^" .. v .. "$", "jo") then
                allowed = true
                break
            end
        end
        local preflight = "OPTIONS" == req.vars.request_method
        if not allowed then
            if preflight then
                res.status = 204
                return 
            end
            return nxt()
        end
        ngx_header["Access-Control-Allow-Origin"] = origin
        if credentials then
            ngx_header["Access-Control-Allow-Credentials"] = "true"
        end
        if #expose_headers > 0 then
            ngx_header["Access-Control-Expose-Headers"] = concat(expose_headers, ",")
        end
        if preflight then
            ngx_header["Access-Control-Max-Age"] = max_age
            if #methods > 0 then
                ngx_header["Access-Control-Allow-Methods"] = concat(methods, ",")
            end
            local allow
            if #headers > 0 then
                allow = concat(headers, ",")
            else
                allow = reflected(req)
                if allow then
                    res.vary("Access-Control-Request-Headers")
                end
            end
            if allow then
                ngx_header["Access-Control-Allow-Headers"] = allow
            end
            ngx_header["Content-Type"] = nil
            ngx_header["Content-Length"] = nil
            res.status = 204
            return 
        end
        return nxt()
    end
    return setmetatable(K, {__call = function(_)
        return run
    end})
end
return {new = new}
