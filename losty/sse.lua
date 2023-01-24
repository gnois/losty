--
-- Generated from sse.lt
--
local semaphore = require("ngx.semaphore")
local accept = require("losty.accept")
local EVstream = "text/event-stream"
local timeout = 30
local ping = "event:ping\ndata:\n\n"
local sema = semaphore.new()
local content
local pinging = function()
    content = ping
end
local publish = function(gen, ...)
    local clients = sema:count()
    if clients < 0 then
        content = gen(...)
        sema:post(-clients)
        ngx.sleep(0.01)
    end
end
local push = function(str)
    ngx.print(str)
    ngx.flush(true)
end
local subscribe = function()
    local headers = ngx.req.get_headers()
    local prefs = accept(headers["Accept"], {EVstream})
    if tostring(prefs[1]) == EVstream then
        ngx.header["Content-Type"] = EVstream
        ngx.header["Cache-Control"] = "no-cache"
        ngx.status = 200
        ngx.send_headers()
        local alive = true
        ngx.on_abort(function()
            alive = false
            return ngx.exit(499)
        end)
        local sec = math.random(timeout - 10, timeout - 5)
        push("retry:" .. tostring(sec) .. "000\n" .. ping)
        while alive do
            sema:wait(timeout)
            push(content)
        end
    else
        ngx.status = ngx.HTTP_NOT_ACCEPTABLE
    end
end
return {pinging = pinging, pub = publish, sub = subscribe}
