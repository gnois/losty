-- Template file manifest for `losty new`.
-- Each entry is a path relative to its flavour directory.
-- Add or remove files here; the CLI copies them verbatim (with @@VAR@@ substitution).
return {
    -- Files shared by both Lua and lauzy scaffolds.
    common = {
        'gen.lua'               -- generate _tmpl/* files (dev|prod)
        , '_tmpl/nginx.conf_'   -- nginx.conf template; edit this, re-run gen.lua to apply
		  , '_tmpl/www.conf_'     -- nginx server block template; edit this, re-run gen.lua to apply
		  , '_tmpl/config.lua_'   -- user config template; edit this, re-run gen.lua to apply
        , 'run.sh'              -- *nix: generate + start/stop/reload nginx
        , 'run.bat'             -- Windows equivalent
		  , 'conf/mime.conf'
		  , 'conf/ssl.conf'
		  , 'conf/certs/.gitkeep' -- nginx certs placeholder; add your .cer/.key files here
        , 'logs/.gitkeep'       -- nginx log and pid files go here
        , 'static/style.css'    -- shared stylesheet, served under /public/<digits>/style.css
    }

    -- lauzy flavour is default
    , lau = {
        'app.lau'
        , 'views/home.lau'
		  , 'views/auth.lau'
		  , 'views/protected.lau'
    }

    -- Plain Lua flavour  (-lua switch)
    , lua = {
        'app.lua'
        , 'views/home.lua'
		  , 'views/auth.lua'
		  , 'views/protected.lua'
    }
}
