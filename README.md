Losty = [*L*uaty](https://github.com/gnois/luaty) + [*O*penRe*sty*](http://openresty.org)

Losty is a practically simple web framework running atop OpenResty with minimal dependencies.

It is similar with middleware based frameworks like Sinatra or Koa.js, but using Lua specific features and includes opinionated batteries, such as:

- DSL for HTML generation
- request router
- request body parsers
- content-negotiation
- cookie and session handlers
- slug generation for url
- Server Side Event (SSE) support
- SQL operation helpers
- input validation helpers
- table, string and functional helpers



Dependency
------
[OpenResty](http://openresty.org)

Optional:
- [Luaty](https://github.com/gnois/luaty) to compile to Lua
- [pgmoon](https://github.com/leafo/pgmoon) if using PostgreSQL (for MySQL, OpenResty comes built in with lua-resty-mysql)


Usage
-----

1. Clone this repo as losty/
2. Create nginx.conf and app.lt under yourapp/ folder, which is at the same level as losty/:

```
yourapp/
  |-- nginx.conf
  |-- app.lt
  |-- ...
  |-- static/
     |-- 404.html
     |-- 5xx.html
     |-- robots.txt
     |-- xx.css
     |-- xx.js
```

app.lt
```
require('resty.core')
collectgarbage("collect")

var web = require('losty.web')
var view = require('losty.view')

var server = web()
var w = server.route()

var template = ->
	return html({
		head({
			meta('[charset=UTF-8]')
			, title(args.title)
			, style({'.center { text-align: center; }'})
		})
		, body({
			div('.center', {
				h1(args.title)
				, div(args.message)
			})
			, footer({
				hr()
				, div('.center', '&copy' .. args.copyright)
			})
		})
	})

var page = \args ->
	args.copyright = 'My website'
	return view(template, args)

var not_found = page({
	title = '404 Not Found'
	, message = 'Nothing here'
})

w.get('/', \req, res->
	res.ok(page({
		title = 'Hi'
		, message = 'Losty is live!'
	}))
)

-- list of custom error pages
var errors = {
	[404] = not_found()
}

return ->
	server.run(errors)
```


nginx.conf
```
http {

	lua_package_path ";;../?.lua;";  # losty is one level up
	lua_code_cache on;  # turn off in development
	
	# take advantage of lua_code_cache
	init_by_lua_block {
		require("app")
	}

	server {
		listen 80;
		listen [::]:80;
		server_name domain.com;

		access_log off;
		
		root static/;
		error_page 404 404.html;
		error_page 500 501 502 503 5xx.html;

		location = /robots.txt {
			root static;
		}

		# dynamic content
		location / {
			access_log on;
			access_by_lua_block {
				local ua = ngx.req.get_headers()['User-Agent']
				if not ua or ua == ''
					return ngx.exit(ngx.HTTP_FORBIDDEN)
			}
			content_by_lua_block {
				require("app")()
			}
		}
	}
}
```

3. Compile your app.lt to Lua and start nginx with prefix as yourapp/ folder
```
 > cd yourapp/
 > luaty app.lt app.lua
 > nginx -p . -c nginx.conf
```


General Idea
-------

Losty is assumed to run under content_by_lua directive. 
Its route handlers are functions taking request and response object.

Response headers, status and body are buffered using
```
res.headers[Name] = value
res.body = 'body'
res.status = 200
```
and finally set into ngx.headers, ngx.status and calling ngx.print(body) and ngx.eof() AFTER the last handler.

This means that code below will not produce desired effect because ngx.say or ngx.print is not yet being called:
```
res.body = 'Hello world'
ngx.flush()
ngx.eof() 
```
The recommended way is simply not calling ngx.flush and ngx.eof, unless you want to short circuit Losty dispatcher and return control to nginx immediately. In such case, you may also use `return ngx.exit(status)`. This is useful for example to use error_page directive instead of using Losty generated error page.



Handlers
--------
Losty handlers are functions having the general structure below:

```
\req, res, w, x, ... ->
	if ok
		req.next(y, z)
	else
		res.status = 400
		-- skip the following handlers
```	
Handlers can be chained, and values passed to req.next() will appear as function arguments in the following handlers, as w, x in the above example. 



For example, here is a handler for http POST, PUT or DELETE request:
```
var form = \req, res ->
	var val, fail = body.buffered(req)
	if val or req.method == 'DELETE'
		return req.next(val)
	res.status = 400 -- bad request
	return { fail = fail or req.method .. " should have request body" }
```

Here is another handler to open a database connection, and pass on the connection, then returning the return value of the next handler after closing the connection.
```
var pg = require('losty.sql.pg')

var database = \req, res ->
	var db = pg(databasename, username, password)
	db.connect()
	var out = req.next(db)
	db.disconnect()
	return out
```

The above handlers can be used like this:

```
w.post('/path', \_, res ->
	res.headers["Content-Type"] = "application/json"
	req.next()

, form, database, \req, res, body, db ->
	-- use body and db here
	db.insert(...)
	res.status = 201
)
```
Notice how handlers are chained, and the body and db are accumulated and passed as arguments to the following handlers.

Other frameworks normally use a context table that get extended with keys and passed around to handlers, but Losty passes them as function arguments.
There are pros and cons to this design:

* Pros:
Arguments are easily visible. Handlers are sometimes copied or moved around, and listing arguments deliberately reduces mistakes.
Argument never gets overwritten accidentally. On the contrary, extending context table need to be careful not to reuse the same key.
Switching to a context table is easy. Just append keys to the req or res table. Or use req.next(ctx) in the first handler and in the following handlers, extend ctx and call req.next() without argument.

* Cons:
Arguments (un)packing is slower. But handlers are probably not too many to make the slowness significant.

* Renaming keys in context table is errorprone. All following handlers have to be changed. For Losty, the position of the arguments need to be followed when moving handlers around.



SQL Operations
---------
Losty provides wrappers for MySQL and PostgreSQL drivers and a basic migration utility. There is no ORM layer, because no ORM is able to fully abstract the flexibility of SQL.

As an example, suppose we want to use an existing PostgreSQL database.
Lets create a new table with SQL file:

users.sql
```
CREATE TABLE user (
	id serial PRIMARY KEY
	, name text NOT NULL
	, email text NOT NULL
)
```
Lets create another table using Luaty:

friends.lt
```
return {
	`CREATE TABLE friend (
		id int NOT NULL REFERENCES users
		, userid int NOT NULL REFERENCES users
		, UNIQUE (id, userid)
	)`
}
```

We can then migrate the tables into PostgreSQL using `resty` below:
```
resty -I ../ -e 'require("losty.sql.migrate")(require("losty.sql.pg")("dbname", "user", "password", host, port))' users.sql friends
```

The database server host and port are optional, and defaults to '127.0.0.1' and 5432 respectively.
Losty migration accepts both SQL and Lua source files. 
A Lua source file extension is optional, and should return an array of strings, which are SQL commands. This allows us to generate SQL using Lua variables and code. Each array item is sent to the database server in a separate batch.
An SQL file uses `----` as batch separator. Separating SQL commands into batches are helpful in case an error occurs, without which it's harder to locate the line of error.

Lets create a function to insert a user:

user.lt
```
var db = require("losty.sql.pg")("dbname", "user", "password")

var insert = \name, email ->
	db.connect()
	var r, err = db.insert("user (name, email) VALUES (?, ?) RETURNING id", name, email)
	db.disconnect()
	return r and r.id, err
```

Note that db.connect() must be called inside a function (not at top level), else the error `cannot yield across C-call boundary` will occur.
Calling disconnect() will keep the connection back to the connection pool and is considered a better practice than calling close() which releases the connection.

The input values `name` and `email` are properly escaped and interpolated into the SQL statement, before sending to the database, and the result is accessible from the first return value object if it succeeds, or the second string if failed. Please refer to pgmoon or lua-resty-mysql documentation on the full explanation of return values.




Credits
-------
This project has stolen ideas and codes from respectable projects such as Lapis, Kong router, lua-resty-* from Bungle, and helpful examples from OpenResty and around the web.
Of course it wouldn't exist without the magnificent OpenResty in the first place.

