--
-- Generated from app.lt
--
local web = require("losty.web")
local content = require("losty.content")
local csrf = require("losty.csrf")
local sess = require("losty.sess")
local flash = require("losty.flash")
local to = require("losty.to")
local cfg = require("config")
local is_dev = cfg.ENV == "dev"
local session = sess("@@APP_NAME@@_sid", cfg.SECRET, nil, "lax", not is_dev)
local guard = csrf(cfg.SECRET, false, true, not is_dev)
local home = require("views.home")
local auth = require("views.auth")
local protected = require("views.protected")
local users = ngx.shared.users
if not users then
    error("missing lua_shared_dict users in nginx.conf", 0)
end
local normalize_username = function(txt)
    local u = to.trim(txt or "")
    if u == "" then
        return nil
    end
    u = string.lower(u)
    if #u < 3 or #u > 32 then
        return nil
    end
    if not string.match(u, "^[a-z0-9_%.%-]+$") then
        return nil
    end
    return u
end
local valid_password = function(txt)
    local p = txt or ""
    return #p >= 3 and #p <= 32
end
local user_key = function(username)
    return "user:" .. username
end
local hash_bin = ngx.sha1_bin
local hash_password = function(username, password)
    local raw = cfg.SECRET .. "|" .. username .. "|" .. password
    return ngx.encode_base64(hash_bin(raw))
end
local user_exists = function(username)
    return users:get(user_key(username)) ~= nil
end
local create_user = function(username, password)
    return users:add(user_key(username), hash_password(username, password))
end
local verify_user = function(username, password)
    local stored = users:get(user_key(username))
    if not stored then
        return false
    end
    return stored == hash_password(username, password)
end
local current_user = function(q)
    local s = session.read(q)
    if s and s.username then
        local u = normalize_username(s.username)
        if u and user_exists(u) then
            return {username = u, role = s.role or "user"}
        end
    end
    return nil
end
local pop_flash = function(q, r, key)
    local f = flash(q, r)
    local msg = f.get(key)
    if msg ~= nil then
        f.delete(key)
    end
    return msg
end
local set_flash = function(q, r, key, val)
    flash(q, r).set(key, val)
end
local require_user = function(q, r)
    local u = current_user(q)
    if u then
        q.user = u
        return q.next()
    end
    session.delete(r)
    return r.redirect("/signin")
end
local route = web.route()
route.get("/", content.html, function(q, r)
    return home({title = "@@APP_NAME@@", user = current_user(q)})
end)
route.get("/signup", content.html, function(q, r)
    if current_user(q) then
        return r.redirect("/app")
    end
    local token = guard.create(q, r)
    return auth.signup({title = "Sign up — @@APP_NAME@@", csrf_token = token, error = pop_flash(q, r, "signup_error")})
end)
route.post("/signup", content.html, content.form, function(q, r, body)
    local ok = guard.check(q, r, body and body.token)
    if not ok then
        set_flash(q, r, "signup_error", "Request forbidden")
        return r.redirect("/signup")
    end
    local username = normalize_username(body and body.username)
    local password = body and body.password or ""
    if not username then
        set_flash(q, r, "signup_error", "Username must be 3-32 chars and contain only a-z, 0-9, ., _, -.")
        return r.redirect("/signup")
    end
    if not valid_password(password) then
        set_flash(q, r, "signup_error", "Password must be 3-32 chars.")
        return r.redirect("/signup")
    end
    if not create_user(username, password) then
        set_flash(q, r, "signup_error", "Username already taken.")
        return r.redirect("/signup")
    end
    local s = session.create(q, r, 86400 * 7)
    s.username = username
    s.role = "user"
    r.redirect("/app")
end)
route.get("/signin", content.html, function(q, r)
    if current_user(q) then
        return r.redirect("/app")
    end
    local token = guard.create(q, r)
    return auth.signin({title = "Sign in — @@APP_NAME@@", csrf_token = token, error = pop_flash(q, r, "signin_error")})
end)
route.post("/signin", content.html, content.form, function(q, r, body)
    local ok = guard.check(q, r, body and body.token)
    if not ok then
        set_flash(q, r, "signin_error", "Request forbidden")
        return r.redirect("/signin")
    end
    local username = normalize_username(body and body.username)
    local password = body and body.password or ""
    if not username or not verify_user(username, password) then
        set_flash(q, r, "signin_error", "Invalid username or password.")
        return r.redirect("/signin")
    end
    local s = session.create(q, r, 86400 * 7)
    s.username = username
    s.role = "user"
    r.redirect("/app")
end)
route.get("/app", content.html, require_user, function(q, r)
    return protected({title = "@@APP_NAME@@ — Account", user = q.user, csrf_token = guard.create(q, r)})
end)
route.post("/signout", content.html, content.form, require_user, function(q, r, body)
    if guard.check(q, r, body and body.token) then
        session.delete(r)
        return r.redirect("/")
    end
    r.status = 403
    return r.redirect("/app")
end)
route.get("/signout", function(q, r)
    session.delete(r)
    r.redirect("/")
end)
return web
