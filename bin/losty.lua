--
-- Generated from losty.lt
--
local script_dir = function()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    if not (src:match("^[/\\]") or src:match("^%a:[/\\]")) then
        local sep = package.config:sub(1, 1)
        local ph = io.popen(sep == "\\" and "cd" or "pwd")
        local cwd = ph:read("*l") or "."
        ph:close()
        src = cwd .. sep .. src
    end
    src = src:gsub("^%a:", ""):gsub("\\", "/")
    return src:match("(.*)/[^/]+$") or "/"
end
local _bin = script_dir()
package.path = _bin .. "/?.lua;" .. package.path
local parse = require("cmdargs")
local IS_WIN = package.config:sub(1, 1) == "\\"
local SEP = IS_WIN and "\\" or "/"
local join = function(...)
    local parts = {...}
    for i = 1, #parts do
        parts[i] = parts[i]:gsub("[/\\]", SEP)
    end
    return table.concat(parts, SEP)
end
local dirname = function(path)
    return path:match("(.*)[/\\][^/\\]+") or ""
end
local basename = function(path)
    path = path:match("^(.*[^/\\])") or path
    return path:match("[/\\]([^/\\]+)$") or path
end
local SCRIPT_DIR = _bin
local _parent = dirname(SCRIPT_DIR)
local LOSTY_ROOT = _parent ~= "" and _parent or "."
local TMPL_ROOT = join(SCRIPT_DIR, "new")
local mkdir_p = function(path)
    path = path:gsub("[/\\]", SEP)
    if IS_WIN then
        os.execute("if not exist \"" .. path .. "\" mkdir \"" .. path .. "\" > nul 2>&1")
    else
        os.execute("mkdir -p \"" .. path .. "\" 2>/dev/null")
    end
end
local read_file = function(path)
    local f, err = io.open(path, "r")
    if not f then
        return nil, err
    end
    local data = f:read("*a")
    f:close()
    return data
end
local write_file = function(path, data)
    local dir = dirname(path)
    if dir ~= "" then
        mkdir_p(dir)
    end
    local f, err = io.open(path, "w")
    if not f then
        return false, err
    end
    f:write(data)
    f:close()
    return true
end
local render = function(text, vars)
    return text:gsub("@@([%u%d_]+)@@", function(k)
        return tostring(vars[k] or "@@" .. k .. "@@")
    end)
end
local copy_tmpl_files = function(file_list, src_dir, dest_dir, vars)
    for _, rel in ipairs(file_list) do
        local src = join(src_dir, rel)
        local dest = join(dest_dir, rel)
        local data, err = read_file(src)
        if data == nil then
            io.stderr:write("  WARN: missing template " .. src .. ": " .. tostring(err) .. "\n")
        else
            data = render(data, vars)
            local ok, werr = write_file(dest, data)
            if ok then
                print("  create  " .. rel)
            else
                io.stderr:write("  ERROR writing " .. dest .. ": " .. tostring(werr) .. "\n")
            end
        end
    end
end
local load_manifest = function()
    local path = join(TMPL_ROOT, "manifest.lua")
    local chunk, err = loadfile(path)
    if not chunk then
        error("Cannot load template manifest at " .. path .. ": " .. tostring(err))
    end
    return chunk()
end
local HELP = [==[
losty - Losty web framework CLI

Usage:
  luajit bin/losty.lt <path> [-lua] [-domain example.com]

Options:
  -lua              Scaffold in plain Lua (default: Luaty .lt files)
  -domain <tld>     Domain for nginx server_name (e.g. example.com);
                    prompted interactively if omitted

Examples:
  luajit bin/losty.lt apps/myapp -domain example.com
  luajit bin/losty.lt /srv/www/myapp -lua

Once scaffolded, cd into the app directory and use the generated scripts:
  ./run.sh dev      # *nix: generate conf + start nginx in dev mode
  ./run.sh prod     # *nix: generate conf + start nginx in prod mode
  ./run.sh -s reload
  run dev           # Windows
]==]
local cmd_new = function(opts)
    local path = opts[1]
    if not path then
        io.write(HELP)
        os.exit(0)
    end
    if path:match("[/\\]$") then
        io.stderr:write("error: path must not end with a separator\n")
        os.exit(1)
    end
    local name = basename(path)
    if not name:match("^[%a][%w_%-]*$") then
        io.stderr:write("error: app name (last path segment) must start with a letter and contain only letters, digits, - or _\n")
        os.exit(1)
    end
    local use_lua = opts.lua == true
    local flavor = use_lua and "lua" or "lt"
    local is_abs = path:match("^[/\\]") or path:match("^%a:[/\\]")
    local dest = is_abs and path or join(".", path)
    local domain = opts.domain
    if not domain then
        io.write("Domain name (e.g. example.com): ")
        io.flush()
        domain = io.read("*l") or "example.com"
    end
    local vars = {APP_NAME = name, DOMAIN = domain, LOSTY_PATH = LOSTY_ROOT:gsub("\\", "/"), YEAR = tostring(os.date("%Y")), FLAVOR = flavor}
    print("Scaffolding \"" .. name .. "\" (" .. (use_lua and "Lua" or "Luaty") .. ") ...")
    local manifest = load_manifest()
    copy_tmpl_files(manifest.common, join(TMPL_ROOT, "server"), dest, vars)
    copy_tmpl_files(manifest[flavor], join(TMPL_ROOT, flavor), dest, vars)
    if not IS_WIN then
        os.execute("chmod +x \"" .. join(dest, "run.sh") .. "\" 2>/dev/null")
    end
    local compile_note = use_lua and "" or [=[
  Luaty workflow:
	 - After editing .lt files, compile before restart:
		luajit /path/to/luaty/lt.lua -f app.lt app.lua
		luajit /path/to/luaty/lt.lua -f views/home.lt views/home.lua
		luajit /path/to/luaty/lt.lua -f views/auth.lt views/auth.lua
		luajit /path/to/luaty/lt.lua -f views/protected.lt views/protected.lua
]=]
    print(string.format([=[
Done!

Next steps:
  1) Enter app directory
	  cd %s

  2) Start server
	  ./run.sh dev        # *nix
	  run dev             # Windows

  3) Open in browser
	  http://localhost:8080

  4) Continue development
	  - Edit routes and auth flow in app.%s
	  - Edit page templates in views/*.%s
%s
  5) Production run
	  ./run.sh prod       # *nix
	  run prod            # Windows
]=], path, flavor, flavor, compile_note))
end
local opts = parse(arg or {})
if not opts[1] or opts.h or opts.help then
    io.write(HELP)
    os.exit(0)
end
cmd_new(opts)
