--
-- Generated from migrate.lt
--
local to = require("losty.to")
local str = require("losty.str")
local c = require("losty.exec")
local model = require("losty.sql.model")
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
    local run = true
    local e
    local filenames = {}
    local k = 1
    while arg[k] do
        local a = arg[k]
        if string.sub(a, 1, 1) == "-" then
            if string.sub(a, 2, 2) == "e" then
                e = true
            else
                run = false
            end
        else
            table.insert(filenames, a)
        end
        k = k + 1
    end
    if #filenames < 1 then
        run = false
    end
    if run then
        for f = 1, #filenames do
            local scripts
            local n = 1
            local fname = filenames[f]
            if str.ends(fname, ".sql") then
                local file, err = io.open(fname, "r")
                if not file then
                    error(err)
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
                local file = string.gsub(to.trimmed(fname), ".lua$", "")
                scripts = require(file)
            end
            if #scripts > 0 then
                if not model.migrate(db, scripts) then
                    error(c.red .. " Error in " .. fname .. c.reset)
                end
            else
                local msg = fname .. " is empty."
                if e then
                    error(msg)
                end
                print(msg)
            end
        end
        print(c.green, "Migration successful.", c.reset)
        return true
    end
    usage()
end
