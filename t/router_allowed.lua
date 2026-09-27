-- Router `allowed()` regression test (P1-1).
--
-- losty.router has no ngx dependency, so this runs under plain luajit with no
-- nginx server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\router_allowed.lua
--
-- It pins the method-selection rules that protocol_method.t exercises over HTTP
-- (405 vs 404, HEAD implied by GET, canonical Allow ordering).

package.path = [[C:\git\losty\?.lua;]] .. package.path

local router = require('losty.router')

local rt = router()
rt.set('GET', '/only-get', 1)
rt.set('GET', '/multi', 1)
rt.set('POST', '/multi', 1)
rt.set('GET', '/opt', 1)
rt.set('OPTIONS', '/opt', 1)

local fails = 0

local function eq(method, path, want)
	local allowed = rt.allowed(method, path)
	local got = allowed and table.concat(allowed, ', ') or nil
	if (got or '') ~= (want or '') then
		fails = fails + 1
		print('FAIL: ' .. method .. ' ' .. path .. '\n  got  ' .. tostring(got) .. '\n  want ' .. tostring(want))
	end
end

-- GET-only path: only GET (and implied HEAD)
eq('PUT', '/only-get', 'GET, HEAD')
eq('POST', '/only-get', 'GET, HEAD')
eq('DELETE', '/only-get', 'GET, HEAD')

-- multi-method path: union of registered methods, HEAD implied by GET
eq('PATCH', '/multi', 'GET, HEAD, POST')
eq('OPTIONS', '/multi', 'GET, HEAD, POST')
eq('DELETE', '/multi', 'GET, HEAD, POST')

-- a registered OPTIONS route contributes OPTIONS to the Allow set
eq('DELETE', '/opt', 'GET, HEAD, OPTIONS')

-- path registered under no method at all -> nil (a true 404)
eq('GET', '/nope', nil)
eq('PUT', '/nope', nil)

-- query string is stripped before matching
eq('PUT', '/only-get?x=1', 'GET, HEAD')

-- HEAD request on a GET-only path reports GET, HEAD (HEAD is itself not matched
-- by web.run, which rewrites HEAD -> GET, but allowed() must stay total)
eq('HEAD', '/only-get', 'GET, HEAD')

if fails == 0 then
	print('OK')
	os.exit(0)
end
print(fails .. ' failure(s)')
os.exit(1)
