--
-- Generated from file.lt
--
local Slash = package.config:sub(1, 1)
return {Slash = Slash, read = function(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*all")
    f:close()
    return text
end, write = function(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end, localize = function(path)
    if Slash == "\\" then
        return string.gsub(path, "/", Slash)
    end
    return string.gsub(path, "\\", Slash)
end, filename = function(path)
    return string.match(path, "[^/]*$")
end}
