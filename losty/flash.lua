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
return function(req, res)
    local new = res.cookies["flash"]
    if not new then
        new = res.cookies.create("flash", 0, false, nil, "/", enc.encode)
        local old = req.cookies.parse("flash", enc.decode)
        if old then
            for k, v in pairs(old) do
                new[k] = v
            end
        end
    end
    local K = {}
    K.set = function(key, val)
        new[key] = val
    end
    for _, meth in pairs({"pass", "fail", "info"}) do
        K[meth] = function(str)
            if not new.note then
                new.note = {}
            end
            push(new.note, meth, str)
        end
    end
    return K
end
