use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/?.lua;$pwd/t/?.lua;;";
    lua_shared_dict locks 100k;
};

$ENV{TEST_NGINX_WORKER_USER}='www www';


no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: lock not affected by garbage collection
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local locker = require "losty.lock"
            local lock = locker("locks")
            local key = "foo"
            for i = 1, 2 do
                collectgarbage("collect")
                local ok, err = lock.lock(key)
                ngx.say("lock: ", ok, " ", err)
            end
            collectgarbage("collect")
            lock.unlock(key)
        }
    }
--- request
GET /t
--- response_body
lock: true nil
lock: false exists

--- no_error_log
[error]



=== TEST 2: serial lock and unlock
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local locker = require "losty.lock"
            local key = "foo"
            for i = 1, 2 do
                local lock = locker("locks")
                local ok, err = lock.lock(key)
                ngx.say("lock: ", ok, " ", err)
                lock.unlock(key)
            end
        }
    }
--- request
GET /t
--- response_body
lock: true nil
lock: true nil

--- no_error_log
[error]



=== TEST 3: lock expired by itself
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local locker = require "losty.lock"
            local key = "blah"
            local t, err = ngx.thread.spawn(function()
                local lock = locker("locks")
                local ok, err = lock.lock(key, 1)
                ngx.say("sub thread: lock: ", ok, " ", err)
                ngx.sleep(2.1)
                ok, err = lock.lock(key, 1)
                ngx.say("sub thread: lock: ", ok, " ", err)
                ngx.sleep(1)
            end)

            local lock = locker("locks")
            local ok, err = lock.lock(key, 1)
            ngx.say("main thread: lock: ", ok, " ", err)
            ngx.sleep(1)
            ok, err = lock.lock(key, 1)
            ngx.say("main thread: lock: ", ok, " ", err)
        }
    }
--- request
GET /t
--- response_body
sub thread: lock: true nil
main thread: lock: false exists
main thread: lock: true nil
sub thread: lock: true nil

--- no_error_log
[error]

--- timeout: 4



=== TEST 4: lock on a nil key
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local locker = require "losty.lock"
            local lock = locker("locks")
            local ok, err = lock.lock()
            if ok then
                ngx.say("lock: ", ok, ", ", err)
                local ok, err = lock.unlock()
                if not ok then
                    ngx.say("failed to unlock: ", err)
                end
            else
                ngx.say("failed to lock: ", err)
            end
        }
    }
--- request
GET /t
--- response_body
failed to lock: nil key

--- no_error_log
[error]



=== TEST 5: same lock, multiple keys
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local locker = require "losty.lock"
            local lock1 = locker("locks")
            for i = 1, 3 do
                local ok, err = lock1.lock("key1")
                ngx.say("lock1: ", ok, " ", err)
                lock1.unlock("key1")
                collectgarbage("collect")
            end

            local lock2 = locker("locks")
            local lock3 = locker("locks")
            local ok, err = lock2.lock("key2")
            ngx.say("lock2: ", ok, " ", err)
            ok, err = lock3.lock("key3")
            ngx.say("lock3: ", ok, " ", err)
            collectgarbage("collect")

            lock2.unlock("key2")
            lock3.unlock("key3")
            collectgarbage("collect")
        }
    }
--- request
GET /t
--- response_body
lock1: true nil
lock1: true nil
lock1: true nil
lock2: true nil
lock3: true nil

--- no_error_log
[error]


