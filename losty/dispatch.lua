--
-- Generated from dispatch.lt
--
local dispatch = function(hn, req, res, ...)
    local i, n = 0, #hn
    local nargs, aargs = 0
    local unpack = table.unpack or unpack
    local invoke = function(...)
        i = i + 1
        if i <= n then
            local np = select("#", ...)
            if np > 0 then
                aargs = aargs or {}
                for j = 1, np do
                    aargs[nargs + j] = select(j, ...)
                end
                nargs = nargs + np
            end
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
