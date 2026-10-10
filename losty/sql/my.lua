--
-- Generated from my.lau
--
local mysql = require("resty.mysql")
local sql = require("losty.sql.base")
return function(database, user, password, host, port, pool)
    local db = mysql.new()
    local encode = function(mode, v)
        if v == nil then
            return "NULL"
        end
        if "?" == mode then
            local ty = type(v)
            if "boolean" == ty then
                return v and "1" or "0"
            end
            if "string" == ty or "number" == ty then
                return ngx.quote_sql_str(v)
            end
        end
        return nil, "invalid placeholder `!" .. mode .. "` for a " .. type(v)
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
                local stop = skip_quote(query, pos, ch, true)
                push(string.sub(query, pos, stop - 1))
                pos = stop
            elseif "`" == ch then
                local stop = skip_quote(query, pos, ch, false)
                push(string.sub(query, pos, stop - 1))
                pos = stop
            elseif "-" == ch and "-" == ch2 or "#" == ch then
                local e = string.find(query, "\n", pos, true) or len + 1
                push(string.sub(query, pos, e - 1))
                pos = e
            elseif "/" == ch and "*" == ch2 then
                local e = string.find(query, "*/", pos + 2, true)
                e = e and e + 2 or len + 1
                push(string.sub(query, pos, e - 1))
                pos = e
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
        local res, err, errcode, sqlstate = db:query(q)
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
        local ok, err = db:connect({
            database = database
            , user = user
            , password = password
            , host = host
            , port = port
            , pool = pool
        })
        if not ok then
            ngx.log(ngx.ERR, tostring(err))
            error(tostring(err), 2)
        end
        return ok
    end
    K.close = function()
        db:close()
    end
    K.disconnect = function(timeout)
        return keepalive(timeout)
    end
    K.send = function(str)
        return db:send_query(str)
    end
    K.read = function()
        return db:read_result()
    end
    return K
end
