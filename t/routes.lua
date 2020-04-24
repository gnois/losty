local web = require('losty.web')()
local w = web.route()

w.get('/foo', function(q, r)
    r.status = 200
    r.headers["content-type"] = "text/plain"
    return "Ho foo"
end)

w.get('/bar', function(q, r)
    r.status = 200
    r.headers["content-type"] = "text/plain"
    return "Ha bar"
end)

return function()
    web.run()
end