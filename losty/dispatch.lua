--
-- Generated from dispatch.lt
--
local dispatch = function(hn, req, res, ...)
    local i, n = 0, #hn
    local nargs, aargs = 0
    local invoke = function(...)
        local np = select("#", ...)
        if np > 0 then
            local p = {...}
            aargs = aargs or {}
            for j = 1, np do
                aargs[nargs + j] = p[j]
            end
            nargs = nargs + np
        end
        i = i + 1
        if i <= n then
            if aargs then
                return hn[i](req, res, unpack(aargs, 1, nargs))
            end
            return hn[i](req, res)
        end
    end
    req.next = invoke
    return invoke(...)
end
return dispatch
