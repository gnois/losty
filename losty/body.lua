--
-- Generated from body.lt
--
local upload = require("resty.upload")
local cjson = require("cjson.safe")
local str = require("losty.str")
local raw = function(req)
    local data = req.get_body_data()
    if not data then
        local file = req.get_body_file()
        if file then
            local fp, err = io.open(file, "r")
            if not fp then
                return fp, err
            end
            data = fp:read("*a")
            fp:close()
        end
    end
    return data
end
local json = function(req)
    local r, err = raw(req)
    if r then
        return cjson.decode(r)
    end
    return r, err
end
local yield = coroutine.yield
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
                err = err or "fail to parse upload data"
            end
        until not t or t == "eof"
    end
    return nil, err
end
return {raw = function(req)
    req.read_body()
    return raw(req)
end, prepare = function(req)
    if req.headers["Transfer-Encoding"] or req.headers["Content-Length"] then
        req.read_body()
        local ctype = req.headers["Content-Type"]
        if ctype then
            if string.match(ctype, "urlencoded") then
                return req.get_post_args()
            end
            if string.match(ctype, "octet-stream") then
                return raw(req)
            end
            if string.match(ctype, "json") then
                return json(req)
            end
            if string.match(ctype, "multipart") then
                return function()
                    local parse = coroutine.create(parser)
                    return function()
                        local code, key, val = coroutine.resume(parse)
                        return key, val
                    end
                end
            end
            return nil, "unfamiliar content-type " .. ctype
        end
        return nil, "missing content-type"
    end
    return false, "possibly empty request body"
end}
