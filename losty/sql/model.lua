--
-- Generated from model.lt
--
local to = require("losty.to")
local c = require("losty.exec")
local tbl = require("losty.tbl")
local K = {}
K.migrate = function(db, migrations)
    assert("table" == type(migrations), "migration schemas must be an array of {sql, ...} where sql are strings")
    local ok = true
    local err
    db.connect()
    for _, v in ipairs(migrations) do
        local sql = to.trimmed(v)
        if #sql > 0 then
            ok, err = db.run(sql)
            if tonumber(err) then
                print(c.onblue, c.yellow, c.bright, "        ==> ", err .. " query ok", c.reset)
            else
                print(c.onred, c.white, c.bright, "        >>>> ", tbl.dump(err), c.reset)
                break
            end
        end
    end
    db.disconnect()
    if not ok and err ~= 0 then
        return false
    end
    return true
end
K.exec = function(db, fn)
    assert("function" == type(fn), "seed must take a function which accepts a database handle")
    db.connect()
    local ok, trace = xpcall(fn, function(err)
        return debug.traceback(err, 2)
    end, db)
    if not ok then
        print(c.syan, trace, c.reset)
        db.disconnect()
        return false
    end
    db.disconnect()
    return true
end
return K
