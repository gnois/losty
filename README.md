*Losty* is a modern and practical web framework running atop OpenResty with minimal dependencies.

Putting functions first and foremost, *Losty* is similar to middleware based frameworks like Koa.js, but comes included with opinionated batteries. 
It has a router, cookie and session handlers, content-negotiation, request body parsers, DSL for HTML generation, input checking, SQL migration helpers and other time saving features.

Losty stands for [L]uaty + [O]penRe[sty]


Installation
------------

Requirement: OpenResty


After installing OpenResty, run
```
opm install losty
```


Usage
-----
```
var web = require('web.web')
var view = require('web.view')

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
		, message = 'Luasty here'
	}))
)

-- custom error pages
var replies = {
	[404] = not_found()
}
server.run(replies)
```


Credits
-------
This project has stolen ideas and codes from respectable projects such as Lapis, Mashape router, lua-resty-* from Bungle, and helpful examples from OpenResty and around the web.
Of course it wouldn't exist without the magnificent OpenResty in the first place.
