--
-- Generated from base.lt
--
local json = require("cjson")
local map = {insert = "INSERT INTO ", update = "UPDATE ", delete = "DELETE FROM "}
return function(db, run)
    local K = {run = run}
    K.settimeouts = function(connect, send, read)
        db:settimeouts(connect, send, read)
    end
    K.select = function(sql, ...)
        local res, err, partial, count = run("SELECT " .. sql, ...)
        if res then
            setmetatable(res, json.empty_array_mt)
        end
        return res, err, partial, count
    end
    for k, v in pairs(map) do
        K[k] = function(sql, ...)
            local res, err, partial, count = run(v .. sql, ...)
            if res and res == true then
                res = {}
            end
            return res, err, partial, count
        end
    end
    K.select1 = function(sql, ...)
        local res, err, partial, count = run("SELECT " .. sql, ...)
        return res and res[1], err, partial, count
    end
    for k, v in pairs(map) do
        K[k .. "1"] = function(sql, ...)
            local res, err, partial, count = run(v .. sql, ...)
            if res then
                if res == true then
                    res = {}
                else
                    res = res[1]
                end
            end
            return res, err, partial, count
        end
    end
    return K
end
