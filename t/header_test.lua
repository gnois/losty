-- Response-header guard tests for P1-5.
--
-- losty.header reaches nginx only through the `ngx.header` table, so with a
-- one-field stub this runs under plain luajit with no server. From the
-- repository root:
--
--   C:\bin\resty\luajit.exe t\header_test.lua
--
-- Contract: a header name must be an RFC 9110 token, and a header value may not
-- contain any control character other than HTAB, nor DEL -- exactly the set
-- OpenResty would otherwise silently percent-escape on the way to the wire
-- (D10 in ROADMAP-http.md). A rejection names the header and the byte, so the
-- expected message is asserted verbatim here; change the wording in
-- lau/header.lau and t/protocol_headers.t in the same commit.

package.path = './?.lua;./t/?.lua;' .. package.path

-- ---- minimal ngx stub ------------------------------------------------------
-- the guard only ever writes to ngx.header
ngx = { header = {} }

local hdr = require('losty.header')
local headers = hdr.headers

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

-- a rejected assignment throws; drop the "file:line: " prefix the runtime adds
-- so what remains is exactly the guard's own message
local function outcome(fn)
	local ok_call, err = pcall(fn)
	if ok_call then
		return 'accepted'
	end
	return (tostring(err):gsub('^.-:%d+: ', ''))
end

local function accepts(label, fn)
	eq(outcome(fn), 'accepted', label)
end

-- build the value from string.char, so the case is independent of any escaping
-- in this file, and assert the message names the offending byte
local function rejects(name, byte, label)
	local value = 'bad' .. string.char(byte) .. 'value'
	local want = string.format("header '%s' value contains illegal byte 0x%02X", name, byte)
	eq(outcome(function() headers[name] = value end), want, label)
end

local function ok_name(name)
	eq(outcome(function() headers[name] = 'x' end), 'accepted',
		'name ' .. string.format('%q', name) .. ' is a token')
end

local function bad_name(name)
	eq(outcome(function() headers[name] = 'x' end),
		'header name must be a http token (RFC 9110)',
		'name ' .. string.format('%q', name) .. ' is rejected')
end

-- ---- the harness itself ----------------------------------------------------
-- a broken helper would make every case below vacuous
eq(outcome(function() end), 'accepted', 'a clean call is accepted')
ok(outcome(function() error('boom', 2) end) == 'boom', 'the prefix is stripped')
ok(outcome(function() error('t:1: t:2: x', 2) end) == 't:2: x', 'only the first prefix is stripped')

-- ---- names: RFC 9110 token (tchar+) ----------------------------------------
ok_name('Content-Type')
ok_name('X-Test')
ok_name('X-Custom_1')
ok_name('X~Y|Z')
ok_name('X%Z')

bad_name('Bad Name')
bad_name('Bad:Name')
bad_name('')
bad_name('X\n')
bad_name('X' .. string.char(127))

-- ---- values: %00-%08, %0A-%1F and %7F are rejected -------------------------
-- the boundaries of the set, around the legal HTAB (0x09)
rejects('X-V', 0, 'NUL (0x00)')
rejects('X-V', 1, 'SOH (0x01)')
rejects('X-V', 8, 'BS (0x08)')
rejects('X-V', 10, 'LF (0x0A)')
rejects('X-V', 11, 'VT (0x0B)')
rejects('X-V', 12, 'FF (0x0C)')
rejects('X-V', 13, 'CR (0x0D)')
rejects('X-V', 14, 'SO (0x0E)')
rejects('X-V', 27, 'ESC (0x1B)')
rejects('X-V', 31, 'US (0x1F)')
rejects('X-V', 127, 'DEL (0x7F)')

-- ... and everything a field value may legally carry is untouched
accepts('a plain string', function() headers['X-Plain'] = 'plain value' end)
accepts('a number', function() headers['X-Num'] = 42 end)
accepts('SP and HTAB (0x09)', function() headers['X-Tab'] = 'good\tvalue' end)
accepts('obs-text (0x80-0xFF)', function() headers['X-Hi'] = 'caf' .. string.char(233) end)
accepts('a clean array', function() headers['X-Arr'] = {'a', 'b'} end)
accepts('a clean nested array', function() headers['X-Nest'] = {{'a'}, {'b'}} end)
accepts('clearing with nil', function() headers['X-Num'] = nil end)
accepts('clearing with an empty table', function() headers['X-Arr'] = {} end)

-- ---- arrays and nesting ----------------------------------------------------
-- every leaf is checked, so one bad element rejects the whole assignment
local function rejects_value(value, byte, label)
	local want = string.format("header 'X-V' value contains illegal byte 0x%02X", byte)
	eq(outcome(function() headers['X-V'] = value end), want, label)
end

rejects_value({'fine', 'bad' .. string.char(11) .. 'x'}, 11, 'a bad element rejects the whole array')
rejects_value({{'fine'}, {'bad' .. string.char(127)}}, 127, 'a bad leaf in a nested array is found')
rejects_value({'ok', 'first' .. string.char(12) .. 'x', 'later' .. string.char(10)}, 12,
	'the first offending byte in traversal order is reported')

-- ---- Vary ------------------------------------------------------------------
eq(outcome(function() hdr.vary('Bad Name') end), 'vary name must be a http token (RFC 9110)',
	'vary() validates its name')
accepts('vary() accepts a token', function() hdr.vary('Accept') end)
eq(headers['Vary'], 'Accept', 'vary() sets Vary')
accepts('vary() is repeatable', function() hdr.vary('Accept') end)
eq(headers['Vary'], 'Accept', 'vary() does not duplicate a value it already has')
accepts('vary() merges', function() hdr.vary('Origin') end)
eq(headers['Vary'], 'Accept, Origin', 'vary() merges with the existing values')

-- ---- state -----------------------------------------------------------------
-- the guard runs before push(), so a rejected value is never half-written
eq(headers['X-V'], nil, 'a rejected value leaves no header behind')
eq(ngx.header['X-V'], nil, 'a rejected value never reaches ngx.header')

-- accepted values arrive byte-for-byte, in order
eq(headers['X-Plain'], 'plain value', 'a plain value round-trips')
eq(string.byte(ngx.header['X-Tab'], 5), 9, 'HTAB survives')
eq(string.byte(ngx.header['X-Hi'], 4), 233, 'obs-text survives')
-- push() stores the first value as given, so a nested array only stays safe
-- because the guard already walked every leaf
ok(type(ngx.header['X-Nest']) == 'table', 'an accepted nested array reaches ngx.header')

accepts('a first value', function() headers['X-App'] = 'one' end)
accepts('a second value', function() headers['X-App'] = 'two' end)
eq(type(ngx.header['X-App']), 'table', 'assigning twice appends rather than replaces')
eq(table.concat(ngx.header['X-App'], ','), 'one,two', 'appended values keep their order')

if fails == 0 then
	print('all header guard cases passed')
else
	print(fails .. ' failure(s)')
	os.exit(1)
end
