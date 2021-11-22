--
-- Generated from exec.lt
--
local K = {}
K.quote = function(argt)
    if argt and string.match(argt, "[!\"#%$&'%(%)%*;<>%?%[\\%]`{|}~%s]") then
        argt = "'" .. string.gsub(argt, "[']", "'\\''") .. "'"
    end
    return argt
end
K.exec = function(cmd)
    assert(#cmd > 0)
    local _, __, code = os.execute(cmd)
    if code == 0 then
        return true
    end
    return false, cmd .. " failed, exit code: " .. tostring(code)
end
K.script_path = function()
    local path = string.sub(debug.getinfo(2, "S").source, 2)
    return string.match(path, "(.*/)")
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
