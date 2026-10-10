--
-- Generated from sse.lau
--
local semaphore = require("ngx.semaphore")
local accept = require("losty.accept")
local EVstream = "text/event-stream"
local timeout = 30
local MaxQueue = 16
local Ping = "event:ping\ndata:\n\n"
local push = function(str)
    ngx.print(str)
    ngx.flush(true)
end
local enqueue = function(sub, msg)
    local q = sub.q
    local n = #q
    if n >= MaxQueue then
        table.remove(q, 1)
        q[n] = msg
    else
        q[n + 1] = msg
    end
end
local new = function()
    local subs = {}
    local n = 0
    local ping = function()
        if next(subs) then
            for _, client in pairs(subs) do
                enqueue(client, Ping)
                client.sema:post(1)
            end
        end
    end
    local publish = function(gen, ...)
        if not next(subs) then
            return 
        end
        local msg = gen(...) or ping
        for _, client in pairs(subs) do
            enqueue(client, msg)
            client.sema:post(1)
        end
        ngx.sleep(0.01)
    end
    local subscribe = function()
        local headers = ngx.req.get_headers()
        local prefs = accept.media(headers["Accept"], {EVstream})
        if tostring(prefs[1]) ~= EVstream then
            ngx.status = ngx.HTTP_NOT_ACCEPTABLE
            return 
        end
        n = n + 1
        local id = n
        local client = {q = {}, sema = semaphore.new()}
        subs[id] = client
        ngx.header["Content-Type"] = EVstream
        ngx.header["Cache-Control"] = "no-cache"
        ngx.status = 200
        ngx.send_headers()
        local alive = true
        ngx.on_abort(function()
            alive = false
            subs[id] = nil
            return ngx.exit(499)
        end)
        local sec = math.random(timeout - 10, timeout - 5)
        push("retry:" .. tostring(sec) .. "000\n" .. ping)
        while alive do
            if #client.q > 0 then
                push(client.q[1])
                table.remove(client.q, 1)
            else
                local ok = client.sema:wait(timeout)
                if not ok then
                    push(ping)
                end
            end
        end
        subs[id] = nil
    end
    return {ping = ping, pub = publish, sub = subscribe}
end
return {new = new}
