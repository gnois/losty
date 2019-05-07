--
-- Generated from exec.lt
--
local K = {}
K.quote = function(arg)
    if arg and string.match(arg, "[!\"#%$&'%(%)%*;<>%?%[\\%]`{|}~%s]") then
        arg = "'" .. string.gsub(arg, "[']", "'\\''") .. "'"
    end
    return arg
end
K.exec = function(cmd)
    assert(#cmd > 0)
    local _, __, code = os.execute(cmd)
    if code == 0 then
        return true
    end
    return false, cmd .. " failed, exit code: " .. tostring(code)
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
