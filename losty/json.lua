--
-- Generated from json.lau
--
local is_json = function(ctype)
    if not ctype then
        return false
    end
    local ct = string.match(string.lower(ctype), "^[^;]*") or ctype
    ct = string.match(ct, "^%s*(.-)%s*$")
    if ct == "application/json" then
        return true
    end
    return string.match(ct, "^application/[%w%._%-]+%+json$") ~= nil
end
local pretty = function(txt, space)
    local ind = string.rep(" ", space or 2)
    local out = {}
    local depth = 0
    local in_str = false
    local esc = false
    local i, n = 1, #txt
    while i <= n do
        local c = string.sub(txt, i, i)
        if in_str then
            out[#out + 1] = c
            if esc then
                esc = false
            elseif c == "\\" then
                esc = true
            elseif c == "\"" then
                in_str = false
            end
        elseif c == "\"" then
            in_str = true
            out[#out + 1] = c
        elseif c == "{" or c == "[" then
            if string.sub(txt, i + 1, i + 1) == (c == "{" and "}" or "]") then
                out[#out + 1] = c .. string.sub(txt, i + 1, i + 1)
                i = i + 1
            else
                depth = depth + 1
                out[#out + 1] = c
                out[#out + 1] = "\n"
                out[#out + 1] = string.rep(ind, depth)
            end
        elseif c == "}" or c == "]" then
            depth = depth - 1
            out[#out + 1] = "\n"
            out[#out + 1] = string.rep(ind, depth)
            out[#out + 1] = c
        elseif c == "," then
            out[#out + 1] = ",\n"
            out[#out + 1] = string.rep(ind, depth)
        elseif c == ":" then
            out[#out + 1] = ": "
        elseif c == " " or c == "\t" or c == "\n" or c == "\r" then
            
        else
            out[#out + 1] = c
        end
        i = i + 1
    end
    return table.concat(out, "")
end
return {is_json = is_json, pretty = pretty}
