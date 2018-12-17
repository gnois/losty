Losty = [**_L_**uaty](https://github.com/gnois/luaty) + [**_O_**penResty](http://openresty.org)

Losty is a practical web framework running atop OpenResty with minimal dependencies.

Putting functions first and foremost, Losty is similar to middleware based frameworks like Koa.js, but comes included with opinionated batteries, such as:

- DSL for HTML generation
- request router
- request body parsers
- content-negotiation
- cookie and session handlers
- slug generation for url
- Server side event (SSE) support
- SQL query and migration helpers
- input validation helpers
- table, string and functional helpers



Installation
------------
```
$ opm get gnois/losty
```

Dependency: [OpenResty](http://openresty.org)

Optional:
- [Luaty](https://github.com/gnois/luaty) to compile to Lua
- [pgmoon](https://github.com/leafo/pgmoon) if using PostgreSQL (for MySQL, OpenResty comes with lua-resty-mysql)



Usage
-----

Create nginx.conf and app.lt under yourapp folder:
```
yourapp/
  |-- nginx.conf
  |-- app.lt
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

-- custom error pages
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
	lua_code_cache off;  # turn on in production
	
	init_by_lua_block {
		require("app")
	}

	server {
		listen 80;
		listen [::]:80;
		server_name domain.com;

		access_log off;
		
		error_page 404 /404.html;
		error_page 500 /5xx.html;
		
		# static files shd not need /prefix, bcoz google check existance of /file.html to verify domain ownership
		# Eg:
		# /file.css
		# /7890322/file.js
		# /404.html
		root public;
		location ~ ^/.+\.(html|txt|js|css|ico)$ {
			expires 1y;
			location ~ ^/\d+/(.+)$ {
				# for busting browser cache
				try_files /$1 =404;
			}
		}

		# dynamic content
		location / {
			userid on;
			userid_name id;
			userid_path /;
			userid_mark Y;
			userid_expires max;
			etag off;
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

Finally, start nginx with prefix in yourapp/ folder
```
 > cd yourapp
 > luaty app.lt app.lua
 > nginx -p . -c nginx.conf
```


Credits
-------
This project has stolen ideas and codes from respectable projects such as Lapis, Kong router, lua-resty-* from Bungle, and helpful examples from OpenResty and around the web.
Of course it wouldn't exist without the magnificent OpenResty in the first place.
