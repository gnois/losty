--
-- Generated from cors.lt
--
local insert = table.insert
local concat = table.concat
local add_vary_origin = function()
    local vary = ngx.header["Vary"]
    if not vary then
        ngx.header["Vary"] = "Origin"
        return 
    end
    local has_origin = false
    if type(vary) == "table" then
        for _, v in ipairs(vary) do
            if v and string.find(string.lower(v), "origin", 1, true) then
                has_origin = true
                break
            end
        end
        if not has_origin then
            vary[#vary + 1] = "Origin"
            ngx.header["Vary"] = vary
        end
        return 
    end
    vary = tostring(vary)
    if not string.find(string.lower(vary), "origin", 1, true) then
        ngx.header["Vary"] = vary .. ", Origin"
    end
end
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
    K.run = function()
        local origin = ngx.req.get_headers()["Origin"]
        if not origin then
            return 
        end
        for _, v in pairs(hosts) do
            local from = ngx.re.find(origin, v, "jo")
            if from then
                ngx.header["Access-Control-Allow-Origin"] = origin
                ngx.header["Access-Control-Max-Age"] = max_age
                ngx.header["Access-Control-Expose-Headers"] = concat(expose_headers, ",")
                ngx.header["Access-Control-Allow-Headers"] = concat(headers, ",")
                ngx.header["Access-Control-Allow-Methods"] = concat(methods, ",")
                ngx.header["Access-Control-Allow-Credentials"] = tostring(credentials)
                add_vary_origin()
                break
            end
        end
    end
    return K
end
