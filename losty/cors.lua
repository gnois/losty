--
-- Generated from cors.lt
--
local insert = table.insert
local concat = table.concat
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
K.run = function()
    local origin = ngx.req.get_headers()["Origin"]
    if not origin then
        return 
    end
    for _, v in pairs(hosts) do
        local from, to, err = ngx.re.find(origin, v, "jo")
        if from then
            ngx.header["Access-Control-Allow-Origin"] = origin
            ngx.header["Access-Control-Max-Age"] = max_age
            ngx.header["Access-Control-Expose-Headers"] = concat(expose_headers, ",")
            ngx.header["Access-Control-Allow-Headers"] = concat(headers, ",")
            ngx.header["Access-Control-Allow-Methods"] = concat(methods, ",")
            ngx.header["Access-Control-Allow-Credentials"] = tostring(credentials)
            break
        end
    end
end
return K
