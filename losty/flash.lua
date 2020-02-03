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
        print(str)
        str = ngx.decode_base64(str)
        print(str)
        return json.decode(str)
    end
end
local Msg = "_msg"
local Flash = "flash"
return function(req, res)
    local old = req.cookies[Flash]
    local new = res.cookies[Flash]
    if not new then
        new = res.cookie(Flash, false, nil, "/")(nil, true, req.secure, encode)
    end
    if old then
        local x = decode(old)
        if x then
            for k, v in pairs(x) do
                new[k] = v
            end
        end
    end
    local K = {set = function(key, val)
        new[key] = val
    end, get = function(key)
        return new[key]
    end}
    for _, meth in pairs({"pass", "fail", "warn", "info"}) do
        K[meth] = function(str)
            if not new[Msg] then
                new[Msg] = {}
            end
            push(new[Msg], meth, str)
        end
    end
    return K
end
