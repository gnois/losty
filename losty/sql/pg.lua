--
-- Generated from pg.lau
--
local pgmoon = require("pgmoon")
local parrays = require("pgmoon.arrays")
local pjson = require("pgmoon.json")
local phstore = require("pgmoon.hstore")
local sql = require("losty.sql.base")
local str_gsub = string.gsub
local RAW = {}
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
    return nil, "cannot escape literal " .. tostring(val)
end, identifier = function(val)
    if "string" == type(val) then
        return "\"" .. str_gsub(val, "\"", "\"\"") .. "\""
    end
    return nil, "cannot escape identifier " .. tostring(val)
end, raw = function(val)
    if "string" ~= type(val) then
        return nil, "raw SQL must be a string"
    end
    local s = str_gsub(val, "/%*", "/ *")
    s = str_gsub(s, "%*/", "* /")
    s = str_gsub(s, "%-%-", "- -")
    return str_gsub(s, ";", "")
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
        if getmetatable(v) == RAW then
            return escape.raw(v[1])
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
            elseif mode == "i" then
                return escape.identifier(v)
            end
        end
        return nil, "invalid placeholder `:" .. mode .. "` for a " .. ty
    end
    local skip_quote = function(query, pos, q, bs)
        local i, len = pos + 1, #query
        while i <= len do
            local ch = string.sub(query, i, i)
            if bs and "\\" == ch then
                i = i + 2
            elseif q == ch then
                if q == string.sub(query, i + 1, i + 1) then
                    i = i + 2
                else
                    return i + 1
                end
            else
                i = i + 1
            end
        end
        return len + 1
    end
    local interpolate = function(query, ...)
        local args = {...}
        local i = 0
        local bad
        local buf, n = {}, 0
        local pos, len = 1, #query
        local push = function(s)
            n = n + 1
            buf[n] = s
        end
        while pos <= len do
            local ch = string.sub(query, pos, pos)
            local ch2 = string.sub(query, pos + 1, pos + 1)
            if "'" == ch or "\"" == ch then
                local bs = false
                if "'" == ch and pos > 1 then
                    local p = string.sub(query, pos - 1, pos - 1)
                    if "E" == p or "e" == p then
                        bs = true
                    end
                end
                local stop = skip_quote(query, pos, ch, bs)
                push(string.sub(query, pos, stop - 1))
                pos = stop
            elseif "-" == ch and "-" == ch2 then
                local e = string.find(query, "\n", pos, true) or len + 1
                push(string.sub(query, pos, e - 1))
                pos = e
            elseif "/" == ch and "*" == ch2 then
                local depth, e = 1, pos + 2
                while depth > 0 and e <= len do
                    if "/*" == string.sub(query, e, e + 1) then
                        depth = depth + 1
                        e = e + 2
                    elseif "*/" == string.sub(query, e, e + 1) then
                        depth = depth - 1
                        e = e + 2
                    else
                        e = e + 1
                    end
                end
                push(string.sub(query, pos, e - 1))
                pos = e
            elseif "$" == ch then
                local tag = string.match(query, "^%$[%a_][%w_]*%$", pos)
                if not tag and "$$" == string.sub(query, pos, pos + 1) then
                    tag = "$$"
                end
                if tag then
                    local e = string.find(query, tag, pos + #tag, true)
                    local stop = e and e + #tag or len + 1
                    push(string.sub(query, pos, stop - 1))
                    pos = stop
                else
                    push(ch)
                    pos = pos + 1
                end
            elseif "!" == ch then
                local mode = string.match(query, "^!([a-z%?])", pos)
                if mode then
                    i = i + 1
                    local s, err = encode(mode, args[i])
                    if s then
                        push(s)
                    elseif not bad then
                        bad = tostring(err) .. " at position " .. i
                    end
                    pos = pos + 2
                else
                    push(ch)
                    pos = pos + 1
                end
            else
                push(ch)
                pos = pos + 1
            end
        end
        return table.concat(buf), i, bad
    end
    local is_error = function(err)
        return err ~= nil and not tonumber(err)
    end
    local log_error = function(q, err)
        ngx.log(ngx.ERR, err)
        if dbg then
            ngx.log(ngx.ERR, q)
            ngx.log(ngx.ERR, debug.traceback("", 3))
        end
    end
    local exec = function(q)
        if dbg then
            print(q)
        end
        local result, err, partial, count = db:query(q)
        if is_error(err) then
            log_error(q, err)
        end
        return result, err, partial, count
    end
    local run = function(str, ...)
        local n = select("#", ...)
        local q, i, bad = interpolate(str, ...)
        if bad then
            ngx.log(ngx.ERR, bad)
            return nil, bad
        end
        if n ~= i then
            local msg = "trying to match " .. i .. " placeholders to " .. n .. " arguments for query `" .. str .. "`"
            ngx.log(ngx.ERR, msg)
            return nil, msg
        end
        return exec(q)
    end
    local keepalive = function(timeout)
        db:keepalive(timeout)
    end
    local K = sql(db, run)
    K.encode = encode
    K.raw = function(fragment)
        return setmetatable({fragment}, RAW)
    end
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
        local ok, err = db:connect()
        if not ok then
            log_error("CONNECT", err)
            error(tostring(err), 2)
        end
        return ok
    end
    K.close = function()
        db:disconnect()
    end
    K.listen = function()
        return db:wait_for_notification()
    end
    K.subscribe = function(channel)
        return exec("LISTEN " .. channel)
    end
    K.unsubscribe = function(channel)
        return exec("UNLISTEN " .. channel)
    end
    local tx = 0
    local sp_name = function()
        local id = ngx.worker.pid()
        return "SP" .. tx .. "_" .. id
    end
    K.disconnect = function(timeout)
        if tx > 0 then
            exec("ROLLBACK")
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
        return exec(cmd)
    end
    K.commit = function()
        assert(tx > 0, "no transaction or savepoint to commit")
        tx = tx - 1
        local cmd = tx < 1 and "COMMIT" or "RELEASE SAVEPOINT " .. sp_name()
        return exec(cmd)
    end
    K.rollback = function()
        assert(tx > 0, "no transaction or savepoint to rollback")
        tx = tx - 1
        local cmd = tx < 1 and "ROLLBACK" or "ROLLBACK TO SAVEPOINT " .. sp_name()
        return exec(cmd)
    end
    return K
end
