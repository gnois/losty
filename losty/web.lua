--
-- Generated from web.lt
--
local router = require("losty.router")
local dispatch = require("losty.dispatch")
local statuses = require("losty.status")
local req = require("losty.req")
local res = require("losty.res")
local cjson = require("cjson.safe")
local unpack = table.unpack or unpack
local METHODS = {
    "GET"
    , "POST"
    , "PUT"
    , "DELETE"
    , "PATCH"
    , "OPTIONS"
}
local rt = router()
local send_body = function(body)
    if type(body) == "function" then
        while true do
            local chunk = body()
            if chunk == nil then
                return true
            end
            local ok, err = ngx.print(chunk)
            if ok then
                ok, err = ngx.flush(true)
            end
            if not ok then
                return ok, err
            end
        end
    end
    return ngx.print(body)
end
local prepare_body = function(r, body)
    if type(body) == "table" and type(next(body)) == "string" then
        local encoded, err = cjson.encode(body)
        if encoded then
            if r.headers["Content-Type"] == nil then
                r.headers["Content-Type"] = "application/json"
            end
            return encoded
        end
        ngx.log(ngx.ERR, "prepare_body: failed to encode response as JSON: ", err)
        return nil
    end
    return body
end
local is_exec_intent = function(body)
    return type(body) == "table" and body.__ngx_exec == true and body.uri
end
local run_defers = function(q)
    local hooks = q._defer_hooks
    if hooks then
        for i = #hooks, 1, -1 do
            local ok, err = xpcall(hooks[i], function(trace)
                return debug.traceback(trace, 2)
            end)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        end
    end
end
local route = function(prefix)
    local phase = ngx.get_phase()
    if phase ~= "init" then
        error("route() must be called in init_by_lua_block instead of '" .. phase .. "' phase", 2)
    end
    local r = {}
    for _, meth in ipairs(METHODS) do
        r[string.lower(meth)] = function(path, f, ...)
            if prefix and prefix ~= "/" then
                path = prefix .. path
            end
            rt.set(meth, path, f, ...)
        end
    end
    return r
end
local run = function(error_page, check)
    local handlers, body, ok, trace
    local q = req()
    local r = res()
    q._defer_hooks = {}
    q.defer = function(fn, ...)
        if "function" ~= type(fn) then
            error("defer requires function", 2)
        end
        local np = select("#", ...)
        if np == 0 then
            table.insert(q._defer_hooks, fn)
        else
            local args = {...}
            table.insert(q._defer_hooks, function()
                return fn(unpack(args, 1, np))
            end)
        end
    end
    local method = q.vars.request_method
    handlers, q.match = rt.match(method == "HEAD" and "GET" or method, q.vars.uri)
    if handlers then
        ok, trace = xpcall(function()
            body = dispatch(handlers, q, r)
        end, function(err)
            return debug.traceback(err, 2)
        end)
        if not ok then
            r.status = 500
            ngx.log(ngx.ERR, trace)
        end
    else
        r.status = 404
    end
    run_defers(q)
    if is_exec_intent(body) then
        if body.args ~= nil then
            return ngx.exec(body.uri, body.args)
        end
        return ngx.exec(body.uri)
    end
    body = prepare_body(r, body)
    local code = r.status
    if error_page == true and body == nil and code >= 400 then
        return ngx.exit(code)
    end
    local empty = statuses.is_empty(code)
    if check then
        if code == 0 then
            error("Response status required")
        end
        if body ~= nil or code >= 200 and code < 300 then
            if not empty and r.headers["Content-Type"] == nil then
                error("Content-Type header required")
            end
        end
    end
    local err
    ok, err = r.send()
    if ok then
        if method ~= "HEAD" and not empty and body ~= nil then
            ok, err = send_body(body)
        end
        if ok then
            ok, err = ngx.eof()
        end
    end
    if not ok then
        ngx.log(ngx.ERR, err)
    end
    return code, err or trace
end
return {route = route, run = run}
