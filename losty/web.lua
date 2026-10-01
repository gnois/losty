--
-- Generated from web.lau
--
local router = require("losty.router")
local dispatch = require("losty.dispatch")
local statuses = require("losty.status")
local req = require("losty.req")
local res = require("losty.res")
local etag = require("losty.etag")
local cjson = require("cjson.safe")
local METHODS = {
    "GET"
    , "POST"
    , "PUT"
    , "DELETE"
    , "PATCH"
    , "OPTIONS"
}
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
    if type(body) == "table" then
        local encoded, err = cjson.encode(body)
        if not encoded then
            error("response body is not JSON-encodable: " .. tostring(err), 2)
        end
        if r.headers["Content-Type"] == nil then
            r.headers["Content-Type"] = "application/json"
        end
        return encoded
    end
    return body
end
local has_body = function(body)
    if body == nil or type(body) == "string" and body == "" then
        return false
    end
    return true
end
local trace_err = function(err)
    return debug.traceback(err, 2)
end
local prefixed = function(base, path)
    if base and base ~= "/" then
        return base .. path
    end
    return path
end
local registrar = function(rt, base, name)
    local r = {}
    for _, meth in ipairs(METHODS) do
        r[string.lower(meth)] = function(path, f, ...)
            local phase = ngx.get_phase()
            if phase ~= "init" then
                error("route must be declared in init_by_lua_block, not '" .. phase .. "' phase (app '" .. (name or "unnamed") .. "')", 2)
            end
            rt.set(meth, prefixed(base, path), f, ...)
        end
    end
    return r
end
local run = function(rt, name, error_page, check)
    local handlers, body, ok, trace
    local q = req()
    local r = res()
    q.state = {}
    local method = q.vars.request_method
    local params
    handlers, q.match, params = rt.match(method == "HEAD" and "GET" or method, q.vars.uri)
    if not handlers then
        q.match = {}
    end
    q.params = params or {}
    if handlers then
        ok, trace = xpcall(function()
            body = dispatch(handlers, q, r)
        end, trace_err)
        if not ok then
            r.status = 500
            ngx.log(ngx.ERR, (name and "[" .. name .. "] " or "") .. trace)
        end
    else
        local allow = rt.allowed(method, q.vars.uri)
        if allow then
            r.status = 405
            r.headers["Allow"] = table.concat(allow, ", ")
        else
            r.status = 404
        end
    end
    r.run_defers()
    body = prepare_body(r, body)
    body = etag.check(q, r, body)
    local code = r.status
    if error_page == true and code >= 400 and not has_body(body) then
        return ngx.exit(code)
    end
    local empty = statuses.is_empty(code)
    if check then
        if code == 0 then
            error("Response status required")
        end
        if statuses.is_redirect(code) and r.headers["Location"] == nil then
            error("Location header required for redirect status")
        end
        if body ~= nil or code >= 200 and code < 300 then
            if not empty and r.headers["Content-Type"] == nil then
                error("Content-Type header required")
            end
        end
    end
    local err
    ok, err = r.send()
    if not ok then
        ngx.log(ngx.ERR, (name and "[" .. name .. "] " or "") .. "cannot send headers: " .. tostring(err))
        return code, err or trace
    end
    if method ~= "HEAD" and not empty and body ~= nil then
        ok, err = send_body(body)
    end
    if ok then
        ok, err = ngx.eof()
    end
    if not ok then
        ngx.log(ngx.WARN, (name and "[" .. name .. "] " or "") .. "cannot send body: " .. tostring(err))
    end
    return code, err or trace
end
local new = function(name)
    local rt = router()
    local app = registrar(rt, nil, name)
    app.name = name
    app.route = function(prefix)
        return registrar(rt, prefix, name)
    end
    app.run = function(error_page, check)
        return run(rt, name, error_page, check)
    end
    return app
end
return {new = new}
