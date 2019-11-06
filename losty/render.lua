--
-- Generated from render.lt
--
local str = require("losty.str")
return function(template, data)
    return (string.gsub(template, "{([_%w%.]*)}", function(s)
        local keys = str.split(s, "%.")
        local v = data[keys[1]]
        for i = 2, #keys do
            v = v[keys[i]]
        end
        return v or "{" .. s .. "}"
    end))
end
