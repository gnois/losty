--
-- Generated from fs.lt
--
local ffi = require("ffi")
local ex = require("losty.exec")
local fs = {}
fs.glob = function(pattern)
    local re = -1
    local glob_t = ffi.new("glob_t[1]")
    re = ffi.C.glob(pattern, 0, nil, glob_t)
    if re ~= 0 then
        ffi.C.globfree(glob_t)
        return nil
    end
    local files = {}
    local i = 0
    while i < glob_t[0].gl_pathc do
        table.insert(files, ffi.string(glob_t[0].gl_pathv[i]))
        i = i + 1
    end
    ffi.C.globfree(glob_t)
    return files
end
fs.exists = function(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end
fs.read_all = function(file)
    local f = io.open(file, "rb")
    assert(f, "Could not open file ", file, " for reading.")
    local content = f:read("*all")
    f:close()
    return content
end
fs.create = function(path, owners)
    local ok, err = ex.exec("mkdir -p " .. path)
    if ok then
        ok, err = ex.exec("chown " .. owners .. " " .. path)
    end
    if not ok then
        error(err)
    end
end
return fs
