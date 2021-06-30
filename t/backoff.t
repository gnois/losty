use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
   lua_package_path "$pwd/?.lua;$pwd/t/?.lua;;";
   lua_shared_dict back 100k;

   init_by_lua_block {
      math.randomseed(1001)
   }
};

no_long_string();

run_tests();

__DATA__


=== TEST 1: backoff sanity
--- http_config eval: $::HttpConfig
--- config
   location = /t {
      content_by_lua_block {
         local backoff = require "losty.backoff"
         local b = backoff.new('back', 1, 60)
         local delay = b:incoming('foo', true)
         ngx.print('delay: ', delay)
      }
   }
--- pipelined_requests eval
["GET /t", "GET /t", "GET /t", "GET /t", "GET /t"]
--- response_body eval
["delay: 0", "delay: 4", "delay: 8", "delay: 16", "delay: 32"]
--- no_error_log
[error]



=== TEST: backoff simulate
--- http_config eval: $::HttpConfig
--- timeout: 200
--- config
   location = /t {
      content_by_lua_block {
         local backoff = require "losty.backoff"
         local b = backoff.new('back', 2, 60)
         local delay = b:incoming('foo', true)
         ngx.print(delay)
      }
   }

   location /test {
      content_by_lua_block {
         local get = ngx.location.capture

         local res = get("/t")
         ngx.say(res.body)
         -- 8 - 3s
         ngx.sleep(3)
         res = get("/t")
         ngx.say(res.body)
         -- 16 - 9s
         ngx.sleep(6)
         res = get("/t")
         ngx.say(res.body)
         -- 32 - 13s
         ngx.sleep(4)
         res = get("/t")
         ngx.say(res.body)
         -- 64 - 37s
         ngx.sleep(24)
         res = get("/t")
         ngx.say(res.body)
         -- 128 - 129s
         ngx.sleep(92)
         res = get("/t")
         ngx.say(res.body)
      }
   }

--- request
GET /test
--- response_body_like chomp
0
7.\d+
8.\d+
26.\d+
26.\d+
10.\d+
--- no_error_log
[error]
--- ONLY


