--
-- Generated from migrate.lt
--
package.path = package.path .. ";../?.lua"
local to = require("losty.to")
local str = require("losty.str")
local tbl = require("losty.tbl")
local c = require("losty.exec")
local parse = require("cmdargs")
local migrate = function(db, migrations)
    assert("table" == type(migrations), "migration schemas must be an array of {sql, ...} where sql are strings")
    local ok = true
    local err
    db.connect()
    for _, v in ipairs(migrations) do
        local sql = to.trim(v)
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
local usage = function()
    io.stderr:write([==[
Usage:
	.../resty/bin/resty -I ../ migrate.lua [-e] m1 [m2.sql] [m3.lua]

	Migrate files m1.lua [, m2.sql, m3.lua] in order.
	Filename can specify SQL file or Lua file. Filename without extension is treated as a Lua file.

	SQL scripts in each file are represented as an array of strings, which is iterated and sent to database.
	Hence a Lua file should return an array of sql scripts.
	A SQL file can have scripts delimited with `---` as array separator, or else is sent to database as a whole.

	Optional switches:
		-e   Error out if any file is empty, default is to continue to next file.
]==])
end
return function(db)
    local opts = parse(arg)
    tbl.show(opts)
    if #opts > 0 then
        for f = 1, #opts do
            local scripts
            local n = 1
            local fname = opts[f]
            if str.ends(fname, ".sql") then
                local file, err = io.open(fname, "r")
                if not file then
                    error(c.red .. err .. c.reset)
                end
                local nested = 0
                local lines, l, i = {}, 1, 1
                scripts = {}
                for line in file:lines() do
                    i = i + 1
                    for comment in string.gmatch(line, "/%*") do
                        nested = nested + 1
                    end
                    for comment in string.gmatch(line, "%*/") do
                        nested = nested - 1
                    end
                    if nested == 0 and str.starts(line, "---") and #lines > 0 then
                        scripts[n] = table.concat(lines, "\n")
                        n = n + 1
                        lines = {}
                        l = 1
                    else
                        lines[l] = line
                        l = l + 1
                    end
                end
                if #lines > 0 then
                    scripts[n] = table.concat(lines, "\n")
                end
                file:close()
            else
                local file = string.gsub(to.trim(fname), ".lua$", "")
                scripts = require(file)
            end
            if #scripts > 0 then
                if not migrate(db, scripts) then
                    error(c.red .. " Error in " .. fname .. c.reset)
                end
            else
                local msg = fname .. " is empty."
                if opts.e then
                    error(c.red .. msg .. c.reset)
                end
                print(c.yellow .. msg .. c.reset)
            end
        end
        print(c.green, "Migration successful.", c.reset)
        return true
    end
    usage()
end
