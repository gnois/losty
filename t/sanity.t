use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/?.lua;$pwd/t/?.lua;;";
    init_by_lua_block {
        require('losty.web')
    }
};

no_root_location();
run_tests();

__DATA__


=== TEST 1: preloadable
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        require('losty.web')
    }
}
--- request
GET /t
--- response_body:



=== TEST 2: not found by default
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local web = require('losty.web')
        web.run()
    }
}
--- request
GET /t
--- response_body: Not Found
--- error_code: 404



=== TEST 3: route is not location aware
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local web = require('losty.web')
        local r = web.route()
        r.get('/hi', function(_, res)
            res.status = 200
            return "hello world"
        end)
        web.run()
    }
}
--- pipelined_requests eval
["GET /t", "GET /t/hi"]
--- response_body eval
["Not Found", "Not Found"]
--- error_code eval
[404, 404]



=== TEST 4: make route location aware
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local web = require('losty.web')
        local w = web.route('/t')
        w.get('/hi', function(q, r)
            r.status = 200
            r.headers["content-type"] = "text/plain"
            return "Hello world"
        end)
        web.run()
    }
}
--- pipelined_requests eval
["GET /t", "GET /t/hi"]
--- response_body eval
["Not Found", "Hello world"]
--- error_code eval
[404, 200]




=== TEST 5: root path works, but need Content-Type
--- http_config eval: $::HttpConfig
--- config
location / {
    content_by_lua_block {
        local web = require('losty.web')
        local w = web.route()
        w.get('/', function(_, r)
            r.status = 200
            return "root"
        end)
        web.run()
    }
}
--- request
GET /
--- error_log
Content-Type header required
--- error_code: 500





=== TEST 6: preload routes
--- http_config
lua_package_path "$pwd/losty/?.lua;$pwd/t/?.lua;;";
init_by_lua_block {
    require('t.routes')
}
--- config
location / {
    content_by_lua_block {
        require('t.routes')()
    }
}
--- pipelined_requests eval
["GET /foo", "GET /bar"]
--- response_body eval
["Ho foo", "Ha bar"]
--- error_code eval
[200, 200]


