-- Trusted-proxy / IP-restriction matcher tests for P3-7 (IPv6 CIDR).
--
-- losty.proxy depends only on LuaJIT's bit library and losty.to, so this runs
-- under plain luajit with no nginx server. From the repository root:
--
--   C:\bin\resty\luajit.exe t\proxy_test.lua
--
-- Contract: a `trusted` list entry may be an exact address, an IPv4 CIDR
-- (a.b.c.d/n, n in 0..32) or an IPv6 CIDR (addr/n, n in 0..128). A bare IPv6
-- literal -- with or without brackets -- is a /128, so every legal spelling of
-- the same address compares equal. Matching is family-correct: an IPv4 rule
-- never matches an IPv6 address and vice versa.

package.path = './?.lua;./t/?.lua;' .. package.path

local trustfn = require('losty.proxy').trustfn

local fails = 0
local function ok(cond, msg)
	if not cond then
		fails = fails + 1
		print('FAIL: ' .. msg)
	end
end

-- t(rules, ip) -> true when the matcher trusts ip
local function t(rules, ip)
	return trustfn(rules)(ip) == true
end

-- ---- IPv4 unchanged --------------------------------------------------------
ok(t({'127.0.0.0/8'}, '127.0.0.1'), 'v4 /8 inside')
ok(not t({'127.0.0.0/8'}, '128.0.0.1'), 'v4 /8 outside')
ok(t({'10.0.0.0/8'}, '10.255.255.255'), 'v4 /8 upper bound')
ok(not t({'10.0.0.0/8'}, '11.0.0.0'), 'v4 /8 just outside')
ok(t({'192.168.1.5'}, '192.168.1.5'), 'v4 exact')
ok(not t({'192.168.1.5'}, '192.168.1.6'), 'v4 exact miss')
ok(t({'0.0.0.0/0'}, '203.0.113.1'), 'v4 /0 matches all')

-- ---- IPv6 CIDR -------------------------------------------------------------
ok(t({'2001:db8::/32'}, '2001:db8::1'), 'v6 /32 inside (::1)')
ok(t({'2001:db8::/32'}, '2001:db8:ffff::1'), 'v6 /32 inside (ffff)')
ok(not t({'2001:db8::/32'}, '2001:db9::1'), 'v6 /32 just outside')
ok(not t({'2001:db8::/32'}, '2001:db7::1'), 'v6 /32 just below')

-- a prefix that is not a multiple of 16 (/34 -> top 2 bits of the 3rd group)
ok(t({'2001:db8::/34'}, '2001:db8:3fff::1'), 'v6 /34 inside')
ok(not t({'2001:db8::/34'}, '2001:db8:4000::1'), 'v6 /34 just outside')

-- /127 and /128 boundaries in the last group
ok(t({'2001:db8::/127'}, '2001:db8::1'), 'v6 /127 last group 0/1')
ok(not t({'2001:db8::/127'}, '2001:db8::2'), 'v6 /127 last group 2')
ok(t({'2001:db8::1/128'}, '2001:db8::1'), 'v6 /128 exact')
ok(not t({'2001:db8::1/128'}, '2001:db8::2'), 'v6 /128 miss')

-- /0 covers every address in the family
ok(t({'::/0'}, '2001:db8::1'), 'v6 /0 matches all')
ok(t({'::/0'}, '::'), 'v6 /0 matches the unspecified address')

-- ---- spelling normalization ------------------------------------------------
ok(t({'2001:db8::1'}, '2001:db8:0:0:0:0:0:1'), 'bare v6 = /128, expanded query')
ok(t({'2001:DB8::A'}, '2001:db8::a'), 'hex case is ignored')
ok(t({'[2001:db8::1]'}, '2001:db8::1'), 'bracketed entry')
ok(not t({'2001:db8::1'}, '2001:db8::2'), 'bare v6 /128 miss')

-- embedded IPv4 tail
ok(t({'::ffff:192.0.2.0/120'}, '::ffff:192.0.2.55'), 'v4-mapped /120 inside')
ok(not t({'::ffff:192.0.2.0/120'}, '::ffff:192.0.3.1'), 'v4-mapped /120 outside')

-- ---- families never cross --------------------------------------------------
ok(not t({'127.0.0.0/8'}, '2001:db8::1'), 'v4 rule never matches a v6 address')
ok(not t({'2001:db8::/32'}, '127.0.0.1'), 'v6 rule never matches a v4 address')

-- ---- mixed list, function form, malformed input ----------------------------
local mixed = trustfn({'127.0.0.0/8', '10.0.0.0/8', '2001:db8::/32', '::1'})
ok(mixed('127.0.0.1'), 'mixed: local v4')
ok(mixed('10.1.2.3'), 'mixed: private v4')
ok(mixed('2001:db8:1::1'), 'mixed: v6 cidr')
ok(mixed('::1'), 'mixed: v6 exact')
ok(not mixed('8.8.8.8'), 'mixed: public v4 rejected')
ok(not mixed('2001:dead::1'), 'mixed: other v6 rejected')

ok(trustfn(function() return true end)('203.0.113.5'), 'function trust is passed through')

-- malformed IPv6 never turns into a rule, so nothing spurious matches
ok(not t({'2001:db8::/129'}, '2001:db8::1'), 'v6 prefix >128 is not a rule')
ok(not t({'2001:db8:::1/64'}, '2001:db8::1'), 'stray colon is not a rule')
ok(not t({'1:2:3:4:5:6:7:8:9/128'}, '1:2:3:4:5:6:7:8'), 'too many groups is not a rule')

ok(not pcall(function() trustfn(42) end), 'non-table/non-function trusted errors')

if fails == 0 then
	print('OK')
	os.exit(0)
end
print(fails .. ' failure(s)')
os.exit(1)
