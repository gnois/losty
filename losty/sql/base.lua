--
-- Generated from base.lt
--
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
    K.call = function(proc, ...)
        local e, err = run("SELECT * FROM " .. proc, ...)
        if e then
            return e[1], err
        end
    end
    K.exec = function(proc, ...)
        local e, err = run("SELECT * FROM " .. proc, ...)
        return e, err
    end
    K.one = function(sql, ...)
        local e, err = run("SELECT " .. sql, ...)
        if e then
            return e[1], err
        end
    end
    K.select = function(sql, ...)
        local e, err = run("SELECT " .. sql, ...)
        return e, err
    end
    K.insert = function(sql, ...)
        local e, err = run("INSERT INTO " .. sql, ...)
        if e then
            return e[1], err
        end
        return nil, err
    end
    K.update = function(sql, ...)
        local e, err = run("UPDATE " .. sql, ...)
        if e then
            return e[1], err
        end
        return nil, err
    end
    K.delete = function(sql, ...)
        local e, err = run("DELETE FROM " .. sql, ...)
        if e then
            return e[1], err
        end
        return nil, err
    end
    K.placeholders = function(...)
        local places = {}
        for i, _ in ipairs({...}) do
            places[i] = ", ?"
        end
        return table.concat(places)
    end
    return K
end
