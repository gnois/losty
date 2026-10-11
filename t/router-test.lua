-- Router tests for the brace grammar and prefix middleware.
--
-- losty.router has no ngx dependency, so this runs under plain luajit with no
-- nginx server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\router-test.lua
--
-- Covers registration validation, match precedence, trailing-slash and
-- strict-mode rules, named captures (in q.match), wildcard, prefix middleware
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

-- compare a captures table exactly: numeric keys are positional, string keys named
local function match_eq(got, want, msg)
	if type(got) ~= 'table' then
		fail(msg .. ': got ' .. type(got) .. ', want table')
		return
	end
	for k, v in pairs(want) do
		if got[k] ~= v then
			fail(msg .. '[' .. tostring(k) .. ']: got ' .. tostring(got[k]) .. ', want ' .. tostring(v))
			return
		end
	end
	for k, v in pairs(got) do
		if want[k] ~= v then
			fail(msg .. '[' .. tostring(k) .. ']: got ' .. tostring(v) .. ', want nil')
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
bad('/dup/{id}/{id}')           -- duplicate capture name in one route
bad('/dup/{id}/{*id}')          -- duplicate name: cap and wildcard

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
r.set(G, '/named/{x:p(%a+)}', 95)

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
	{'/user/42', 80, {id = '42'}},
	{'/user/42/post/7', 81, {id = '42', pid = '7'}},
	{'/files/a/b/c', 90, {'a/b/c'}},
	{'/docs/a/b', 91, {path = 'a/b'}},
	{'/named/past', 95, {'ast', x = 'past'}},
}

for _, c in ipairs(cases) do
	local path, want, wm = c[1], c[2], c[3]
	if type(want) ~= 'table' then want = {want} end
	local got, m = r.match(G, path)
	arr_eq(got, want, 'match ' .. path .. ' ')
	if wm then match_eq(m, wm, 'captures ' .. path .. ' ') end
end

-- named captures land in q.match by name, never positionally
local _, n1 = r.match(G, '/user/42')
eq(n1 and n1.id, '42', 'named id for /user/42')
eq(n1 and #n1, 0, 'a named capture takes no array slot')
local _, n2 = r.match(G, '/user/42/post/7')
eq(n2 and n2.id, '42', 'named id for /user/42/post/7')
eq(n2 and n2.pid, '7', 'named pid for /user/42/post/7')
local _, n3 = r.match(G, '/docs/a/b')
eq(n3 and n3.path, 'a/b', 'named wildcard capture')
eq(n3 and #n3, 0, 'a named wildcard takes no array slot')
local _, m0 = r.match(G, '/page')
eq(type(m0), 'table', 'captures is a table')
eq(next(m0), nil, 'no captures when the route has none')

-- a named and an unnamed token are distinct even with the same pattern
local rn = router()
rn.set(G, '/a/{:%d+}', 1)
rn.set(G, '/a/{id:%d+}', 2)
local lfp, mpp = rn.match(G, '/a/42')
arr_eq(lfp, {1}, 'a positional token is not merged with a named one ')
eq(mpp and mpp[1], '42', 'the positional capture stays in the array')
eq(mpp and mpp.id, nil, 'the positional capture is not keyed by the named token')

local rd = router()
rd.set(G, '/b/{id:%d+}', 1)
rd.set(G, '/b/{uid:%d+}', 2)
local _, mdd = rd.match(G, '/b/42')
eq(mdd and mdd.id, '42', 'the first named token wins')
eq(mdd and mdd.uid, nil, 'a sibling name does not leak into q.match')

-- a named and an unnamed wildcard are distinct even on the same parent
local rw2 = router()
rw2.set(G, '/f/{*}', 1)
rw2.set(G, '/f/{*rest}', 2)
local lfw, mw2 = rw2.match(G, '/f/a/b')
arr_eq(lfw, {1}, 'an unnamed wildcard is not merged with a named one ')
eq(mw2 and mw2[1], 'a/b', 'the unnamed wildcard stays in the array')
eq(mw2 and mw2.rest, nil, 'the unnamed wildcard is not keyed by the named one')

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
local _, wmv = rwl.match(G, '/docs/a/b')
eq(wmv and wmv.path, 'a/b', 'named wildcard capture value')
eq(wmv and #wmv, 0, 'a named wildcard takes no array slot')
local _, wav = rwl.match(G, '/files/a/b')
eq(wav and wav[1], 'a/b', 'unnamed wildcard capture is positional')
eq(wav and #wav, 1, 'unnamed wildcard takes one array slot')
eq(rwl.match(G, '/docs'), nil, 'named wildcard needs at least one segment')
eq(rwl.match(G, '/docs/'), nil, 'trailing slash does not reach a named wildcard')

-- ---- determinism and no ambiguity ------------------------------------------

-- a literal always beats a pattern, whichever is registered first
local rlp = router()
rlp.set(G, '/p/{:.*}', 1)
rlp.set(G, '/p/literal', 2)
arr_eq(rlp.match(G, '/p/literal'), {2}, 'literal beats a pattern registered earlier ')
arr_eq(rlp.match(G, '/p/other'), {1}, 'the pattern still matches other segments ')

-- a pattern always beats a wildcard, whichever is registered first
local rpw = router()
rpw.set(G, '/w/{*}', 1)
rpw.set(G, '/w/{:.*}/x', 2)
arr_eq(rpw.match(G, '/w/ab/x'), {2}, 'pattern beats a wildcard registered earlier ')
arr_eq(rpw.match(G, '/w/ab'), {1}, 'wildcard catches a path the pattern cannot end ')

-- routes are per method; captures never cross a method boundary
local rfirst = router()
rfirst.set('GET', '/m/{id:%d+}', 1)
rfirst.set('POST', '/m/{:.*}', 2)
local lgm, mgm = rfirst.match('GET', '/m/9')
arr_eq(lgm, {1}, 'GET route matched ')
eq(mgm and mgm.id, '9', 'GET capture is named')
local lpm, mpm = rfirst.match('POST', '/m/9')
arr_eq(lpm, {2}, 'POST route matched ')
eq(mpm and mpm[1], '9', 'POST capture is positional')
eq(mpm and mpm.id, nil, 'POST capture is not the GET one')
eq(rfirst.match('PUT', '/m/9'), nil, 'an unregistered method misses')

-- a failed pattern branch must not leak its captures
local rb = router()
rb.set(G, '/x/{id:%d+}/end', 1)
rb.set(G, '/x/{:.*}/other', 2)
local lb, mb = rb.match(G, '/x/12/other')
arr_eq(lb, {2}, 'a backtracked branch does not keep its handler ')
eq(mb and mb[1], '12', 'the fallback positional capture is in the array')
eq(mb and mb.id, nil, 'the backtracked named capture is dropped')
local lb2, mb2 = rb.match(G, '/x/12/end')
arr_eq(lb2, {1}, 'the named branch still wins when its terminal exists ')
eq(mb2 and mb2.id, '12', 'the named capture binds on its own branch')

-- named and positional captures coexist without collision
local rnp = router()
rnp.set(G, '/o/{a}/{:%d+}/{b}', 1)
local l_np, m_np = rnp.match(G, '/o/x/7/y')
arr_eq(l_np, {1}, 'named+positional route matched ')
match_eq(m_np, {'7', a = 'x', b = 'y'}, 'a positional index and names coexist ')

-- a name binds one segment only (the default pattern is [^/]+)
local rdef = router()
rdef.set(G, '/g/{id}', 1)
eq(rdef.match(G, '/g/a/b'), nil, 'the default named capture matches one segment')
local _, mdef = rdef.match(G, '/g/a')
eq(mdef and mdef.id, 'a', 'the default named capture binds the segment')

-- query string and trailing slash do not change the captures
local _, mq = r.match(G, '/user/42?x=1')
eq(mq and mq.id, '42', 'the query string is stripped before capturing')
local _, mts = r.match(G, '/user/42/')
eq(mts and mts.id, '42', 'a trailing slash still binds the capture')

-- repeated identical routes accumulate handlers, capture once
local rsame = router()
local s1, s2 = function() end, function() end
rsame.set(G, '/same', s1)
rsame.set(G, '/same', s2)
arr_eq(rsame.match(G, '/same'), {s1, s2}, 'identical literal routes accumulate in order ')
local rcap = router()
local c1, c2 = function() end, function() end
rcap.set(G, '/u/{id:%d+}', c1)
rcap.set(G, '/u/{id:%d+}', c2)
local l_cap, m_cap = rcap.match(G, '/u/5')
arr_eq(l_cap, {c1, c2}, 'identical named tokens accumulate in order ')
match_eq(m_cap, {id = '5'}, 'the capture is bound once')

-- q.match is deterministic and fresh across calls
local rdet = router()
rdet.set(G, '/d/{id:%d+}/e/{:%a+}', 1)
rdet.set(G, '/d/{:.*}/f', 2)
rdet.set(G, '/d/{*rest}', 3)
local _, md1 = rdet.match(G, '/d/12/e/xy')
local _, md2 = rdet.match(G, '/d/12/e/xy')
match_eq(md2, md1, 'a repeated match yields the same q.match ')
rdet.match(G, '/d/zzz/f')
rdet.match(G, '/d/zzz')
local _, md3 = rdet.match(G, '/d/12/e/xy')
match_eq(md3, md1, 'q.match survives unrelated matches ')
eq(md1 and md1.id, '12', 'the named capture is still bound')
eq(md1 and md1[1], 'xy', 'the positional capture is still bound')
md1.injected = 'x'
local _, md4 = rdet.match(G, '/d/12/e/xy')
eq(md4 and md4.injected, nil, 'q.match is a fresh table each call')

-- the same name in different routes is fine; within one route it is an error
local rok = router()
eq(pcall(function() rok.set(G, '/u1/{id}', 1) end), true, 'name id in route 1 is allowed')
eq(pcall(function() rok.set(G, '/u2/{id}', 2) end), true, 'name id in route 2 is allowed')

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
