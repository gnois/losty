--
-- Generated from base.lt
--
local json = require("cjson")
local map = {select = "SELECT ", insert = "INSERT INTO ", update = "UPDATE ", delete = "DELETE FROM "}
return function(db, run)
    local K = {run = run}
    K.settimeouts = function(connect, send, read)
        db:settimeouts(connect, send, read)
    end
    for k, v in pairs(map) do
        K[k] = function(sql, ...)
            local res, err, partial, count = run(v .. sql, ...)
            if res then
                setmetatable(res, json.empty_array_mt)
            end
            return res, err, partial, count
        end
    end
    local one = function(query, ...)
        local res, err, partial, count = run(query, ...)
        local result = res and res[1]
        return result, err, partial, count
    end
    for k, v in pairs(map) do
        K[k .. "1"] = function(sql, ...)
            return one(v .. sql, ...)
        end
    end
    return K
end
