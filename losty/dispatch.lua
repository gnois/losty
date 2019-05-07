--
-- Generated from dispatch.lt
--
return function(hn, req, res, ...)
    local i, n = 0, #hn
    local nargs = select("#", ...)
    local args = {...}
    local nxt = req.next
    req.next = function(...)
        local np = select("#", ...)
        local p = {...}
        for j = 1, np do
            args[nargs + j] = p[j]
        end
        nargs = nargs + np
        i = i + 1
        if i <= n then
            return hn[i](req, res, unpack(args, 1, nargs))
        end
    end
    req.next()
    req.next = nxt
end
