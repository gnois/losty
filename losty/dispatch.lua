--
-- Generated from dispatch.lau
--
local dispatch = function(hn, q, r, ...)
    local i, n = 0, #hn
    local nargs, aargs = 0
    local nxt
    nxt = function(...)
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
                return hn[i](q, r, nxt, unpack(aargs, 1, nargs))
            end
            return hn[i](q, r, nxt)
        end
    end
    return nxt(...)
end
return dispatch
