-- Router tests for the brace grammar and prefix middleware.
--
-- losty.router has no ngx dependency, so this runs under plain luajit with no
-- nginx server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\router-test.lua
--
-- Covers registration validation, match precedence, trailing-slash and
-- strict-mode rules, named captures (params), wildcard, prefix middleware
-- composition, and the interaction with allowed().

package.path = './?.lua;./t/?.lua;' .. package.path

local router = require('losty.router')

local fails = 0

local function fail(msg)
	fails = fails + 1
	print('FAIL: ' .. msg)
end

local function eq(got, want, msg)
	if got ~= want then
		fail(msg .. '\n  got  ' .. tostring(got) .. '\n  want ' .. tostring(want))
	end
end

local function arr_eq(got, want, msg)
	if type(got) ~= 'table' then
		fail(msg .. ': got ' .. type(got) .. ', want table')
		return
	end
	local n = math.max(#got, #want)
	for i = 1, n do
		if got[i] ~= want[i] then
			fail(msg .. '[' .. i .. ']: got ' .. tostring(got[i]) .. ', want ' .. tostring(want[i]))
			return
		end
	end
end

local function raises(fn, msg)
	local ok = pcall(fn)
	if ok then
		fail('expected an error: ' .. msg)
	end
end

local G = 'GET'

-- ---- registration validation ----------------------------------------------

local rv = router()
local function bad(path)
	raises(function() rv.set(G, path, 1) end, 'set ' .. path)
end

bad('//')                       -- empty segment
bad('/favicon ico')             -- space
bad('/:page')                   -- old ':pattern' syntax
bad('/{:page%}')                -- malformed lua pattern
bad('/{:page:}')                -- not a pattern
bad('/::%wage')
bad('/{:page+}')
bad('/{:[page}')
bad('/{+}/x')                   -- {+} must be last
bad('/{*}/x')                   -- {*} must be last
bad('/a/*/b')                   -- bare '*'
bad('/{id')                     -- unbalanced brace
bad('/x{id}')                   -- a meta token must be a whole segment
bad('/{}')                      -- empty token
bad('/{1id}')                   -- not a valid name

for _, p in ipairs({'/', '/a', '/a/{id}', '/a/{id:%d+}', '/a/{:%d+}',
	'/a/{*}', '/a/{*rest}', '/{+}', '/a/{+}'}) do
	local ok, err = pcall(function() rv.set(G, p, 1) end)
	if not ok then
		fail('unexpected error for ' .. p .. ': ' .. tostring(err))
	end
end

-- ---- match precedence and captures ----------------------------------------

local r = router()
r.set(G, '/', 1)
r.set(G, '/favicon.ico', 2)
r.set(G, '/page', 10)
r.set(G, '/page/', 11)
r.set(G, '/page/near', 12)
r.set(G, '/page/{:%a+}', 22)
r.set(G, '/page/{:%a+}', 23)
r.set(G, '/page/{:.*}', 24)
r.set(G, '/page/{:%d+}', 25)
r.set(G, '/page/{:%d+}/{:.+}', 30)
r.set(G, '/page/{:%d+}/related', 32)
r.set(G, '/page/{:(%d+)}/related', 33)
r.set(G, '/page/{:.*}/{:^[+-]?}/{:%d*$}', 50)
r.set(G, '/{:page%?}', 60)
r.set(G, '/{:p(%a+)}/{:%d(%d)}', 61)
r.set(G, '/{:page%w*}', 71)
r.set(G, '/{:page%w*-(%d)}', 72)
r.set(G, '/user/{id:%d+}', 80)
r.set(G, '/user/{id:%d+}/post/{pid:%d+}', 81)
r.set(G, '/files/{*}', 90)
r.set(G, '/docs/{*path}', 91)

local cases = {
	{'/', 1},
	{'/favicon.ico', 2},
	{'/page', {10, 11}},
	{'/page/', {10, 11}},
	{'/page/near', 12},
	{'/page/neared', {22, 23}, {'neared'}},
	{'/page/@peter', 24, {'@peter'}},
	{'/page/:id', 24, {':id'}},
	{'/page/123', 24, {'123'}},
	{'/page/123/456', 30, {'123', '456'}},
	{'/page/111/edit', 30, {'111', 'edit'}},
	{'/page/22//related', {32, 33}, {'22'}},
	{'/page/sept/-/4/', 50, {'sept', '-', '4'}},
	{'/pages100', 71, {'pages100'}},
	{'/pages200-2', 72, {'pages200-2', '2'}},
	{'/past/56', 61, {'past', 'ast', '56', '6'}},
	{'/user/42', 80, {'42'}},
	{'/user/42/post/7', 81, {'42', '7'}},
	{'/files/a/b/c', 90, {'a/b/c'}},
	{'/docs/a/b', 91, {'a/b'}},
}

for _, c in ipairs(cases) do
	local path, want, wm = c[1], c[2], c[3]
	if type(want) ~= 'table' then want = {want} end
	local got, m = r.match(G, path)
	arr_eq(got, want, 'match ' .. path .. ' ')
	if wm then arr_eq(m, wm, 'captures ' .. path .. ' ') end
end

-- named captures -> params (the third return value)
local _, _, p = r.match(G, '/user/42')
eq(p and p.id, '42', 'params.id for /user/42')
local _, _, p2 = r.match(G, '/user/42/post/7')
eq(p2 and p2.id, '42', 'params.id for /user/42/post/7')
eq(p2 and p2.pid, '7', 'params.pid for /user/42/post/7')
local _, _, p3 = r.match(G, '/docs/a/b')
eq(p3 and p3.path, 'a/b', 'named wildcard capture')
local _, m0, p0 = r.match(G, '/page')
eq(p0, nil, 'no params when the route has no named captures')
eq(type(m0), 'table', 'captures is a table')

-- strict mode rejects a double slash instead of normalising it
local s, serr = r.match(G, '/page/22//related', true)
eq(s, nil, 'strict double slash rejected')
eq(type(serr), 'string', 'strict double slash carries a message')

-- ---- prefix middleware -----------------------------------------------------

local mw_outer, mw_inner, leaf = function() end, function() end, function() end
local rw = router()
rw.set(G, '/api/{+}', mw_outer)
rw.set(G, '/api/v1/{+}', mw_inner)
rw.set(G, '/api/v1/orders', leaf)

arr_eq(rw.match(G, '/api/v1/orders'), {mw_outer, mw_inner, leaf}, 'middleware order ')
eq(rw.match('POST', '/api/v1/orders'), nil, 'middleware is method scoped')
eq(rw.match(G, '/api/nope'), nil, 'no terminal under the prefix')

-- the prefix node itself is wrapped too
local api_leaf = function() end
rw.set(G, '/api', api_leaf)
arr_eq(rw.match(G, '/api'), {mw_outer, api_leaf}, 'middleware wraps the prefix node ')

-- repeated matches must not corrupt the stored leaf
arr_eq(rw.match(G, '/api/v1/orders'), {mw_outer, mw_inner, leaf}, 'composition stable ')

-- a pattern in the prefix shares its node with routes on the same pattern
local p_mw, p_leaf = function() end, function() end
local rp = router()
rp.set(G, '/tenant/{:%d+}/{+}', p_mw)
rp.set(G, '/tenant/{:%d+}/orders', p_leaf)
arr_eq(rp.match(G, '/tenant/42/orders'), {p_mw, p_leaf}, 'pattern prefix shares node ')
eq(rp.match(G, '/tenant/abc/orders'), nil, 'pattern prefix needs the pattern to match')

-- ...but only through its own node: a different pattern token does not share
local c_mw, c_leaf = function() end, function() end
local rc = router()
rc.set(G, '/s/{:%d+}/{+}', c_mw)
rc.set(G, '/s/{:.*}/orders', c_leaf)
arr_eq(rc.match(G, '/s/42/orders'), {c_leaf}, 'middleware applies only through its node ')

-- middleware survives a failed exact branch and still wraps the winner
local x_mw, x_exact, x_pat = function() end, function() end, function() end
local rx = router()
rx.set(G, '/a/{+}', x_mw)
rx.set(G, '/a/exact', x_exact)
rx.set(G, '/a/{:.*}/x', x_pat)
arr_eq(rx.match(G, '/a/exact'), {x_mw, x_exact}, 'middleware with an exact terminal ')
arr_eq(rx.match(G, '/a/exact/x'), {x_mw, x_pat}, 'middleware survives a failed exact branch ')

-- ---- wildcard --------------------------------------------------------------

local st_leaf, w_leaf, d_leaf = function() end, function() end, function() end
local rwl = router()
rwl.set(G, '/files/static', st_leaf)
rwl.set(G, '/files/{*}', w_leaf)
rwl.set(G, '/docs/{*path}', d_leaf)

arr_eq(rwl.match(G, '/files/static'), {st_leaf}, 'literal beats wildcard ')
arr_eq(rwl.match(G, '/files/other'), {w_leaf}, 'wildcard matches the rest ')
eq(rwl.match(G, '/files'), nil, 'wildcard needs at least one segment')
eq(rwl.match(G, '/files/'), nil, 'trailing slash does not reach the wildcard')
local _, _, wp = rwl.match(G, '/docs/a/b')
eq(wp and wp.path, 'a/b', 'named wildcard capture value')

-- ---- allowed() ignores middleware-only nodes -------------------------------

local ra = router()
ra.set(G, '/api/{+}', function() end)          -- GET: middleware only
ra.set('DELETE', '/api/{+}', function() end)   -- DELETE: middleware only
ra.set(G, '/api/v1/orders', function() end)    -- GET: a real route

eq(ra.allowed('POST', '/api/x'), nil, 'middleware-only node is not a route')
eq(table.concat(ra.allowed('PUT', '/api/v1/orders') or {}, ', '), 'GET, HEAD',
	'middleware-only DELETE is not in Allow')
eq(ra.allowed(G, '/nope'), nil, 'unknown path -> nil')

-- ---- done ------------------------------------------------------------------

if fails == 0 then
	print('OK')
	os.exit(0)
end
print(fails .. ' failure(s)')
os.exit(1)
