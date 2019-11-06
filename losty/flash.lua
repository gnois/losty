--
-- Generated from flash.lt
--
local enc = require("losty.enc")
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
local Msg = "_Msg"
local Flash = "Flash"
return function(req, res)
    local new = res.cookies[Flash]
    if not new then
        new = res.cookie(Flash, false, nil, "/")(nil, true, req.secure, enc.encode)
    end
    local old = enc.decode(req.cookies[Flash])
    if old then
        for k, v in pairs(old) do
            new[k] = v
        end
    end
    local K = {set = function(key, val)
        new[key] = val
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
