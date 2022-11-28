--
-- Generated from etag.lt
--
local sha1 = require("resty.sha1")
local str = require("resty.string")
local etag = function(payload, weak)
    local sha = sha1:new()
    if sha:update(payload) then
        local digest = sha:final()
        local tag = str.to_hex(digest)
        if weak then
            return "W/\"" .. tag .. "\""
        end
        return "\"" .. tag .. "\""
    end
end
return etag
