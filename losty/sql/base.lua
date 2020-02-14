--
-- Generated from base.lt
--
local map = {select = "SELECT ", insert = "INSERT INTO ", update = "UPDATE ", delete = "DELETE FROM "}
return function(db, run, keepalive)
    local began = false
    local K = {run = run}
    K.settimeouts = function(connect, send, read)
        db:settimeouts(connect, send, read)
    end
    K.disconnect = function(timeout)
        if began then
            db:query("ROLLBACK;")
            began = false
        end
        keepalive(timeout)
    end
    K.begin = function()
        assert(not began, "Already inside a transaction")
        if db:query("BEGIN;") then
            began = true
            return true
        end
        return false
    end
    K.commit = function()
        assert(began, "Cannot COMMIT without transaction")
        if db:query("COMMIT;") then
            began = false
            return true
        end
        return false
    end
    K.rollback = function()
        assert(began, "Cannot ROLLBACK without transaction")
        if db:query("ROLLBACK;") then
            began = false
            return true
        end
        return false
    end
    for k, v in pairs(map) do
        K[k] = function(sql, ...)
            return run(v .. sql, ...)
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
