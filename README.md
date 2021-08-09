![](./assets/logo.png)

## Losty = [Luaty](https://github.com/gnois/luaty) + [OpenResty](http://openresty.org)

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
- input validation helpers
- idempotent API helper
- Server Side Event (SSE) helper
- table, string and functional helpers
- SQL operation and seeding helpers
- SQL testing helpers


Losty is written in [Luaty](https://github.com/gnois/luaty) and compiled to Lua.

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

nginx.conf
```
events {
   worker_connections 4096;
}
http {
   server {
      listen 80;

      location / {
         content_by_lua_block {
            local web = require('losty.web')()      -- line 1
            local w = web.route('/t')               -- line 2
            w.get('/hi', function(q, r)             -- line 3
               r.status = 200
               r.headers["content-type"] = "text/plain"
               return "Hi world"
            end)
            web.run()
         }
      }
   }
}
```

The result can be viewed by visiting `/t/hi`.

See [losty-starters](https://github.com/gnois/losty-starters) repo for more examples.


## Introduction

Losty can be used in content_by_lua* directive in OpenResty. It matches HTTP requests to user defined routes, which associates one or more handler functions that process the request.
Similar to frameworks like Koajs, handlers need to be explicitly invoked downstream, and then control flows back upstream.

line 1, 2 and 3 in the Quickstart is the basic pattern to setup route handlers within a content_by_lua* block.
Line 1 returns a simple key/value table having only 2 functions, `route()` and `run()`.

`route()` may be called multiple times, each taking an optional path prefix for grouping purpose. In the quickstart, `/t` is the prefix used to group route handlers under `/t/...` url.
If any combined prefix and path resolves to the same string, their associated handlers are accumulated (but still has to be explicitly invoked). For eg:

```
local web = require('losty.web')()
local w = web.route()
w.get('/a/b', function(q, r)
   r.status = 403
   return q.next()      -- explicitly invoke next handler if any
end)

local w = web.route('/a')
w.get('/b/', function(q, r) return "No entry" end)      -- line 4

```

Visiting `/a/b` will get "No entry" with HTTP status 403. Notice that the extra `/` on line 4 is ignored.

After routes are established, `run()` must be called to start handling incoming requests.


### Routes definition

Routes are defined using HTTP methods, like get() for GET or post() for POST.

Route paths are strings that begins with '/', followed by multiple segments separated by '/' as well. A trailing slash is ignored.

A segment that begins with : specifies a capturing lua pattern. Captured values are stored in `match` array of request table (q).

There is no named capture like in other frameworks, due to possible conflicting paths like:
```
  /page/:id
  /page/:user
```
where :user may never be matched, causing `q.match['user']` to be always nil.

Hence, q.match is not a keyed table, but an array instead, which also enables multiple captures within one segment.
eg:
```
/page/:%w-(%d)-(%d)
```

There is no way to specify an optional last segment, to avoid possible conflicts:
```
  /page/:?  <- not valid
  /page
```
Specify both routes instead, with and without the optional segment.

The match pattern does not allow `%c, %s`, and obviously `/`, which is always a path separator.

For routes registered in specified order below:
```
1. /page/:%a+
2. /page/:.*
3. /page/:%d+
4. /page/near
5. /:p(%a+)/:%d(%d)
```
Requests below are matched.
```
/page/near  -> 4
/page/last  -> 1,  q.match = {'last'}
/page/:id   -> 2,  q.match = {':id'}
/page/123   -> 2 due to precedence, q.match = {'123'}
/past/56    -> 5,  q.match = {'past', 'ast', '56', '6'}
```
Notice the last route receives multiple captures within a single segment.

Path matching is deterministic. They are matched in order of declaration, and non-pattern path gets a higher precedence.




### Handler

A handler is a function that takes a request (q) and a response (r) table, and optionally more arguments which may be passed from previous handlers.

Here is a handler for http POST, PUT or DELETE request, taken from the built in content.lua helper:
```
function form(q, r)
   local val, fail = body.buffered(q)
   local method = q.vars.request_method
   if val or method == "DELETE" then
      return q.next(val)
   end
   r.status = ngx.HTTP_BAD_REQUEST
   return {fail = fail or method .. " should have request body"}
end
```
When a route is matched with the requested URL, Losty dispatcher invokes the first handler, which may call the next handler with q.next() passing more arguments, like `val` in the above example, or simply return a response body.


Here is another handler that opens a postgresql database connection and passes it to the next handler, then keepalives the connection and returns the received result.
```
local pg = require('losty.sql.pg')

function database(q, r)
   local db = pg(databasename, username, password)
   db.connect()
   local out = q.next(db)
   db.disconnect()
   return out
end
```

The above handlers can be chained like this:

```
w.post('/path', function(q, r)
   r.headers["Content-Type"] = "application/json"
   return q.next()
end, form, database, function(q, r, body, db)
   -- use body and db
   db.insert("users(name) values (:?)", body.name)
   r.status = 201
   return json.encode({ok = true})
end)
```
Notice how the form `body` and `db` are appended and passed as arguments to the following handlers, and the last handler returns JSON as response body.

Other frameworks normally use a context table that is extended with keys and passed across handlers, but Losty passes them as cumulative function arguments by default, thanks to Lua variable argument and multiple return values. Here are some considerations for Losty's design.

* Arguments are easily visible.
* Arguments (un)packing is slower, but may not be significant if there are only a handful of handlers.
* Switching to a context table is easy for Losty; just append keys to the request (q) or response (r) table. But the reverse is not.


If the response body is large, or may not be available all at once, we can return a function from the handler, and Losty will loop the function as iterator, returning its result in streaming fashion until its result is nil.



### Request Table
Inside handlers, the passed in request table (q) is a thin wrapper for ngx.var and ngx.req, from which all properties are accessible.


### Response Table
Inside handlers, the passed in response table (r) is a thin helper used to set HTTP headers and cookies, and wraps `ngx.status`. Setting `ngx.status` directly also works as expected.

```
r.headers[Name] = value
r.status = 201
assert(ngx.status == 201)
```

#### Cookies

Cookies are created using the response table (r) in 2 steps:
```
local ck = r.cookie('biscuit', true, nil, '/')  -- step 1
local data = ck(nil, true, r.secure(), value) -- step 2
data.id = xxx
data.token = yyy
```

Step 1. r.cookie is called with a name, and optional httponly, domain and path. These 4 parameters make up the identity of a cookie, which is required for deletion.

Step 2. r.cookie returns a function, which must be called to specify age, samesite, secure and cookie value.
- The age can be nil, +ve or -ve number
  * +ve is the number of secs for the cookie to last
  * nil means the cookie will be deleted upon browser close
  * -ve means it will be deleted when the response is returned, and samesite, secure and value is not needed. eg:  ck(-100)

- If the age not a -ve number, the cookie value can be specified as either:
  * a simple string, treated as is
  * an encoding function, such as json.encode(), which encodes the cookie as key/value object, as seen in `data` above



### Session

Session is implemented via a pair of cookies, one bearing the encrypted data, which is httponly and the other bears its signature, which is javascript readable.
This allows javascript to detect cookie changes, and act accordingly without additional server round trip.

```
var session = require('losty.sess')
var sess = session('candy', "This IS secret", "this-is_key")

w.post('/login', function(q, r)
   r.headers["Content-Type"] = "application/json"
   var s = sess(q, r, 3600 * 24 * 7) -- age 7 days
   s.data = "userid"
   s.extra = {other = "info"}
   r.redirect('/')
)
```
In the above example, there will be a cookie named 'candy' within document.cookie readable by javascript, holding the signature of this session cookie.
The actual encrypted data is stored in other cookie named 'candy_', which is httponly.
Both cookies is matched to ensure the session is not tampered with.



### Response completion and returning control to Nginx

Response headers including cookies and sessions are accumulated and finally set into `ngx.headers` before response is returned.
Setting `ngx.headers` directly prior to returning response should also work as expected.

Note that calling `ngx.exec()`, `ngx.redirect()`, `ngx.exit()`, `ngx.flush()`, `ngx.say()`, `ngx.print()` or `ngx.eof()` in a handler would short circuit the Losty dispatcher flow and return control to Nginx immediately. A valid example would be to use `return ngx.exit(status)` to fall back to error_page directive in nginx.conf instead of using Losty generated error pages.




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



### Credits

This project has taken ideas and codes from respectable projects such as Lapis, Mashape router, lua-resty-session, and helpful examples from OpenResty and around the web.

Of course it wouldn't exist without the magnificent OpenResty in the first place.

