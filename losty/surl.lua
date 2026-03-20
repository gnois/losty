--
-- Generated from surl.lt
--
local sigurl = require("losty.sigurl")
return function(secret, length)
    local pen = sigurl(secret, {length = length})
    return {sign = function(value)
        return pen.sign_raw(value)
    end, verify = function(sig, value)
        return pen.verify_raw(sig, value)
    end}
end
