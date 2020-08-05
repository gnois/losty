--
-- Generated from body.lt
--
local upload = require("resty.upload")
local cjson = require("cjson.safe")
local str = require("losty.str")
local has_body = function(req)
    if not req.headers["Transfer-Encoding"] and not tonumber(req.headers["Content-Length"]) then
        return false, "Empty request body"
    end
    return true
end
local urlencoded = function(req)
    local ok, err = has_body(req)
    if ok then
        req.read_body()
        return req.get_post_args()
    end
    return ok, err
end
local raw = function(req)
    local ok, err = has_body(req)
    if ok then
        req.read_body()
        local data = req.get_body_data()
        if not data then
            local file = req.get_body_file()
            if file then
                local fp
                fp, err = io.open(file, "r")
                if fp then
                    data = fp:read("*a")
                    fp:close()
                end
            end
        end
        return data, err
    end
    return ok, err
end
local json = function(req)
    local r, err = raw(req)
    if r then
        return cjson.decode(r)
    end
    return r, err
end
local content_disposition = function(value)
    local dtype, params = string.match(value, "([%w%-%._]+);(.+)")
    if dtype and params then
        local out, o = {}, 0
        for param in str.gsplit(params, ";") do
            local key, val = string.match(param, "([%w%.%-_]+)=\"(.+)\"$")
            if key then
                o = o + 1
                out[o] = {key, val}
            end
        end
        return out
    end
end
local K = {}
K.buffered = function(req)
    local ctype = req.headers["Content-Type"]
    if ctype then
        if string.match(ctype, "octet-stream") then
            return raw(req)
        end
        if string.match(ctype, "urlencoded") then
            return urlencoded(req)
        end
        if string.match(ctype, "json") then
            return json(req)
        end
        return nil, "Unfamiliar content-type " .. ctype
    end
    return nil, "Missing content-type"
end
local yield = coroutine.yield
local parser = function()
    local input, err = upload:new(4096)
    if input then
        input:set_timeout(2000)
        local t, data
        repeat
            t, data, err = input:read()
            if t then
                if "header" == t then
                    local name, value = unpack(data)
                    if name == "Content-Disposition" then
                        local params = content_disposition(value)
                        if params then
                            for _, v in ipairs(params) do
                                yield(v[1], v[2])
                            end
                        end
                    else
                        yield(string.lower(name), value)
                    end
                elseif "body" == t then
                    yield(true, data)
                elseif "part_end" == t then
                    yield(false, nil)
                end
            else
                err = err or "Fail to parse upload data"
            end
        until not t or t == "eof"
    end
    return nil, err
end
K.multipart = function(req)
    local parse = coroutine.create(parser)
    return function()
        local ctype = req.headers["Content-Type"]
        if ctype and string.match(ctype, "multipart") then
            local code, key, val = coroutine.resume(parse)
            return key, val
        end
        return nil, "Expected multipart/form-data but received " .. ctype or "nil"
    end
end
return K
