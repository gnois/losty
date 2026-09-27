-- Response-body rendering tests for P1-4.
--
-- losty.web talks to nginx only through the `ngx` global, so with a small stub
-- this runs under plain luajit with no server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\render_body.lua
--
-- Contract: any table returned by a handler is JSON-encoded (empty tables and
-- arrays included); an unencodable table raises instead of failing in ngx.print.

package.path = './?.lua;./t/?.lua;' .. package.path

-- ---- minimal ngx stub ------------------------------------------------------
local captured = {}
local phase = 'init'
local headers = {}

local function noop() return true end

ngx = {
	var = {},
	req = {},
	header = headers,
	status = 0,
	ERR = 4,
	NOTICE = 5,
	HTTP_OK = 200,
	get_phase = function() return phase end,
	print = function(...)
		for _, v in ipairs({...}) do
			captured[#captured + 1] = tostring(v)
		end
		return true
	end,
	flush = noop,
	eof = noop,
	send_headers = noop,
	log = noop,
	time = function() return 0 end,
	http_time = function() return 'Thu, 01 Jan 1970 00:00:00 GMT' end,
	cookie_time = function() return 'Thu, 01 Jan 1970 00:00:00 GMT' end,
	escape_uri = function(s) return s end,
	unescape_uri = function(s) return s end,
	encode_base64 = function(s) return s end,
	sha1_bin = function(s) return s end,
	exec = noop,
	exit = noop,
}

-- stub resty.sha1 / resty.string: etag.check hashes the body, but the real
-- modules need the ngx C API / ffi which isn't loaded here
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

local web = require('losty.web')

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

local w = web.route()  -- init phase

w.get('/empty', function(q, r) r.status = 200 ; return {} end)
w.get('/array', function(q, r) r.status = 200 ; return {1, 2, 3} end)
w.get('/dict', function(q, r) r.status = 200 ; return {ok = true} end)
w.get('/text', function(q, r)
	r.status = 200
	r.headers['Content-Type'] = 'text/plain'
	return 'hi'
end)
w.get('/iter', function(q, r)
	r.status = 200
	local parts = {'x', 'y', 'z'}
	local i = 0
	return function()
		i = i + 1
		return parts[i]
	end
end)
w.get('/bad', function(q, r) r.status = 200 ; return {f = print} end)

local function req(uri)
	phase = 'content'
	-- mutate ngx.var in place: losty.req captures the table at load time
	for k in pairs(ngx.var) do ngx.var[k] = nil end
	ngx.var.request_method = 'GET'
	ngx.var.uri = uri
	ngx.var.request_uri = uri
	ngx.status = 0
	captured = {}
	for k in pairs(headers) do headers[k] = nil end
	local code, err = web.run()
	local body = table.concat(captured)
	local ctype = headers['Content-Type']
	if 'table' == type(ctype) then ctype = ctype[1] end
	return code, body, ctype, err
end

-- ---- cases -----------------------------------------------------------------

local _, body, ctype = req('/empty')
eq(body, '{}', 'empty table -> JSON object (was an ngx.print error)')
eq(ctype, 'application/json', 'empty table sets JSON content-type')

_, body, ctype = req('/array')
eq(body, '[1,2,3]', 'array table -> JSON array (was chunked "123")')
eq(ctype, 'application/json', 'array sets JSON content-type')

_, body = req('/dict')
eq(body, '{"ok":true}', 'dict table -> JSON object')

_, body, ctype = req('/text')
eq(body, 'hi', 'string body is sent verbatim')
eq(ctype, 'text/plain', 'string body keeps a handler-set content-type')

_, body = req('/iter')
eq(body, 'xyz', 'a function body is still streamed')

local ok_call, err = pcall(req, '/bad')
ok(not ok_call, 'unencodable table raises instead of mis-rendering')
ok(ok_call or tostring(err):match('not JSON%-encodable') ~= nil,
	'error is clear, got ' .. tostring(err))

if fails == 0 then
	print('all render_body cases passed')
else
	print(fails .. ' failure(s)')
	os.exit(1)
end
