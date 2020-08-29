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
            ngx.say("acq: ", k, " ", err)
            for i = 1, 2 do
               collectgarbage("collect")
               k, err = idem.advance()
               ngx.say("idem: ", k, " ", err)
            end
            k, err = idem.save(201, "YES")
            ngx.say("idem: ", k, " ", err)
            idem.release()
            k, err = idem.acquire("fdasds", 2, 20)
            ngx.say("acq: ", k, " ", err)
            k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("acq: ", k, " ", err)
            idem.release()
        }
    }
--- request
GET /t
--- response_body
acq: 1 nil
idem: 2 nil
idem: 3 nil
idem: 201 nil
acq: nil identity mismatch
acq: 201 YES

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
                ngx.say("sub acq: ", k, " ", err)
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
            ngx.say("acq: ", k, " ", err)
            k, err = idem.advance()
            ngx.say("idem: ", k, " ", err)
            k, err = idem.acquire(ngx.var.request_uri, 2, 20)
            ngx.say("acq: ", k, " ", err)
            k, err = idem.save(200, "YES")
            ngx.say("idem: ", k, " ", err)
            idem.release()
        }
    }
--- request
GET /t
--- response_body
sub acq: 1 nil
idem: false exists
sub idem: 2 nil
sub idem: false not locked
acq: 2 nil
idem: 3 nil
acq: false exists
idem: 200 nil

--- no_error_log
[error]




=== TEST 3: advancing via save()
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
            k, err = idem.save(5, "YES")
            ngx.say("idem: ", k, " ", err)
            idem.release()
            k, err = idem.acquire(ngx.var.request_uri, 2, 13)
            ngx.say("acq: ", k, " ", err)
            k, err = idem.save(6, "NOPE")
            idem.release()
            k, err = idem.save(7, "MAY")
            ngx.say("idem: ", k, " ", err)
            k, err = idem.acquire(ngx.var.request_uri, 2, 16)
            ngx.say("acq: ", k, " ", err)
            k, err = idem.save(8, "BE")
            ngx.say("idem: ", k, " ", err)
            k, err = idem.save(7)
            ngx.say("idem: ", k, " ", err)
            k, err = idem.advance()
            ngx.say("idem: ", k, " ", err)
        }
    }
--- request
GET /t
--- response_body
idem: 1 nil
idem: 2 nil
idem: 3 nil
idem: 5 nil
acq: 5 YES
idem: false not locked
acq: 6 NOPE
idem: 8 nil
idem: 7 nil
idem: 8 nil


--- no_error_log
[error]