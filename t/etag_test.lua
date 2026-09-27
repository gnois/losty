-- Conditional-request tests for P1-8 (Last-Modified / If-Modified-Since).
--
-- losty.etag reaches nginx only through the `ngx` global (parse_http_time and
-- the status constants), so with a small stub this runs under plain luajit with
-- no server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\etag_test.lua
--
-- Contract: a 200 GET/HEAD is turned into a 304 when the client copy is still
-- current -- by If-None-Match (entity tag), or, only when the request carries no
-- If-None-Match, by If-Modified-Since against a handler-set Last-Modified.

package.path = './?.lua;./t/?.lua;' .. package.path

-- ---- minimal ngx stub ------------------------------------------------------
local MONTH = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
	Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }

-- just enough of RFC 9110's IMF-fixdate to order two dates; nil for anything
-- else, so the "ignore an unparsable date" rule can be exercised
local function parse_http_time(str)
	local d, mon, y, hh, mm, ss = string.match(str, '^%a%a%a, (%d%d) (%a%a%a) (%d%d%d%d) (%d%d):(%d%d):(%d%d)')
	if not d or not MONTH[mon] then
		return nil
	end
	return tonumber(y) * 10 ^ 10 + MONTH[mon] * 10 ^ 8 + tonumber(d) * 10 ^ 6
		+ tonumber(hh) * 10 ^ 4 + tonumber(mm) * 10 ^ 2 + tonumber(ss)
end

ngx = {
	HTTP_OK = 200,
	HTTP_NOT_MODIFIED = 304,
	HTTP_PRECONDITION_FAILED = 412,
	parse_http_time = parse_http_time,
}

-- stub the digest modules: the auto-ETag path needs them, and the real ones
-- require the ngx C API / ffi which isn't loaded here
package.loaded['resty.sha1'] = {
	new = function(self)
		return {
			update = function() return true end,
			final = function() return string.rep('\0', 20) end,
		}
	end,
}
package.loaded['resty.string'] = {
	to_hex = function(s)
		return (string.gsub(s, '.', function(c) return string.format('%02x', string.byte(c)) end))
	end,
}

local etag = require('losty.etag')

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

-- ---- cases -----------------------------------------------------------------
local LM = 'Tue, 15 Nov 1994 08:12:31 GMT'
local EARLIER = 'Mon, 14 Nov 1994 08:12:31 GMT'
local LATER = 'Wed, 16 Nov 1994 08:12:31 GMT'
local AUTO = 'W/"' .. string.rep('00', 20) .. '"'   -- the stubbed digest

-- run check() once and assert both the status and the body it hands back
local function chk(label, qheaders, rheaders, want_status, want_body)
	local q = { vars = { request_method = 'GET' }, headers = qheaders }
	local r = { status = 200, headers = rheaders }
	local got = etag.check(q, r, 'hello')
	eq(r.status, want_status, label .. ' [status]')
	eq(got, want_body, label .. ' [body]')
	return r
end

-- no conditional header: untouched
chk('no conditionals', {}, {['Last-Modified'] = LM}, 200, 'hello')

-- If-Modified-Since against a handler-set Last-Modified
chk('date equal to Last-Modified', {['If-Modified-Since'] = LM}, {['Last-Modified'] = LM}, 304, nil)
chk('date later than Last-Modified', {['If-Modified-Since'] = LATER}, {['Last-Modified'] = LM}, 304, nil)
chk('date earlier than Last-Modified', {['If-Modified-Since'] = EARLIER}, {['Last-Modified'] = LM}, 200, 'hello')

-- the 304 keeps the validator, so the next round can be revalidated too
local r = chk('304 keeps Last-Modified', {['If-Modified-Since'] = LM}, {['Last-Modified'] = LM}, 304, nil)
eq(r.headers['Last-Modified'], LM, 'the 304 keeps Last-Modified')

-- only a handler-set, parseable Last-Modified is usable
chk('no Last-Modified', {['If-Modified-Since'] = LM}, {}, 200, 'hello')
chk('Last-Modified not a date', {['If-Modified-Since'] = LM}, {['Last-Modified'] = 'not a date'}, 200, 'hello')
chk('If-Modified-Since not a date', {['If-Modified-Since'] = 'nope'}, {['Last-Modified'] = LM}, 200, 'hello')
chk('empty If-Modified-Since', {['If-Modified-Since'] = ''}, {['Last-Modified'] = LM}, 200, 'hello')

-- If-Modified-Since works without any ETag
chk('date-only 304', {['If-Modified-Since'] = LM}, {['Last-Modified'] = LM}, 304, nil)

-- If-None-Match wins, even when it fails and the date alone would have matched
chk('stale If-None-Match beats a matching date',
	{['If-None-Match'] = '"stale"', ['If-Modified-Since'] = LATER},
	{['Last-Modified'] = LM, ETag = '"v1"'}, 200, 'hello')
chk('matching If-None-Match', {['If-None-Match'] = '"v1"'}, {['Last-Modified'] = LM, ETag = '"v1"'}, 304, nil)
chk('If-None-Match star', {['If-None-Match'] = '*'}, {['Last-Modified'] = LM, ETag = '"v1"'}, 304, nil)
-- weak comparison: the W/ prefix is stripped on both sides, so a weak tag on
-- either side still matches a strong one
chk('weak request tag vs strong response tag', {['If-None-Match'] = 'W/"v1"'}, {ETag = '"v1"'}, 304, nil)
chk('strong request tag vs weak response tag', {['If-None-Match'] = '"v1"'}, {ETag = 'W/"v1"'}, 304, nil)
chk('different opaque value', {['If-None-Match'] = '"v2"'}, {ETag = '"v1"'}, 200, 'hello')
-- a matching If-None-Match still 304s when the date is stale
chk('matching If-None-Match with a stale date',
	{['If-None-Match'] = '"v1"', ['If-Modified-Since'] = EARLIER},
	{['Last-Modified'] = LM, ETag = '"v1"'}, 304, nil)

-- the body-derived tag is weak (nginx may gzip the same bytes)
local ra = chk('auto ETag', {}, {}, 200, 'hello')
eq(ra.headers['ETag'], AUTO, 'the auto tag is weak and derived from the body')
chk('auto ETag matches', {['If-None-Match'] = AUTO}, {}, 304, nil)

-- no-store without a handler ETag keeps the old early return
chk('no-store blocks a date-only 304',
	{['If-Modified-Since'] = LM},
	{['Last-Modified'] = LM, ['Cache-Control'] = 'no-store, max-age=0'}, 200, 'hello')

-- only a successful response of a safe method is revalidated
local q0 = { vars = { request_method = 'GET' }, headers = {['If-Modified-Since'] = LM} }
local r0 = { status = 0, headers = {['Last-Modified'] = LM} }
eq(etag.check(q0, r0, 'hello'), nil, 'an unset status is revalidated')
eq(r0.status, 304, 'an unset status becomes 304')

local qh = { vars = { request_method = 'HEAD' }, headers = {['If-Modified-Since'] = LM} }
local rh = { status = 200, headers = {['Last-Modified'] = LM} }
eq(etag.check(qh, rh, 'hello'), nil, 'HEAD is revalidated')
eq(rh.status, 304, 'HEAD becomes 304')

local qp = { vars = { request_method = 'POST' }, headers = {['If-Modified-Since'] = LM} }
local rp = { status = 200, headers = {['Last-Modified'] = LM} }
eq(etag.check(qp, rp, 'hello'), 'hello', 'POST is not revalidated')
eq(rp.status, 200, 'POST keeps its status')

local q5 = { vars = { request_method = 'GET' }, headers = {['If-Modified-Since'] = LM} }
local r5 = { status = 500, headers = {['Last-Modified'] = LM} }
eq(etag.check(q5, r5, 'hello'), 'hello', 'a 500 is not revalidated')
eq(r5.status, 500, 'a 500 keeps its status')

local qe = { vars = { request_method = 'GET' }, headers = {['If-Modified-Since'] = LM} }
local re = { status = 200, headers = {['Last-Modified'] = LM} }
eq(etag.check(qe, re, ''), '', 'an empty body is untouched')
eq(re.status, 200, 'an empty body keeps its status')

-- ---- preconditions for unsafe methods (P1-8 b) -----------------------------
-- the middleware runs before the mutating handler, so drive it with a stub nxt
-- that records whether the chain was allowed to continue
local calls, reached
local function pre(label, qheaders, method, tag, want_status, want_reached)
	local q = { vars = { request_method = method }, headers = qheaders }
	local r = { status = 200, headers = {} }
	calls, reached = 0, false
	local out = etag.precondition(function()
		calls = calls + 1
		return tag
	end)(q, r, function()
		reached = true
		return 'downstream'
	end)
	eq(r.status, want_status, label .. ' [status]')
	eq(reached, want_reached, label .. ' [handler reached]')
	eq(out, want_reached and 'downstream' or nil, label .. ' [chain value]')
	return r
end

-- no precondition header at all: the handler runs
pre('PUT, no preconditions', {}, 'PUT', '"v1"', 200, true)

-- If-Match, strong comparison
pre('PUT, If-Match equal', {['If-Match'] = '"v1"'}, 'PUT', '"v1"', 200, true)
pre('PUT, If-Match different', {['If-Match'] = '"v2"'}, 'PUT', '"v1"', 412, false)
pre('PUT, If-Match list with one match', {['If-Match'] = '"v0", "v1"'}, 'PUT', '"v1"', 200, true)
pre('PUT, If-Match * with a representation', {['If-Match'] = '*'}, 'PUT', '"v1"', 200, true)
pre('PUT, If-Match * with none', {['If-Match'] = '*'}, 'PUT', nil, 412, false)
pre('PUT, If-Match weak candidate', {['If-Match'] = 'W/"v1"'}, 'PUT', '"v1"', 412, false)
pre('PUT, If-Match against a weak current', {['If-Match'] = '"v1"'}, 'PUT', 'W/"v1"', 412, false)

-- If-None-Match, weak comparison
pre('PUT, If-None-Match matching weakly', {['If-None-Match'] = 'W/"v1"'}, 'PUT', '"v1"', 412, false)
pre('PUT, If-None-Match * with a representation', {['If-None-Match'] = '*'}, 'PUT', '"v1"', 412, false)
pre('PUT, If-None-Match * with none', {['If-None-Match'] = '*'}, 'PUT', nil, 200, true)
pre('PUT, If-None-Match stale', {['If-None-Match'] = '"v9"'}, 'PUT', '"v1"', 200, true)
pre('PUT, If-None-Match stale with nothing stored', {['If-None-Match'] = '"v9"'}, 'PUT', nil, 200, true)

-- If-Match is evaluated first and short-circuits (RFC 9110 s13.2.2)
pre('PUT, failing If-Match is not rescued by If-None-Match',
	{['If-Match'] = '"v2"', ['If-None-Match'] = '*'}, 'PUT', '"v1"', 412, false)
pre('PUT, passing If-Match still applies If-None-Match',
	{['If-Match'] = '"v1"', ['If-None-Match'] = '"v1"'}, 'PUT', '"v1"', 412, false)

-- a safe method is passed through, and the current tag is never looked up
pre('GET, failing If-Match', {['If-Match'] = '*'}, 'GET', nil, 200, true)
eq(calls, 0, 'get_tag is not called for a safe method')
pre('HEAD, failing If-Match', {['If-Match'] = '*'}, 'HEAD', nil, 200, true)

-- a broken get_tag is a programming error, not a 412
local okc, err = pcall(etag.precondition)
eq(okc, false, 'precondition() without a function raises')
ok(tostring(err):find('tag getter', 1, true) ~= nil,
	'the message says what is missing, got ' .. tostring(err))

okc, err = pcall(function()
	etag.precondition(function() return {} end)(
		{ vars = { request_method = 'PUT' }, headers = {} }, { status = 200, headers = {} }, function() end)
end)
eq(okc, false, 'a non-string tag raises')
ok(tostring(err):find('must return a string or nil', 1, true) ~= nil,
	'the message says what is wrong, got ' .. tostring(err))

-- ---- the middleware must not disturb the payload chain ---------------------
-- dispatch accumulates the payload and re-supplies it on every nxt(), so a
-- middleware calls nxt() and never nxt(...) (see the note in lau/dispatch.lau).
-- Drive the real dispatch with a payload-adding handler in front.
local dispatch = require('losty.dispatch')
local tail, tail_n
local function chain()
	return {
		function(q, r, nxt)              -- stands in for `form`
			return nxt('BODY')
		end,
		etag.precondition(function() return '"v1"' end),
		function(q, r, nxt, ...)
			tail, tail_n = select(1, ...), select('#', ...)
			return 'done'
		end,
	}
end

local out = dispatch(chain(),
	{ vars = { request_method = 'PUT' }, headers = {} }, { status = 200, headers = {} })
eq(out, 'done', 'the chain runs to the end')
eq(tail, 'BODY', 'the payload reaches the tail')
eq(tail_n, 1, 'the payload is passed through exactly once')

-- failing in the middle: nothing downstream runs, and the payload is dropped
-- with the rest of the chain
tail, tail_n = nil, nil
local r = { status = 200, headers = {} }
out = dispatch(chain(),
	{ vars = { request_method = 'PUT' }, headers = {['If-Match'] = '"v2"'} }, r)
eq(out, nil, 'a failing precondition stops the chain')
eq(r.status, 412, 'a failing precondition answers 412')
eq(tail_n, nil, 'the tail never runs')

if fails == 0 then
	print('all etag cases passed')
else
	print(fails .. ' failure(s)')
	os.exit(1)
end
