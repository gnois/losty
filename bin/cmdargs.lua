--
-- Generated from cmdargs.lt
--
local insert = function(tbl, key, val)
    if tbl[key] then
        if "table" == type(tbl[key]) then
            table.insert(tbl[key], val)
        else
            tbl[key] = {tbl[key], val}
        end
    else
        tbl[key] = val
    end
end
local parse = function(args)
    local out = {}
    local key
    local a = 1
    while args[a] do
        local x = args[a]
        if string.sub(x, 1, 1) == "-" then
            if key then
                insert(out, key, true)
            end
            key = string.sub(x, 2)
        elseif key then
            insert(out, key, x)
            key = nil
        else
            table.insert(out, x)
        end
        a = a + 1
    end
    if key then
        insert(out, key, true)
    end
    return out
end
local test = function()
    local line = {
        "-w"
        , "-x"
        , "xfile1"
        , "-x"
        , "xfile2"
        , "--y"
        , "yfile"
        , "other"
        , "file"
        , "--long"
        , "switch"
        , "--java=style"
    }
    local o = parse(line)
    local as = assert
    as(o[1] == "other")
    as(o[2] == "file")
    as(o.w == true)
    as(o.x[1] == "xfile1")
    as(o.x[2] == "xfile2")
    as(o["-y"] == "yfile")
    as(o["-long"] == "switch")
    as(o["-java=style"] == true)
end
test()
return parse
