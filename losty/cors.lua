--
-- Generated from cors.lau
--
local concat = table.concat
local ngx_header = ngx.header
local hdr = require("losty.header")
local insert = hdr.insert
return function()
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
    K.run = function(req, res)
        local origin = req.headers["Origin"]
        if not origin then
            return req.next()
        end
        res.vary("Origin")
        local allowed = false
        for _, v in ipairs(hosts) do
            if ngx.re.find(origin, "^" .. v .. "$", "jo") then
                allowed = true
                break
            end
        end
        if not allowed then
            return req.next()
        end
        ngx_header["Access-Control-Allow-Origin"] = origin
        ngx_header["Access-Control-Expose-Headers"] = concat(expose_headers, ",")
        if credentials then
            ngx_header["Access-Control-Allow-Credentials"] = "true"
        end
        if "OPTIONS" == req.vars.request_method then
            ngx_header["Access-Control-Max-Age"] = max_age
            ngx_header["Access-Control-Allow-Headers"] = concat(headers, ",")
            ngx_header["Access-Control-Allow-Methods"] = concat(methods, ",")
        end
        return req.next()
    end
    return K
end
