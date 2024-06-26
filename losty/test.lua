--
-- Generated from test.lt
--
setmetatable(_G, {__newindex = function(t, n, v)
    rawset(t, n, v)
end})
local c = require("losty.exec")
local tbl = require("losty.tbl")
local s = function(...)
    local args = {...}
    local n = select("#", ...)
    local out = {}
    for i = 1, n do
        local x = args[i]
        if x == nil then
            out[i] = "<nil>"
        elseif x == ngx.null then
            out[i] = "<ngx.null>"
        elseif type(x) == "table" then
            out[i] = tbl.dump(x)
        else
            out[i] = tostring(x)
        end
    end
    return table.concat(out, " ")
end
local setup = function(db)
    if db then
        local map = {s = "select", i = "insert", u = "update", d = "delete"}
        local q = db
        for k, v in pairs(map) do
            q[k] = db[v]
            q[k .. "1"] = db[v .. "1"]
        end
        return q
    end
end
return function(db, func)
    local q = setup(db)
    local prn = function(...)
        print(s(...))
    end
    local tests = 0
    local fails = 0
    local errors = 0
    local chk = function(ok, ...)
        tests = tests + 1
        if ok then
            print(c.bright .. c.green .. "ok" .. c.reset)
        else
            fails = fails + 1
            print(c.bright .. c.red .. "fail: " .. s(...) .. c.reset)
        end
    end
    local groups = 0
    local passes = 0
    local test = function(desc, fn, rollback)
        groups = groups + 1
        tests = 0
        fails = 0
        errors = 0
        local title = c.bright .. c.cyan .. groups .. ". " .. c.yellow .. "[[ " .. (desc or "?? no name ??") .. " ]]"
        if rollback then
            title = title .. c.cyan .. " - WITH ROLLBACK"
        end
        print("                                         " .. title .. c.reset)
        if q and rollback then
            q.begin()
        end
        local _, err = xpcall(fn, function(err)
            return debug.traceback(err, 2)
        end)
        if err then
            if q and rollback then
                q.rollback()
            end
            print(c.bright .. c.red, "\nERROR: " .. err .. "\n" .. c.reset)
            errors = errors + 1
        else
            if q and rollback then
                q.rollback()
            end
        end
        if fails == 0 and errors == 0 then
            passes = passes + 1
        end
        local msg = tests .. " checks: " .. tests - fails .. " passed"
        if fails > 0 then
            msg = msg .. ", " .. fails .. " failed"
        end
        if errors > 0 then
            msg = msg .. "   [ Error: " .. errors .. " ]"
        end
        local color = fails + errors > 0 and c.cyan or c.green
        print(c.bright .. color .. "                                         ---------- " .. msg .. " ----------\n" .. c.reset)
    end
    if q then
        q.connect()
    end
    func(test, chk, prn, q)
    if q then
        q.disconnect()
    end
    local color = groups - passes > 0 and c.magenta or c.yellow
    print(c.bright .. color .. "                                         === " .. groups .. " cases:    " .. passes .. " ok,    " .. groups - passes .. " not ok ===\n" .. c.reset)
end
