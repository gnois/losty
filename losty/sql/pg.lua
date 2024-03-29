--
-- Generated from pg.lt
--
local pgmoon = require("pgmoon")
local parrays = require("pgmoon.arrays")
local pjson = require("pgmoon.json")
local phstore = require("pgmoon.hstore")
local sql = require("losty.sql.base")
local str_gsub = string.gsub
local escape = {literal = function(val)
    if val == nil or val == ngx.null then
        return "NULL"
    end
    local ty = type(val)
    if "number" == ty or "boolean" == ty then
        return tostring(val)
    elseif "string" == ty then
        return "'" .. str_gsub(val, "'", "''") .. "'"
    end
    error("cannot escape literal " .. tostring(val))
end, identifier = function(val)
    if "string" == type(val) then
        return "\"" .. str_gsub(val, "\"", "\"\"") .. "\""
    end
    error("cannot escape identifier " .. tostring(val))
end, any = function(val, mode)
    local s = str_gsub(val, "/%*", "/ *")
    s = str_gsub(s, "%*/", "* /")
    s = str_gsub(s, "%-%-", "- -")
    s = str_gsub(s, ";", "")
    return str_gsub(s, mode, "")
end}
return function(database, user, password, host, port, pool, dbg)
    local db = pgmoon.new({
        database = database
        , user = user
        , password = password
        , host = host
        , port = port
        , pool = pool
    })
    local encode_row
    encode_row = function(t)
        local out = {}
        for i, v in ipairs(t) do
            local o
            if v == ngx.null then
                o = ""
            else
                local ty = type(v)
                if "table" == ty then
                    o = encode_row(v)
                elseif "string" == ty then
                    if 0 == string.len(v) then
                        o = "\"\""
                    else
                        o = str_gsub(v, ",", "\\,")
                    end
                else
                    o = tostring(v) or ""
                end
            end
            out[i] = o
        end
        return "(" .. table.concat(out, ",") .. ")"
    end
    local encode = function(mode, v)
        if v == nil or v == ngx.null then
            return "NULL"
        end
        local ty = type(v)
        if "table" == ty then
            if mode == "r" then
                return encode_row(v)
            elseif mode == "a" then
                return parrays.encode_array(v)
            elseif mode == "h" then
                return phstore.encode_hstore(v)
            elseif mode == "?" then
                return pjson.encode_json(v)
            end
        elseif "number" == ty or "string" == ty or "boolean" == ty then
            if mode == "b" then
                return db:encode_bytea(v)
            elseif mode == "?" then
                return escape.literal(v)
            elseif mode == "!" then
                return escape.identifier(v)
            elseif mode == ")" or mode == "]" then
                return escape.any(v, "%" .. mode)
            end
        end
        return nil, "invalid placeholder `:" .. mode .. "` for a " .. ty
    end
    local interpolate = function(query, ...)
        local args = {...}
        local i = 0
        return str_gsub(query, "(:?):([a-z!%?%)%]])", function(c, mode)
            if c == ":" then
                return "::" .. mode
            end
            i = i + 1
            local s, err = encode(mode, args[i])
            if s then
                return s
            end
            ngx.log(ngx.ERR, err .. " at position ", i)
        end), i
    end
    local run = function(str, ...)
        local n = select("#", ...)
        local q, i = interpolate(str, ...)
        if n ~= i then
            ngx.log(ngx.ERR, "trying to match ", i, " placeholders to ", n, " arguments for query `", str, "`")
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
    local K = sql(db, run)
    K.encode = encode
    K.hstore = function()
        db:setup_hstore()
    end
    K.variadic = function(mode, ...)
        local n = select("#", ...)
        if n > 0 then
            local places = string.rep(", " .. mode, n - 1)
            return (interpolate(mode .. places, ...))
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
    local tx = 0
    local sp_name = function()
        local id = ngx.worker.pid()
        return "SP" .. tx .. "_" .. id
    end
    K.disconnect = function(timeout)
        if tx > 0 then
            db:query("ROLLBACK")
            tx = 0
        end
        keepalive(timeout)
    end
    K.begin = function(serializable)
        local cmd
        if tx < 1 then
            if serializable == true then
                cmd = "BEGIN ISOLATION LEVEL SERIALIZABLE"
            elseif serializable == false then
                cmd = "BEGIN ISOLATION LEVEL REPEATABLE READ"
            else
                cmd = "BEGIN"
            end
        else
            cmd = "SAVEPOINT " .. sp_name()
        end
        tx = tx + 1
        if dbg then
            print(cmd)
        end
        return db:query(cmd)
    end
    K.commit = function()
        assert(tx > 0, "no transaction or savepoint to commit")
        tx = tx - 1
        local cmd = tx < 1 and "COMMIT" or "RELEASE SAVEPOINT " .. sp_name()
        if dbg then
            print(cmd)
        end
        return db:query(cmd)
    end
    K.rollback = function()
        assert(tx > 0, "no transaction or savepoint to rollback")
        tx = tx - 1
        local cmd = tx < 1 and "ROLLBACK" or "ROLLBACK TO SAVEPOINT " .. sp_name()
        if dbg then
            print(cmd)
        end
        return db:query(cmd)
    end
    return K
end
