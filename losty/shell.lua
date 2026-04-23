--
-- Generated from shell.lt
--
local file = require("losty.file")
local K = {}
K.script_path = function()
    local path = string.sub(debug.getinfo(2, "S").source, 2)
    return string.match(path, "(.*/)")
end
K.quote = function(argt)
    if argt and string.match(argt, "[!\"#%$&'%(%)%*;<>%?%[\\%]`{|}~%s]") then
        argt = "'" .. string.gsub(argt, "[']", "'\\''") .. "'"
    end
    return argt
end
local exec = function(cmd)
    local ok, _, code = os.execute(cmd)
    if ok then
        return ok
    end
    return false, "exec " .. cmd .. " failed, exit code: " .. tostring(code)
end
K.exec = exec
local run = function(cmd)
    local t, err = io.popen(cmd)
    if t then
        local data
        data, err = t:read("*all")
        io.close(t)
        if data then
            return data
        end
        return nil, "get output of " .. cmd .. " failed, error: " .. err
    end
    return nil, "exec " .. cmd .. " failed, error: " .. err
end
K.run = run
K.run_stderr = function(cmd)
    return run(cmd .. " 2>&1")
end
K.mkdir = function(path)
    local lp = file.localize(path)
    if os.Win then
        return exec("md " .. lp)
    end
    return exec("mkdir -p " .. lp)
end
K.exist_dir = function(path)
    local p = string.gsub(file.localize(path), file.Slash .. "*$", "")
    local ok, err = exec("pushd " .. p .. " 2> nul")
    if ok then
        exec("popd")
    end
    return ok, err
end
K.list_files = function(path)
    local lp = file.localize(path)
    if os.Win then
        return run("dir /b/a:-D \"" .. lp .. "\"")
    end
    return run("ls -p \"" .. lp .. "\" | grep -v /")
end
local colors = {
    reset = 0
    , clear = 0
    , bright = 1
    , dim = 2
    , underscore = 4
    , blink = 5
    , reverse = 7
    , hidden = 8
    , black = 30
    , red = 31
    , green = 32
    , yellow = 33
    , blue = 34
    , magenta = 35
    , cyan = 36
    , white = 37
    , onblack = 40
    , onred = 41
    , ongreen = 42
    , onyellow = 43
    , onblue = 44
    , onmagenta = 45
    , oncyan = 46
    , onwhite = 47
}
for c, v in pairs(colors) do
    K[c] = "\27[" .. tostring(v) .. "m"
end
return K
