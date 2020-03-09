--
-- Generated from pg.lt
--
local pgmoon = require("pgmoon")
local parrays = require("pgmoon.arrays")
local pjson = require("pgmoon.json")
local phstore = require("pgmoon.hstore")
local sql = require("losty.sql.base")
return function(database, user, password, host, port, pool, dbg)
    local db = pgmoon.new({
        database = database
        , user = user
        , password = password
        , host = host
        , port = port
        , pool = pool
    })
    local interpolate = function(query, ...)
        local args = {...}
        local i = 0
        return string.gsub(query, "(:?):([a-z%?])", function(c, x)
            if c == ":" then
                return "::" .. x
            end
            i = i + 1
            local a = args[i]
            if a ~= nil and a ~= ngx.null then
                local ty = type(a)
                if "table" == ty then
                    if x == "a" then
                        return parrays.encode_array(a)
                    elseif x == "h" then
                        return phstore.encode_hstore(a)
                    elseif x ~= "?" then
                        ngx.log(ngx.ERR, "Invalid query placeholder `:", x, "` for table value at position ", i)
                    end
                    return pjson.encode_json(a)
                elseif "number" == ty or "string" == ty or "boolean" == ty then
                    if x == "b" then
                        return db:encode_bytea(a)
                    elseif x ~= "?" then
                        ngx.log(ngx.ERR, "Invalid query placeholder `:", x, "` for scalar value at position ", i)
                    end
                    return db:escape_literal(a)
                end
            end
            return "NULL"
        end), i
    end
    local run = function(str, ...)
        local n = select("#", ...)
        local q, i = interpolate(str, ...)
        if n ~= i then
            ngx.log(ngx.ERR, "Trying to match ", i, " placeholders to ", n, " arguments for query `", str, "`")
        end
        if dbg then
            print(q)
        end
        local result, err, partial, count = db:query(q)
        if nil == result and not tonumber(err) then
            ngx.log(ngx.ERR, q)
            ngx.log(ngx.ERR, err)
        end
        return result, err, partial, count
    end
    local keepalive = function(timeout)
        db:keepalive(timeout)
    end
    local K = sql(db, run, keepalive)
    K.hstore = function()
        db:setup_hstore()
    end
    K.variadic = function(modifier, ...)
        local n = select("#", ...)
        if n > 0 then
            local places = string.rep(", " .. modifier, n - 1)
            return interpolate(modifier .. places, ...)
        end
    end
    K.connect = function()
        assert(db:connect())
    end
    K.close = function()
        db:disconnect()
    end
    K.listen = function()
        return db:wait_for_notification()
    end
    K.subscribe = function(channel)
        return db:query("LISTEN " .. channel)
    end
    K.unsubscribe = function(channel)
        return db:query("UNLISTEN " .. channel)
    end
    return K
end
