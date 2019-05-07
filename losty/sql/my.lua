--
-- Generated from my.lt
--
local mysql = require("resty.mysql")
local sql = require("losty.sql.base")
return function(database, user, password, host, port, pool)
    local db = mysql.new()
    local interpolate = function(query, ...)
        local args = {...}
        local i = 0
        return (string.gsub(query, "%?", function()
            i = i + 1
            if not args[i] then
                return "NULL"
            end
            return ngx.quote_sql_str(args[i])
        end))
    end
    local run = function(str, ...)
        if select("#", ...) > 0 then
            str = interpolate(str, ...)
        end
        local res, err, errcode, sqlstate = db:query(str)
        if res == nil and err then
            ngx.log(ngx.ERR, err)
        end
        return res, err, errcode, sqlstate
    end
    local keepalive = function(timeout)
        db:set_keepalive(timeout)
    end
    local K = sql(db, run, keepalive)
    K.connect = function()
        assert(db:connect({
            database = database
            , user = user
            , password = password
            , host = host
            , port = port
            , pool = pool
        }))
    end
    K.close = function()
        db:close()
    end
    K.send = function(str)
        return db:send_query(str)
    end
    K.read = function()
        return db:read_result()
    end
    return K
end
