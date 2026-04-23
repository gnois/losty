--
-- Generated from file.lt
--
local Slash = package.config:sub(1, 1)
os.Win = Slash == "\\"
os.Nix = not os.Win
local localize = function(path)
    if os.Win then
        return string.gsub(path, "/", Slash)
    end
    return string.gsub(path, "\\", Slash)
end
local fail = function(op, path, err)
    if path then
        return false, op .. " " .. path .. " error: " .. err
    end
    return false, op .. "failed: " .. err
end
return {
    Slash = Slash
    , localize = localize
    , read = function(path)
        local lp = localize(path)
        local f, err = io.open(lp, "r")
        if f then
            local text
            text, err = f:read("*all")
            io.close(f)
            if text then
                return text
            end
            return fail("read", lp, err)
        end
        return fail("open", lp, err)
    end
    , write = function(path, text)
        local lp = localize(path)
        local f, err = io.open(lp, "w")
        if f then
            local ok
            ok, err = f:write(text)
            io.close(f)
            if ok then
                return ok
            end
            return fail("write", lp, err)
        end
        return fail("open", lp, err)
    end
    , exist = function(path)
        local f = io.open(path, "r")
        if f then
            io.close(f)
            return true
        end
        return false
    end
    , filename = function(path)
        return string.match(path, "[^/]*$")
    end
}
