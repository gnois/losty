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


## Quickstart

Routes are registered once at init time, and requests are served per connection. nginx.conf therefore has two distinct blocks:

app.lau
```
var web = require('losty.web')                  -- line 1
var app = web.new('site')                       -- line 2
var w = app.route('/t')                         -- line 3
w.get('/hi', function(q, r)                     -- line 4
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
      require('app')                             -- register routes once, at init
   }
   server {
      listen 80;

      location / {
         content_by_lua_block {
            require('app').run()                 -- handle each request
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

Lines 1–4 in the Quickstart show the basic pattern: `require('losty.web')` returns a
`new(name)` factory, and each call returns an app with `get`/`post`/… verbs,
`route(prefix)` for grouping, and `run()`.

`route()` may be called multiple times, each taking an optional path prefix for grouping purpose. In the quickstart, `/t` is the prefix used to group route handlers under `/t/...` url.
If any combined prefix and path resolves to the same string, their associated handlers are accumulated (but still has to be explicitly invoked). For eg:

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

Visiting `/a/b` will get "No entry" with HTTP status 403. Notice that the extra `/` on line 4 is ignored.

After routes are established, `run()` must be called to start handling incoming requests.


### More than one app

An app is its own router. One app can serve `/` and another `/api/`, each with its own
routes, middleware and error handling.

Keep each app in its own module and return the app:

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
   return {items = {'a', 'b'}}                   -- table -> JSON
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
   require('app.site')                          -- register routes once, at init
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

Routes are written as full paths (`/api/items`), so nothing is stripped: nginx picks the
location, and the location picks the app. Two locations may share one app, and one
`init_by_lua_block` may load several apps. Creating an app with `web.new()` is safe at
any time; only *registering routes* must happen in the init phase.


### Routes definition

Routes are defined using HTTP methods, like `get()` for GET or `post()` for POST.

A route path begins with `/`, with segments separated by `/`. A trailing slash is
ignored.

A segment is either a literal, or a `{...}` token. Braces are not valid URL characters,
so they can never appear in a real request — everything inside them is route syntax:

| Segment    | Meaning |
|------------|---------|
| `users`    | literal: matches exactly `users` |
| `{id}`     | named capture, one segment (default pattern `[^/]+`) |
| `{id:%d+}` | named capture with an explicit Lua pattern |
| `{:%d+}`   | positional capture with an explicit Lua pattern |
| `{*}` / `{*rest}` | wildcard: the rest of the path (last segment only) |
| `{+}`      | prefix middleware (last segment only) |

Captures go into the `q.match` array. A named capture is also stored in `q.params`,
keyed by name:
```
/page/{id}        -- q.params.id
/page/{id:%d+}    -- q.params.id, digits only
/page/{:%w+}      -- q.match[1], %w+
/past/{:p(%a+)}   -- q.match = {'past', 'ast'}
```

A pattern cannot contain `/`, which is always a path separator. The whole segment is
captured, so an outermost `( )` around the pattern is redundant:
```
/page/{:(%d+)}    -- same as {:%d+}
```

`{*}` captures the rest of the path:
```
/files/{*path}    -- /files/a/b -> q.params.path = 'a/b'
```

`{+}` registers a handler for a path prefix, so it runs for every route under it and
falls through to the matched route. This is how prefix middleware is attached:
```
w.post('/api/{+}', csrf_guard)    -- runs for every POST under /api
w.post('/api/items', create_item) -- then this, if the path matches
```

Patterns are matched in order of declaration, and a literal segment always beats a
pattern. There is no optional last segment, to avoid conflicts:
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
Notice the last route receives multiple captures within a single segment.




### Handler

A handler is a function that takes a request (q), a response (r), and the continuation (`nxt`) as its third argument. Values passed to `nxt(...)` are appended to the arguments of every handler further down the chain.

`nxt` belongs to the current position in the chain, not to the request, so it is passed as an argument. A nested dispatch (for example inside `content.dual`) gets its own `nxt` and cannot disturb an outer one.

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
   db.insert("users(name) values (:?)", body.name)
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

For data that does not belong to a particular position in the chain, use the per-request facilities instead of adding arguments:

* `q.state` — a plain table for the current request, eg `q.state.user = u`, for cross-cutting values that many handlers need.
* `r.defer(fn, ...)` — register cleanup to run once the chain has returned, before the response is sent.

The third argument is named `nxt` rather than `next`, so that it does not shadow Lua's built-in `next()`, which handlers sometimes need for table traversal.

Other frameworks normally use a context table that is extended with keys and passed across handlers, but Losty passes them as cumulative function arguments by default, thanks to Lua variable argument and multiple return values. Here are some considerations for Losty's design.

* Arguments are easily visible.
* Arguments (un)packing is slower, but may not be significant if there are only a handful of handlers.
* Values that do not belong to a chain position go in `q.state`, which is per-request and does not need to be threaded through every signature.


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
| `q.match` | array of route captures (see [Routes definition](#routes-definition)) |
| `q.params` | key/value table of named captures, eg `q.params.id` |
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
   local r, err = db.insert("user (name, email) VALUES (:?, :?) RETURNING id", name, email)
   db.disconnect()
   return r and r.id, err
end
```

Note that db.connect() must be called inside a function (not at top level), else the error `cannot yield across C-call boundary` will occur.
db.disconnect() calls keepalive() under the hood, which puts the connection back to the connection pool and is considered a better practice than calling close().

The `:?` are placeholders, where `?` is a default modifier that converts Lua table and string to PostgreSQL JSON and quoted string respectively. The values in `name` and `email` will be interpolated into the placeholders, before sending to the database.

Other placeholder modifiers exist to customize the conversion from Lua to PostgreSQL data types:
For Lua table
* `:r`  [row constant type](https://www.postgresql.org/docs/11/rowtypes.html)
* `:a`  [arrays](https://www.postgresql.org/docs/11/arrays.html)
* `:h`  [hstore](https://www.postgresql.org/docs/11/hstore.html)
* `:?`  JSON

For Lua scalar value
* `:b`  bytea
* `:?`  escaped literal
* `:)` or `:]`  verbatim, only comments transformed, and semicolon and either `)` or `]` closing char stripped


Please refer to [pgmoon](https://github.com/leafo/pgmoon) or [lua-resty-mysql](https://github.com/openresty/lua-resty-mysql) documentation on interpreting query return values.




### Generating HTML

Unlike templating libraries that embed control flow inside HTML constructs, Losty goes the other way round by generating HTML with Lua, with full language features at your disposal. In Javascript, it is like JSX vs hyperscript on steroids, where the HTML tags become functions themselves, thanks to Lua function environment and its metatable again.

```
function tmpl(args)
   html({
      head({
         meta('[charset=UTF-8]')
         , title(args.title)
         , style({
            '.center { text-align: center; }'
         })
      })
      , body({
         div('.center', {
            h1(args.title)
         })
         , footer({
            hr()
            , div('.center', '&copy' .. args.copyright)
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
In fact, you could quote and use the 2nd string and the resulting HTML will be the same, as demonstrated in the style() tag in the example above. That means you can copy existing HTML code and quote it as Lua strings, and interleave with Losty HTML tag functions as needed.

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

Finally, to get your HTML string generated, call Losty `view()` function with your view template as first parameter, followed by the needed key/value table as argument.
A third boolean parameter prevents `<!DOCTYPE html>` being prepended to the result if truthy, and a fourth boolean parameter turns on assertion if an invalid HTML5 tag is used.


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
      local i = q.s1([[* from find_user(:?, :?)]], "belly@email.com", 'Passw0rd')
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

