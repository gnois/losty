--
-- Generated from flash.lt
--
local json = require("cjson.safe")
local tbl = require("losty.tbl")
local push = function(tb, k, v)
    local old = tb[k]
    if nil == old then
        old = {v}
    else
        if not tbl.find(old, v) then
            old[#old + 1] = v
        end
    end
    tb[k] = old
end
local encode = function(obj)
    assert(obj)
    local str = json.encode(obj)
    return ngx.encode_base64(str)
end
local decode = function(str)
    if str then
        str = ngx.decode_base64(str)
        return json.decode(str)
    end
end
local Flash = "flash"
local make = function(res)
    return res.cookie(Flash, false, nil, "/")
end
local transfer = function(req, res, old, new)
    if not new then
        new = make(res)(nil, true, req.secure, encode)
    end
    if old then
        for k, v in pairs(old) do
            new[k] = v
        end
    end
    return nil, new
end
return function(req, res)
    local old = req.cookies[Flash]
    if old then
        old = decode(old)
    end
    local new = res.cookies[Flash]
    local K = {set = function(key, val)
        old, new = transfer(req, res, old, new)
        new[key] = val
    end, get = function(key)
        if old and old[key] then
            return old[key]
        end
        if new then
            return new[key]
        end
    end, delete = function(key)
        if key then
            old, new = transfer(req, res, old, new)
            new[key] = nil
        else
            make(res)(-100)
        end
    end}
    return K
end
