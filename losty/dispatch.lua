--
-- Generated from dispatch.lt
--
return function(handlers, req, res)
    local i, n = 0, #handlers
    local args, a = {}, 0
    local nxt = req.next
    req.next = function(...)
        for _, v in ipairs({...}) do
            a = a + 1
            args[a] = v
        end
        i = i + 1
        if i <= n then
            return handlers[i](req, res, unpack(args))
        end
    end
    local v = req.next()
    req.next = nxt
    return v
end
