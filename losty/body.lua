--
-- Generated from body.lau
--
local upload = require("resty.upload")
local cjson = require("cjson.safe")
local str = require("losty.str")
local MaxBody = 10 * 1024 * 1024
local body_size = function(req)
    local data = req.get_body_data()
    if data ~= nil then
        return #data
    end
    local file = req.get_body_file()
    if file then
        local fp = io.open(file, "rb")
        if fp then
            local sz = fp:seek("end")
            fp:close()
            return sz
        end
    end
    return nil
end
local raw = function(req)
    local data = req.get_body_data()
    if data == nil then
        local file = req.get_body_file()
        if file then
            local fp, err = io.open(file, "rb")
            if not fp then
                return nil, err
            end
            data = fp:read("*a")
            fp:close()
            if data == nil then
                return nil, "failed to read request body file"
            end
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
local cap = function(mmt)
    return mmt and mmt > 0 and mmt or MaxBody
end
local parser = function(max)
    local input, err = upload:new(4096)
    if input then
        input:set_timeout(8000)
        local t, data
        local used = 0
        local limit = cap(max)
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
                    used = used + #data
                    if used > limit then
                        err = "request body too large"
                        break
                    end
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
end, prepare = function(req, max)
    local limit = cap(max)
    local len = tonumber(req.headers["Content-Length"])
    if len and len > limit then
        return nil, "too_large", len
    end
    if req.headers["Transfer-Encoding"] or req.headers["Content-Length"] then
        req.read_body()
        if not len then
            local size = body_size(req)
            if size and size > limit then
                return nil, "too_large", size
            end
        end
        local ctype = req.headers["Content-Type"]
        if ctype then
            local base = string.match(ctype, "^%s*([^;]+)")
            if base then
                base = string.lower(string.match(base, "^%s*(.-)%s*$"))
                if base == "application/x-www-form-urlencoded" then
                    return req.get_post_args()
                end
                if base == "application/octet-stream" then
                    return raw(req)
                end
                if base == "application/json" or string.match(base, "%+json$") then
                    return json(req)
                end
                if string.match(base, "^multipart/") then
                    return function()
                        local parse = coroutine.create(parser, max)
                        return function()
                            local code, key, val = coroutine.resume(parse)
                            if not code then
                                return nil, key
                            end
                            return key, val
                        end
                    end
                end
            end
            return nil, "unsupported", ctype
        end
        return nil, "missing content-type"
    end
    return false, "possibly empty request body"
end}
