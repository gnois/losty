use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/?.lua;$pwd/t/?.lua;;";
    lua_shared_dict locks 100k;
    lua_shared_dict caches 100k;
};

no_long_string();

run_tests();

__DATA__


=== TEST 1: idempotency sanity
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local idempotent = require "losty.idempotent"
            local key = "foo"
            local idem = idempotent("locks", "caches", key)
            collectgarbage("collect")
            local k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("idem: ", k, " ", err)
            for i = 1, 2 do
               collectgarbage("collect")
               k, err = idem.advance()
               ngx.say("idem: ", k, " ", err)
            end
            k, err = idem.complete(201, "YES", 20)
            ngx.say("idem: ", k, " ", err)
            idem.release()
            k, err = idem.acquire("fdasds", 2, 20)
            ngx.say("idem: ", k, " ", err)
            k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("idem: ", k, " ", err)
            idem.release()
        }
    }
--- request
GET /t
--- response_body
idem: 1 nil
idem: 2 nil
idem: 3 nil
idem: true nil
idem: nil identity mismatch
idem: 201 YES

--- no_error_log
[error]


=== TEST: multiple acquire not allowed before release or timeout, advance must be locked
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local idempotent = require "losty.idempotent"
            local key = "foo"
            local idem = idempotent("locks", "caches", key)

            local t, err = ngx.thread.spawn(function()
                local k, err = idem.acquire(ngx.var.request_uri, 2, 20)
                ngx.say("sub idem: ", k, " ", err)
                for i = 1, 2 do
                    ngx.sleep(1)
                    k, err = idem.advance()
                    ngx.say("sub idem: ", k, " ", err)
                end

            end)

            local k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("idem: ", k, " ", err)
            ngx.sleep(2.5)
            k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("idem: ", k, " ", err)
            k, err = idem.advance()
            ngx.say("idem: ", k, " ", err)
            k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("idem: ", k, " ", err)
            k, err = idem.complete(200, "YES", 20)
            ngx.say("idem: ", k, " ", err)
            idem.release()
        }
    }
--- request
GET /t
--- response_body
sub idem: 1 nil
idem: false exists
sub idem: 2 nil
sub idem: false not locked
idem: 2 nil
idem: 3 nil
idem: false exists
idem: true nil

--- no_error_log
[error]

