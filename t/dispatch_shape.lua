-- Argument-shape tests for the CPS dispatcher (P2-7).
--
-- losty.dispatch has no ngx dependency, so this runs under plain luajit with no
-- nginx server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\dispatch_shape.lua
--
-- Cases 1-3 and 8 are ported from the commented-out block that used to live in
-- lau/dispatch.lau. The rest, in particular case 6, are the reasons the
-- continuation was moved off the request object.

package.path = './?.lua;./t/?.lua;' .. package.path

local dispatch = require('losty.dispatch')

local fails = 0

local function ok(cond, msg)
	if not cond then
		fails = fails + 1
		print('FAIL: ' .. msg)
	end
end

local function eq(got, want, msg)
	if got ~= want then
		fails = fails + 1
		print('FAIL: ' .. msg .. '\n  got  ' .. tostring(got) .. '\n  want ' .. tostring(want))
	end
end

-- record each hop: name, then the payload args (nils spelled out)
local trail
local function add(tag, ...)
	local n = select('#', ...)
	local parts = {tag}
	for i = 1, n do
		local v = select(i, ...)
		parts[#parts + 1] = v == nil and 'nil' or tostring(v)
	end
	trail[#trail + 1] = table.concat(parts, ' ')
end

-- 1. no handlers must not error
dispatch({}, {}, {})

-- 2. nxt is arg 3, payload starts at arg 4 and accumulates across hops,
--    preserving embedded nils
local a = function(q, r, nxt, ...)
	add('=>a', ...)
	local v, w, x = nxt(nil)
	add('a<=')
	return v, w, x
end
local b = function(q, r, nxt, ...)
	add('=>b', ...)
	local v, w = nxt(nil, nil)
	add('b<=')
	return v, w, ' and b'
end
local c = function(q, r, nxt, ...)
	add('=>c', ...)
	add('c<=')
	return nil, 'c'
end

trail = {}
local m, n, o = dispatch({a, b, c}, {}, {})
eq(table.concat(trail, ' '), '=>a =>b nil =>c nil nil nil c<= b<= a<=', 'cumulative payload with nils')
eq(m, nil, 'first return of nxt is nil')
eq(n .. o, 'c and b', 'multiple returns propagate upstream')

-- 3. mixed numbers and nils through several hops
local e = function(q, r, nxt, ...)
	add('=>e', ...)
	local v = nxt(4, nil)
	add('e<=')
	return v or 'e()'
end
local f = function(q, r, nxt, ...)
	add('=>f', ...)
	local v = nxt(nil, 5)
	add('f<=')
	return v or 'f()'
end
local g = function(q, r, nxt, ...)
	add('=>g', ...)
	local v = nxt(6, nil, 7)
	add('g<=')
	return v or 'g()'
end
local h = function(q, r, nxt, ...)
	add('=>h', ...)
	add('h<=')
	return 'h()'
end

trail = {}
eq(dispatch({e, f, g, h}, {}, {}, 1), 'h()', 'value from the end of the chain')
eq(table.concat(trail, ' '),
	'=>e 1 =>f 1 4 nil =>g 1 4 nil nil 5 =>h 1 4 nil nil 5 6 nil 7 h<= g<= f<= e<=',
	'nil positions preserved')

-- 4. calling nxt() past the end is legal and returns nothing
local last = function(q, r, nxt)
	return nxt()
end
eq(dispatch({last}, {}, {}), nil, 'nxt() past the end returns nothing')

-- 5. a leaf handler that ignores nxt and payload still works (most app code)
local leaf = function(q, r)
	return 'leaf'
end
eq(dispatch({leaf}, {}, {}), 'leaf', 'leaf handler ignores the extra args')

local first = function(q, r, nxt)
	return nxt('x', 'y')
end
local tail = function(q, r, nxt, p, qv)
	return p .. qv
end
eq(dispatch({first, tail}, {}, {}), 'xy', 'payload reaches a named tail handler')

-- 6. THE regression: a nested dispatch() must not corrupt the outer continuation.
--    Under the old design (req.next = invoke) the outer nxt() below resolved to
--    the inner chain and returned nil; content.dual had to work around this.
local outer_ran, inner_ran = 0, 0

local outer_tail = function(q, r, nxt)
	outer_ran = outer_ran + 1
	return 'outer-tail'
end

local inner_handler = function(q, r, nxt)
	inner_ran = inner_ran + 1
	return 'inner'
end

local nested = function(q, r, nxt)
	local got = dispatch({inner_handler}, q, r) -- re-entrant, as content.dual does
	eq(got, 'inner', 'nested dispatch returns its own value')
	return nxt() -- must reach outer_tail, not the inner chain
end

eq(dispatch({nested, outer_tail}, {}, {}), 'outer-tail', 'outer nxt() survives a nested dispatch')
eq(outer_ran, 1, 'outer tail ran exactly once')
eq(inner_ran, 1, 'inner handler ran exactly once')

-- 7. two sequential dispatches on the same request must not interfere
local mk = function(tag)
	return function(q, r, nxt)
		return tag
	end
end
eq(dispatch({mk('one')}, {}, {}), 'one', 'first dispatch')
eq(dispatch({mk('two')}, {}, {}), 'two', 'second dispatch')

-- 8. re-entrance: a handler may call nxt() without returning, and keeps running
--    after the downstream chain unwinds
local k = function(q, r, nxt, ...)
	add('=>k', ...)
	nxt(nil)
	add('k<=')
end

trail = {}
dispatch({k, k, k, k}, {}, {})
eq(table.concat(trail, ' '),
	'=>k =>k nil =>k nil nil =>k nil nil nil k<= k<= k<= k<=',
	'nxt() may be called without returning')

-- 9. nxt() preserves the accumulated payload, so a pass-through middleware has
--    nothing to forward
local seen_args
local give = function(q, r, nxt)
	return nxt('a', 'b')
end
local watch = function(q, r, nxt, ...)
	seen_args = select('#', ...)
	return nxt()
end
local sink = function(q, r, nxt, ...)
	return select('#', ...)
end
eq(dispatch({give, watch, sink}, {}, {}), 2, 'nxt() keeps the payload intact')
eq(seen_args, 2, 'the pass-through saw the whole payload')

-- 10. documented sharp edge: a pass-through written as `return nxt(...)`
--     re-appends what it was given, doubling the payload every hop
local fwd = function(q, r, nxt, ...)
	return nxt(...)
end
eq(dispatch({fwd, fwd, sink}, {}, {}, 'x'), 4, 'nxt(...) doubles the payload each hop')

if fails > 0 then
	print('\n' .. fails .. ' failure(s)')
	os.exit(1)
end
print('dispatch_shape: all assertions passed')
