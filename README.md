![](./assets/logo.png)

## Losty = [Lauzy](https://github.com/gnois/lauzy) + [OpenResty](http://openresty.org)

Losty is a functional style web framework for OpenResty with minimal dependencies.

By composing functions almost everywhere and utilizing Lua's powerful language features, it adds helpers on OpenResty without obscuring its API that you are familiar with.

It has
- request router
- request body parsers
- content negotiation
- cookie helpers
- flash helpers
- CSRF helpers
- encrypted session
- slug generation for url
- DSL for HTML generation
- validation and convertion helpers
- idempotent API helper
- Server Side Event (SSE) helper
- table, string and functional helpers
- SQL operation and seeding helpers
- SQL testing helpers
- simple scheduled job


Losty is written in [Lauzy](https://github.com/gnois/lauzy) and compiled to Lua.

Bug reports and contributions are very much welcomed and appreciated.



## Dependency

Required:
[OpenResty](http://openresty.org)

Optional:
- [pgmoon](https://github.com/leafo/pgmoon) if using PostgreSQL


## Installation

Use [opm](https://opm.openresty.org):
```
opm get gnois/losty
```

Or scaffold a complete, self-contained app with the bundled CLI — see [Quickstart](#quickstart).


## Quickstart

### Scaffold a new app

`bin/losty.lua` generates a complete app (routes, views, nginx config and run scripts) and bundles the framework under `lualib/losty`, so the app has no dependency on this repo at runtime:

```
luajit bin/losty.lua myapp -domain example.com        -- lauzy (default)
luajit bin/losty.lua myapp -lua -domain example.com   -- plain Lua
```

`-domain` sets `server_name`; it is prompted for if omitted.

The lauzy flavor (default) scaffolds `.lau` sources that must be compiled to `.lua` before the app can run, and recompiled after each edit — the CLI prints the exact `lau.zy` commands, one per file.
The `-lua` flavor is ready to run as generated.

```
cd myapp
./run.sh dev        # *nix: generate conf + start nginx
run dev             # Windows
```

Open <http://localhost:8080>. Stop or reload from another terminal:

```
./run.sh reload     # or: ./run.sh quit      (*nix)
run reload          # or: run quit           (Windows)
```

The generated layout:

```
myapp/
  app.lau              routes and handlers
  views/               HTML templates (home, auth, protected)
  _tmpl/               nginx.conf / www.conf / config.lua templates
  conf/                mime.conf, ssl.conf, certs/
  lualib/losty/        bundled framework
  run.sh, run.bat      dev | prod | reload | quit
```


### Minimal setup by hand

A minimal app is one module plus an nginx.conf.

app.lau
```
var web = require('losty.web')      -- line 1
var app = web.new('site')           -- line 2
var w = app.route('/t')             -- line 3
w.get('/hi', function(q, r)         -- line 4
   r.status = 200
   r.headers["content-type"] = "text/plain"
   return "Hi world"
end)
return app
```
nginx.conf
```
events {
   worker_connections 4096;
}
http {
   init_by_lua_block {
      require('app')                -- register routes once per worker
   }
   server {
      listen 80;

      location / {
         content_by_lua_block {
            require('app').run()    -- handle each request
         }
      }
   }
}
```

The result can be viewed by visiting `/t/hi`.

See [losty-starters](https://github.com/gnois/losty-starters) repo for more examples.


## Introduction

Losty can be used with `init_by_lua_block` and `content_by_lua_block` directives in OpenResty. Routes are registered once in `init_by_lua_block`, then each incoming request is handled by calling `run()` from `content_by_lua_block`. It matches HTTP requests to user defined routes, which associates one or more handler functions that process the request.
Similar to frameworks like Koajs, handlers need to be explicitly invoked downstream, and then control flows back upstream.

Lines 1–4 in the Quickstart show the basic pattern: `require('losty.web')` returns a `new(name)` factory, and each call returns an app with `get`/`post`/… verbs, `route(prefix)` for grouping, and `run()`.

`route()` may be called multiple times, each taking an optional path prefix for grouping purpose. In the quickstart, `/t` is a prefix used to group route handlers under `/t/...` url.
If any combined prefix and path resolves to the same string, their associated handlers are accumulated. For eg:

```
local app = require('losty.web').new('demo')
local w = app.route()
w.get('/a/b', function(q, r, nxt)
   r.status = 403
   return nxt()      -- explicitly invoke next handler if any
end)

local w = app.route('/a')
w.get('/b/', function(q, r) return "No entry" end)      -- line 4

```

Visiting `/a/b` will get "No entry" with HTTP status 403. Notice that the extra `/` in the path on line 4 is ignored.

After routes are established, `run()` must be called to start handling incoming requests.


### One app per nginx location

An app has its own router. We can use one app for all nginx locations, or one app can serve `/` and another `/api/`, each with its own routes, middleware and error handling. In this case, keep each app in its own module and return the app:

app.site.lau
```
var web = require('losty.web')
var app = web.new('site')                       -- the name is only for logs and errors

app.get('/', function(q, r)
   r.headers['Content-Type'] = 'text/plain'
   return 'Home'
end)

app.get('/about', function(q, r)
   r.headers['Content-Type'] = 'text/plain'
   return 'About'
end)
return app
```
app.api.lau
```
var web     = require('losty.web')
var content = require('losty.content')
var app     = web.new('api')

-- every POST under /api answers with JSON
app.post('/api/{+}', content.json)

app.get('/api/items', function(q, r)
   return {items = {'a', 'b'}}               -- table outputs as JSON
end)

app.post('/api/items', content.form, function(q, r, nxt, body)
   return {created = body.name}
end)
return app
```
Load both once at init, and run the right one per location:

nginx.conf
```
init_by_lua_block {
   require('app.site')                       -- register routes once, at init
   require('app.api')
}
server {
   listen 80;

   location /api/ {
      content_by_lua_block {
         require('app.api').run()
      }
   }
   location / {
      content_by_lua_block {
         require('app.site').run()
      }
   }
}
```
`require` caches, so each app is built once per worker and every request reuses it.

Routes are internally written as full paths (`/api/items`), so nothing is stripped: nginx picks the location, and the location picks the app. One `init_by_lua_block` may load several apps. Creating an app with `web.new()` is safe at any time; only *registering routes* must happen in the init phase.


### Routes definition

Routes are defined using HTTP methods, like `get()` for GET or `post()` for POST.

A route path begins with `/`, with segments separated by `/`. A trailing slash is ignored.

A segment is either a literal, or a `{...}` token. Braces are not valid URL characters,
so they can never appear in a real request — everything inside them is route syntax:

| Segment    | Meaning |
|------------|---------|
| `users`    | literal: matches exactly `users` |
| `{id}`     | named capture, one segment (default pattern `[^/]+`) |
| `{id:%d+}` | named capture with an explicit Lua pattern |
| `{:%d+}`   | positional capture with an explicit Lua pattern |
| `{*}` / `{*rest}` | wildcard: the rest of the path, ≥1 segment (last token only) |
| `{+}`      | prefix middleware (last token only) |

Because Lua table is versatile as both hash table and array, captures go into the single `q.match` table. A named segment is stored under its name; an unnamed (positional) segment is stored at an integer index:
```
/page/{id}        -- q.match.id
/page/{id:%d+}    -- q.match.id, digits only
/page/{:%w+}      -- q.match[1], %w+
/page/{:p(%a+)}   -- q.match = {'past', 'ast'}
```
A named segment's own pattern submatches still go to integer indices:
```
/page/{id:p(%a+)} -- /page/past -> q.match = {'ast', id = 'past'}
```
A name may appear at most once in a route; a duplicate is a registration error.

A pattern cannot contain `/`, which is always a path separator. The whole segment is captured, so an outermost `( )` around the pattern is redundant:
```
/page/{:(%d+)}    -- same as {:%d+}
```

`{*}` captures the rest of the path as a single string (e.g. `'a/b'`). A named wildcard is stored under its name, an unnamed one in the array:
```
/files/{*path}    -- /files/a/b -> q.match.path = 'a/b'
/files/{*}        -- /files/a/b -> q.match = {'a/b'}
```

`{+}` registers a handler for a path prefix, so it runs for every route under it and falls through to the matched route. This allows middlewares to be attached for all path matching the same prefix:
```
w.post('/api/{+}', csrf_guard)    -- runs for every POST under /api
w.post('/api/items', create_item) -- then this, if the path matches
```

Precedence is fixed, not dependent on registration order: a literal segment always
beats a pattern, and a pattern always beats a wildcard. Among patterns, the first
declared one that reaches a handler wins.

A named and an unnamed token are distinct even when their pattern text is identical:
`{id:%d+}` and `{:%d+}` are two separate routes, so their handlers do not
accumulate. If both can match the same URL, only the one declared first is used.

There is no optional last segment, to avoid conflicts:
```
  /page
  /page/{id}      -- not /page/{id?}
```
Specify both routes instead, with and without the optional segment.

The pattern does not allow `%c`, `%s`, or `/`.

For routes registered in this order:
```
1. /page/{:%a+}
2. /page/{:.*}
3. /page/{:%d+}
4. /page/near
5. /{:p(%a+)}/{:%d(%d)}
```
Requests below are matched:
```
/page/near  -> 4
/page/last  -> 1,  q.match = {'last'}
/page/:id   -> 2,  q.match = {':id'}
/page/123   -> 2 due to precedence, q.match = {'123'}
/past/56    -> 5,  q.match = {'past', 'ast', '56', '6'}
```
Notice the last route receives multiple captures within a single segment. More examples in `t/router-test.lua`.




### Handler

A handler is a function that takes a request (q), a response (r), and the continuation (`nxt`) as its third argument. Values passed to `nxt(...)` are appended to the arguments of every handler further down the chain.

Handlers declare only what they use, which gives three natural shapes:

```
-- leaf: the common case, ignores the continuation and the payload
w.get('/hi', function(q, r)
   r.status = 200
   r.headers['Content-Type'] = 'text/plain'
   return 'Hi world'
end)

-- middleware: continues the chain
w.get('/admin', require_user, function(q, r)
   ...
end)

-- payload tail: names the values earlier middleware passed down
w.post('/path', form, database, function(q, r, nxt, body, db)
   -- use body and db
   db.insert("users(name) values (!?)", body.name)
   r.status = 201
   return {ok = true}    -- dict table is auto-encoded to JSON
end)
```

Here is the built in `content.form` middleware, which declares `nxt` because it continues the chain and passes the parsed body to the handlers below it:
```
function form(q, r, nxt)
   local val, fail = body.buffered(q)
   local method = q.vars.request_method
   if val or method == "DELETE" then
      return nxt(val)
   end
   r.status = ngx.HTTP_BAD_REQUEST
   return {fail = fail or method .. " should have request body"}
end
```

`nxt(...)` **returns** the downstream handler's value, so a middleware can wrap it and release resources afterwards:
```
local pg = require('losty.sql.pg')

function database(q, r, nxt)
   local db = pg(databasename, username, password)
   db.connect()
   local out = nxt(db)
   db.disconnect()
   return out
end
```

Payload values are cumulative and positional: `form` appends `body`, then `database` appends `db`, so the tail declares `(q, r, nxt, body, db)`.

To continue the chain without adding a value, call `nxt()` with no arguments. The dispatcher holds the accumulated payload, so a pass-through middleware has nothing to forward. Writing `return nxt(...)` is almost always wrong as it re-appends the payload the handler was given and doubles it on every hop.

We can also use `q.state` — a plain table, eg `q.state.user = u`, for cross-cutting values that many handlers need for the current request.

If the response body is large, or may not be available all at once, we can return a function from the handler, and Losty will loop the function as iterator, returning its result in streaming fashion until its result is nil.


### Response body auto-detection

Handlers simply return a value — Losty infers how to send it:

| Return value | Behaviour |
|---|---|
| `string` or `number` | Sent as-is. Set `Content-Type` header yourself. |
| `function` | Called repeatedly as an iterator and streamed until it returns `nil`. |
| table | JSON-encoded, arrays and empty tables included. `Content-Type: application/json` set if not already present. |
| `nil` | No body. |

```
-- no json.encode() or Content-Type needed for a simple JSON endpoint
w.get('/api/status', function(q, r)
   r.status = 200
   return {ok = true, version = '1.0'}
end)
```

Because every table is JSON-encoded, an array such as `{'a', 'b'}` becomes the JSON `["a","b"]`, not the raw bytes `ab`. To stream a list of strings, return a function iterator instead.

For richer control — ETags, cache headers, content negotiation — use the `losty.content` middleware (`content.json`, `content.html`, `content.form`, `content.dual`). `content.json` and `content.html` set the response type (`content.html` also disables caching); the body itself is still encoded by the rules above.



### Request Table
Inside handlers, the passed in request table (q) is a thin wrapper for ngx.var and ngx.req, with a few route and proxy helpers.

| Field | What it is |
|---|---|
| `q.vars` | `ngx.var` — every nginx variable, eg `q.vars.request_method`, `q.vars.uri` |
| `q.headers` | request headers, case-insensitive: `q.headers['Content-Type']` |
| `q.cookies` | request cookies, URI-unescaped: `q.cookies.sid` |
| `q.args` | query string arguments: `q.args.page` for `?page=2` |
| `q.match` | route captures for this request (a fresh table): unnamed at integer indices, named under their name (see [Routes definition](#routes-definition)) |
| `q.state` | empty table, created fresh for each request |
| `q.request_id` | `X-Request-Id` header, else `$request_id`, else the userid cookie |
| `q.secure()` | true when the request is HTTPS |
| `q.client_ip(trusted)` | client address, honouring `Forwarded` / XFF from trusted proxies |
| `q.forwarded()` | parsed `Forwarded` header |
| `q.canonical_url(trusted)` | canonical public URL, from the forwarded details |

Anything else falls through to `ngx.req`, so `q.get_body_data()` and friends work too. With `userid on;` in nginx, `q.id`, `q.id_binary` and `q.id_base64` give the browser id.

`q.state` is the place for application data such as the signed-in user, eg `q.state.user = u`, instead of threading it through every handler signature.

### Response Table
Inside handlers, the passed in response table (r) sets the status, headers and cookies, and wraps `ngx.status`. Setting `ngx.status` directly also works as expected.

| Field | What it does |
|---|---|
| `r.status` | `ngx.status`; read or assign, eg `r.status = 201` |
| `r.headers[Name] = value` | set a header (appends to an existing one; `nil` or `{}` clears it) |
| `r.vary(name)` | add `name` to `Vary`, keeping the values already there |
| `r.nocache()` | no-store caching headers |
| `r.cache(status, sec)` | set the status and `Cache-Control: max-age=sec` |
| `r.redirect(url, same_method?)` | 303 to `url` (307 when `same_method` is true) |
| `r.cookie(name, httponly?, domain?, path?)` | create a cookie (see [Cookies](#cookies)) |
| `r.cookies` | read-only view of the cookies set on this response |
| `r.defer(fn, ...)` | run `fn` after the chain returns, before the response is sent (won't work after an `ngx.exec`/`ngx.exit` abort) |

```
r.status = 201
r.headers['Content-Type'] = 'application/json'
r.headers['X-Count'] = 3
assert(ngx.status == 201)
```

Assigning any other key stores it on `r` for the rest of the request, eg `r.user = u`.

`r.defer(fn, ...)` hooks run in LIFO order once the handler chain has returned, before the response is sent — even when a handler throws and the app answers 500. Use it to release resources opened by middleware.

#### Cookies

Cookies are created using the response table (r) in 2 steps:
```
local ck = r.cookie('biscuit', true, nil, '/')  -- step 1
local data = ck(nil, true, r.secure(), value) -- step 2
data.id = xxx
data.token = yyy
```

Step 1. `r.cookie` is called with a name, and optional httponly, domain and path. These 4 parameters make up the identity of a cookie, which is required for deletion.

Step 2. r.cookie returns a function, which must be called to specify age, samesite, secure and cookie value.
- The age can be nil, +ve or -ve number
  * +ve is the number of secs for the cookie to last
  * nil means the cookie will be deleted upon browser close
  * -ve means it will be deleted when the response is returned, and samesite, secure and value is not needed. eg: `ck(-100)`

Step 3. If age is not -ve, determine what to store in the cookie, either using the cookie value (4th parameter) above, or setting key/values in the returned `data` object. If the value is:
  * **omitted or nil** — if key/values are set on `data` , they will be JSON-encoded as the cookie value. If no keys are set, the cookie is an empty string.
  * **string** — used as-is; any keys set on `data` are ignored.
  * **function** — called with `data` as argument; use this for custom encoding or deferred evaluation.

For eg:

```
-- auto JSON: set keys on data after calling ck
local data = ck(3600, 'lax', true)
data.id = 123
data.role = 'admin'
-- cookie value becomes URI-escaped JSON: {"id":123,"role":"admin"}

-- explicit string value
ck(3600, 'lax', true, 'hello')

-- custom encoder
data = ck(3600, 'lax', true, json.encode)   -- same effect as auto JSON
data.id = 100
```
The cookie value is always URI-escaped before being sent.


### Session

Session is implemented via a pair of cookies, one bearing the encrypted data, which is httponly and the other bears its signature, which is javascript readable.
This allows javascript to detect cookie changes, and act accordingly without additional server round trip.

```
local session = require('losty.sess')
local sess = session('candy', "This IS secret", "this-is_key")

w.post('/login', function(q, r)
   local s = sess(q, r, 3600 * 24 * 7) -- age 7 days
   s.data = "userid"
   s.extra = {other = "info"}
   r.redirect('/')
end)
```
In the above example, there will be a cookie named 'candy' within document.cookie readable by javascript, holding the signature of this session cookie.
The actual encrypted data is stored in other cookie named 'candy_', which is httponly.
Both cookies is matched to ensure the session is not tampered with.



### Response completion and returning control to Nginx

Response headers including cookies and sessions are accumulated and finally set into `ngx.headers` before response is returned. Setting `ngx.headers` directly prior to returning response should also work as expected.

Use `r.defer(fn, ...)` to register cleanup callbacks in middleware. Deferred callbacks run in LIFO order after the handler chain returns and before the response is sent, even when a handler throws and Losty sets 500. Use this for releasing external resources.

Note that calling `ngx.exec()`, `ngx.redirect()`, `ngx.exit()`, `ngx.flush()`, `ngx.say()`, `ngx.print()` or `ngx.eof()` in a handler would terminate the Losty dispatcher flow including cleanup callbacks of `r.defer(fn, ...)` and return control to Nginx immediately. In such case, cookies may not be emitted and external resources like db connection might not be released. For example:

```
w.get('/download/{id}', function(q, r)
   local db = pg(...)
   db.connect()

   -- ngx.exec() aborts this handler: nothing after it runs, including the
   -- deferred callbacks, so release anything registered before handing over
   db.disconnect()
   return ngx.exec('/_protected/' .. q.match[1])
end)
```

It is recommended to always use `return` to be explicit that control is no longer in Losty. The example above use `return ngx.exec()` to internally redirect to another location. Another example is to `return ngx.exit(status)` to fall back to error_page directive in nginx.conf instead of using Losty generated error pages.



### CORS

The `losty.cors` middleware sets the cross-origin headers and answers preflight
requests. Create one configurator per route group with `cors.new()`, configure
it, then call it to get the handler:

```
local cors = require('losty.cors')
local c = cors.new()
c.host("example%.com")            -- "%.", not ".": this is a PCRE pattern
c.method("GET")
c.method("POST")
c.header("Content-Type")          -- allowed request headers (preflight)
c.expose_header("X-Total")        -- response headers js may read
c.max_age(3600)
c.credentials(true)               -- default true

fn = c()
w.options('/api/{*}', fn)      -- once per group: answers every preflight
w.get('/api/items', fn, list_items)
w.post('/api/items', fn, create_item)
```

For a normal request the handler sets the CORS headers and continues with
`nxt()`. For a preflight (an `OPTIONS` request carrying an `Origin`) it answers
**204** itself and does **not** continue, so no per-path OPTIONS route is needed.
When no `c.header()` list is configured, `Access-Control-Request-Headers` is
reflected and `Vary: Access-Control-Request-Headers` is added. A preflight from
an origin matching no `c.host()` is still answered 204, but without
`Access-Control-Allow-Origin`, so the browser blocks the actual request.

#### `{*}` or `{+}` for the OPTIONS route?

Use `{*}`:

* `{*}` is a terminal route leaf — it matches the rest of the path (one or more
  segments) and its handlers are the leaf. `w.options('/api/{*}', c())` gives
  the OPTIONS tree a leaf that any `/api/...` request resolves to, even when no
  OPTIONS route exists for that specific path. That is exactly the preflight case.
* `{+}` is prefix middleware, not a route. The router only collects a node's
  `{+}` handlers while resolving down to a matching **leaf of the same method**.
  With no OPTIONS leaf under `/api`, the OPTIONS tree has no leaf to reach, so
  `w.options('/api/{+}', c())` never runs for a preflight on a path that has
  only GET/POST routes.

Rule of thumb: use `{+}` only when a downstream route *of the same method* should
be wrapped; use `{*}` when the middleware is the handler-of-last-resort for a set
of paths.

Because `{*}` registers a real OPTIONS route, `OPTIONS` is now included in the
`Allow` header for other methods under `/api`. Note that `{*}` matches one or
more segments, so `OPTIONS /api` (bare, no trailing segment) does not match it —
preflights always target a concrete resource path.


### Secure headers

The `losty.security` middleware sets the hardening response headers. Build one
handler per group with `security.new()` and attach it to the routes:

```
local s = require('losty.security')
local sec = s.new()                -- all defaults
w.get('/page', sec, handler)
```

It sets (unless the response already carries the header):
`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`,
`X-Frame-Options: SAMEORIGIN`, `Permissions-Policy: geolocation=(), microphone=(), camera=()`,
`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Resource-Policy: same-site`,
`Origin-Agent-Cluster: ?1`, `X-DNS-Prefetch-Control: off`, `X-Download-Options: noopen`,
`X-Permitted-Cross-Domain-Policies: none` and `X-XSS-Protection: 0`. It also sets
`Strict-Transport-Security` over https, and removes `X-Powered-By`. Pass `false`
for an option to disable its header, or a string to override the default:

```
s.new({ x_frame_options = false, cross_origin_embedder_policy = "require-corp" })
```

#### Content-Security-Policy

`content_security_policy` is either a ready-made string or a policy built with
`s.csp{...}`, whose keys are directive names — snake_case or camelCase, both
accepted (`default_src`/`defaultSrc` -> `default-src`) — and whose values are a
string, an array of strings, or `true` for a valueless directive. Directives are
emitted sorted by name, so the header is stable:

```
local sec = s.new({
   content_security_policy = s.csp({
      default_src = "'self'"
      , script_src = { "'self'", s.nonce }
      , style_src = { "'self'", s.nonce }
      , img_src = { "'self'", "data:" }
      , upgrade_insecure_requests = true
   })
})
```

Put the `s.nonce` sentinel in a directive and the middleware generates a fresh
nonce for each request, writes it into the header as `'nonce-<random>'` and
exposes the raw value as `q.state.nonce`, so the handler can pass it to the view
that renders the matching tags:

```
w.get('/page', sec, function(q, r)
   r.headers['Content-Type'] = 'text/html'
   return '<!DOCTYPE html>' .. view(tmpl, { nonce = q.state.nonce })
end)

-- in the template:
script({ nonce = args.nonce, src = '/app.js' }, '')
```

Reporting is supported too: `reporting_endpoints = { { name = "csp", url = ... } }`
renders `Reporting-Endpoints`, and
`report_to = { { group = "csp", max_age = 10886400, endpoints = { { url = ... } } } }`
renders `Report-To`.


### SQL Operations

Losty provides wrappers for MySQL and PostgreSQL drivers and a basic migration utility. There is no ORM layer. (It's much more worthwhile to just learn SQL)

As an example, suppose we want to use an existing PostgreSQL database.
Lets create a new table with SQL file:

users.sql
```
CREATE TABLE user (
   id serial PRIMARY KEY
   , name text NOT NULL
   , email text NOT NULL
);
```
And another table with a Lua file:

friends.lua
```
return {
   "CREATE TABLE friend (
      id int NOT NULL REFERENCES users
      , userid int NOT NULL REFERENCES users
      , UNIQUE (id, userid)
   );"
}
```

We can then migrate the tables into PostgreSQL using [`resty cli`](https://github.com/openresty/resty-cli) as below:
```
resty -I ../ -e 'require("losty.sql.migrate")(require("losty.sql.pg")("dbname", "user", "password", host, port))' users.sql friends
```

The database server host and port are optional, and defaults to '127.0.0.1' and 5432 respectively.
Losty migration accepts both SQL and Lua source files, and a .lua file extension is optional.

A Lua source should return an array of strings, which are SQL commands. Each array item is sent to the database server in separate batch. This means we can programatically generate SQL with Lua.

An SQL file uses `----` as batch separator. Separating SQL commands into batches are helpful in case an error occurs, without which it's harder to locate the line of error.

Lets create a function to insert a user:

user.lua
```
local db = require("losty.sql.pg")("dbname", "user", "password")

function insert(name, email)
   db.connect()
   local r, err = db.insert("user (name, email) VALUES (!?, !?) RETURNING id", name, email)
   db.disconnect()
   return r and r.id, err
end
```

Note that db.connect() must be called inside a function (not at top level), else the error `cannot yield across C-call boundary` will occur.
db.disconnect() calls keepalive() under the hood, which puts the connection back to the connection pool and is considered a better practice than calling close().

The `!?` are placeholders, where `?` is a default modifier that converts Lua table and string to PostgreSQL JSON and quoted string respectively. The values in `name` and `email` will be interpolated into the placeholders, before sending to the database. Placeholders are only recognized in SQL code, never inside string literals or comments (so a value like `'wow!bar'` is left alone), and `::type` casts are plain SQL.

Other placeholder modifiers exist to customize the conversion from Lua to PostgreSQL data types:
For Lua table
* `!r`  [row constant type](https://www.postgresql.org/docs/11/rowtypes.html)
* `!a`  [arrays](https://www.postgresql.org/docs/11/arrays.html)
* `!h`  [hstore](https://www.postgresql.org/docs/11/hstore.html)
* `!?`  JSON

For Lua scalar value
* `!b`  bytea
* `!?`  escaped literal
* `!i`  quoted identifier

To splice a verbatim SQL fragment (eg. an expression), wrap it with `db.raw()` and pass it as a `!?` placeholder, eg. `db.select("... WHERE created_at > !?", db.raw("now() - interval '1 day'"))`. Only tables produced by `db.raw()` are accepted, so untrusted input can never reach the raw path; comments are transformed and `;` is stripped.


Please refer to [pgmoon](https://github.com/leafo/pgmoon) or [lua-resty-mysql](https://github.com/openresty/lua-resty-mysql) documentation on interpreting query return values.




### Generating HTML

Unlike templating libraries that embed control flow inside HTML constructs, Losty goes the other way round by generating HTML with Lua, with full language features at your disposal. In Javascript, it is like JSX vs hyperscript on steroids, where the HTML tags become functions themselves, thanks to Lua function environment and its metatable again.

```
function tmpl(args)
   html({
      head({
         meta('[charset=UTF-8]')
         , title(args.title)
         , style(raw('.center { text-align: center; }'))
      })
      , body({
         div('.center', {
            h1(args.title)
         })
         , footer({
            hr()
            , div('.center', raw('&copy'), args.copyright)
         })
      })
   })
end

local view = require('losty.view')
local output = view(tmpl, {title='Sample', copyright='company'})

```

HTML generation starts with a view template function that may take an argument, which should be a key/value table. It should return a string or an array of strings.

For example, within a view template function,
```
img({src='/a.png', alt='A'})
```
returns this string
```
<img alt="A" src="/a.png">
```
Text and attribute values are html-escaped (`&`, `<`, `>`, and inside attributes the quotes as well), so a quoted string is never treated as markup: `div("<b>hi</b>")` renders `&lt;b&gt;hi&lt;/b&gt;`. To pass markup, entities or script/style bodies through verbatim, wrap them in `raw()`, which is emitted unescaped:
```
raw('<b>hi</b>')
raw('&copy')
raw('.center { text-align: center; }')
```
Never pass untrusted input to `raw()`; it is the one place where injection is possible.

As you know there are void and normal HTML elements. Void elements such as `<br>`, `<hr>`, `<img>`, `<link>` etc cannot have children element, while normal elements like `<div>`, `<p>` can.
So the below gives errors because `hr()` cannot have children.
```
hr(hr())
hr({div(), span()})
```
While this works
```
div("foo")
div(".foo", '')
div("#id1.foo", '')
div("[class=foo][title=bar]", {})
```
Here is the result
```
<div>foo</div>
<div class="foo"></div>
<div class="foo" id="id1"></div>
<div class="foo" title="bar"></div>
```

Notice that if two or more arguments are given, and if the first argument is a string or a key/value table, then it is treated as attribute. Using string as attribute requires special syntax. They can each be listed in square brackets, or preceded with dot to indicate classname, or hash to indicate id, as seen above.


This works as expected, without attributes
```
p(h1("blog"))
nav(span('z'), span(1), span(false))
ul({li("item1"), li("item2")})
strong(nil, "Home")
```
Gives
```
<p><h1>blog</h1></p>
<nav><span>z</span><span>1</span><span>false</span></nav>
<ul><li>item1</li><li>item2</li></ul>
<strong>Home</strong>
```

Generally, Losty view templates are shorter than its HTML counterpart.

Unfortunately the `<table>` tag and the table library in Lua have the same name. Hence, functions like `table.remove()`, `table.insert()` and `table.concat()` are exposed as just `remove()`, `insert()` and `concat()` without qualifying with the name `table`.

Attributes are emitted in name order, so the same node always renders to the same bytes.

Inside a template only a fixed set of globals is reachable: `assert`, `error`, `getmetatable`, `ipairs`, `math`, `next`, `pairs`, `pcall`, `print`, `rawequal`, `rawget`, `rawset`, `setmetatable`, `string`, `table`, `tonumber`, `tostring`, `type`, `unpack`, `xpcall`, plus the html-facing `concat`, `insert`, `remove` and `raw`. `_G`, `os`, `io`, `require`, `load`, `dofile`, `debug` and `package` are deliberately unreachable, so a template cannot execute commands or touch the filesystem. A template must also not suspend mid-render: `view()` swaps the function's environment in place and restores it afterwards.

Finally, to get your HTML string generated, call Losty `view()` function with your view template as first parameter, followed by the needed key/value table as argument. It returns the html body only, so prepend `<!DOCTYPE html>` yourself if you need it.
An optional third boolean parameter turns on assertion that every tag is a known HTML5 element, which catches a typo like `dvi()` at render time instead of silently emitting `<dvi>`.


### (SQL) testing or seeding helpers

Losty has a simple unit testing helper for exercising your SQL or Lua functionalities.

```
local setup = require('losty.test')
local pg = require('losty.sql.pg')

local sql = pg(databasename, username, password, true)

-- the 1st parameter `sql` can be nil if we are not testing database operations
setup(sql, function(test, a, p, q)
   -- test is a function that tests some assertions
   -- a is an assert function
   -- p is a printing function
   -- q holds a table of functions for sql query (optional)

   p('user test')
   q.begin()  -- optional

   local uid
   test("can create user", function()
      local u = user.add(q, "belly@email.com", 'Passw0rd')
      a(u and u.user_id, u)  -- assert
      uid = u.user_id
   end, true) -- true means commit a savepoint to database, until end of parent scope, which then decide whether to commit or rollback the whole setup

   test("can match user", function()
      local i = q.s1([[* from find_user(!?, !?)]], "belly@email.com", 'Passw0rd')
      a(i and i.user_id == uid, i)
   end)

   q.rollback() -- use q.commit() if seeding database
end)

```
When run using `resty cli`, the test above produces summary of tests passed/failed.

To seed the database, omit the q.begin() and q.rollback() statements, and pass `true` as the last argument to test()




### Validation Helpers

Losty has builtin test functions in `losty.is`, to perform validation checks on a variable. Some of them takes addition arguments:
```
local is = require('losty.is')

is.null
is.nonull
is.tbl
is.num
is.str
is.bool
is.func1
is.array(fn)  -- fn can be is.str/is.num/is.bool etc to check if is an array only contains strings or numbers or booleans
is.len(min, max)  -- check minimum and maximum length of string
is.email
is.date
is.has(pattern)      -- calls string.find with the given pattern
is.match(pattern)    -- calls string.match with the given pattern
is.min(n)
is.max(n)
is.int

```


Using `losty.check`, We can also chain these test functions together to perform multiple validations and returns cumulative error messages on failure. For eg:

```
local c = require('losty.check')
local is = require('losty.is')

local text = 'helo'
local o, errs = c.check(is.nonull, is.str, is.has('%s', 'space'), is.atleast(10))(text)
if not o then
   print(o, c.message('text', errs))
end

```

The output error message is cumulative of the failed test functions, if they are called.
```
false   text should have space and be at least 10 characters
```

By following simple convention, we can write custom test function that can work like the builtins. For eg, testing for non nil:
```
local nonull = function(t)
   if t ~= nil or t ~= ngx.null then
      return true
   end
   return nil, "not be null"
end
```
If the test succeeds, we simply returns true, and the next test in the chain (if any) will be called.

But if the test fails and the next test should not be allowed, return nil to terminate the chain. Here we return nil because it does not make sense to continue testing a nil variable.
To continue testing, we can return false.
For failures, the 2nd return value must be an error message, which will be auto prepended with the word 'should' by the `losty.check.message()` function.



### Simple scheduled job

A job can be scheduled to run at a point of time in future on one worker using `losty.schedule`. It can optionally be run periodically after that point of time.
The scheduler is only one function with signature

`function (worker, cycle, ndays, hh, mm, ss, job, ...)`, where `job` is a function that is repeatedly called with the given varargs to perform actual processing.

- worker: ordinal num of worker to run the job on, between 0 .. ngx.worker.count()-1, via nginx.conf worker_processes directive
- cycle: repeat every `cycle` seconds - 0 or nil means non repeating job
- ndays: days from now to start the job running - 0 means next coming time at hh:min:ss
- hh, mm, ss: the first time to invoke the job at, after which the job may be repeated every `cycle` secs


Suppose we would like to cleanup expired data daily at around 11.58pm where user activity is low, starting 7 days later after nginx is brought up, we would schedule the job via `init_worker_by_lua_*` below:


clean.lua
```
-- only one can run
local running

function clean(...)
   if not running then
      running = true
      local db = sql()
      db.connect()
       -- do cleanup
      db.disconnect()
      running = nil
   end
end

local schedule = require('losty.schedule')
schedule(worker, 24*60*60, 7, 23, 58, 0, clean)

```

nginx.conf
```
init_worker_by_lua_block {
   require("clean")
}

```







### Credits

This project has taken ideas and codes from respectable projects such as Lapis, Mashape router, lua-resty-session, and helpful examples from OpenResty and around the web.

Of course it wouldn't exist without the magnificent OpenResty in the first place.

