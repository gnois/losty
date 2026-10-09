--
-- Generated from security.lau
--
local rnd = require("resty.random")
local cjson = require("cjson")
local concat = table.concat
local sort = table.sort
local gmatch = string.gmatch
local gsub = string.gsub
local match = string.match
local lower = string.lower
local nonce = {}
local default = {
    x_content_type_options = "nosniff"
    , referrer_policy = "strict-origin-when-cross-origin"
    , x_frame_options = "SAMEORIGIN"
    , permissions_policy = "geolocation=(), microphone=(), camera=()"
    , cross_origin_opener_policy = "same-origin"
    , cross_origin_resource_policy = "same-site"
    , cross_origin_embedder_policy = nil
    , origin_agent_cluster = "?1"
    , x_dns_prefetch_control = "off"
    , x_download_options = "noopen"
    , x_permitted_cross_domain_policies = "none"
    , x_xss_protection = "0"
    , content_security_policy = nil
    , report_to = nil
    , reporting_endpoints = nil
    , hsts_max_age = 31536000
    , hsts_include_subdomains = true
    , hsts_preload = false
    , remove_powered_by = true
}
local set_if_empty = function(headers, key, val)
    if val ~= nil and val ~= false and headers[key] == nil then
        headers[key] = val
    end
end
local hsts = function(cfg, secure)
    if not secure or not cfg.hsts_max_age or cfg.hsts_max_age <= 0 then
        return nil
    end
    local out = {"max-age=" .. tostring(cfg.hsts_max_age)}
    if cfg.hsts_include_subdomains then
        out[#out + 1] = "includeSubDomains"
    end
    if cfg.hsts_preload then
        out[#out + 1] = "preload"
    end
    return concat(out, "; ")
end
local kebab = function(name)
    name = gsub(name, "_", "-")
    local out, n = {}, 0
    local prev
    for c in gmatch(name, ".") do
        if prev and match(c, "%u") and match(prev, "[%l%d]") then
            n = n + 1
            out[n] = "-"
        end
        n = n + 1
        out[n] = lower(c)
        prev = c
    end
    return concat(out)
end
local render_values = function(vals, n)
    if "table" == type(vals) then
        local out, c = {}, 0
        for _, v in ipairs(vals) do
            c = c + 1
            out[c] = v == nonce and "'nonce-" .. n .. "'" or tostring(v)
        end
        return concat(out, " ")
    end
    return vals == nonce and "'nonce-" .. n .. "'" or tostring(vals)
end
local render_directive = function(name, vals, n)
    if true == vals then
        return name
    end
    if "table" == type(vals) and vals ~= nonce and next(vals) == nil then
        return name
    end
    return name .. " " .. render_values(vals, n)
end
local uses_nonce = function(vals)
    if "table" == type(vals) then
        if vals == nonce then
            return true
        end
        for _, v in ipairs(vals) do
            if v == nonce then
                return true
            end
        end
    end
    return false
end
local csp = function(directives)
    return {_directives = directives}
end
local render_csp = function(directives, n)
    local parts, names = {}, {}
    local i = 0
    for k, v in pairs(directives) do
        local name = kebab(k)
        i = i + 1
        names[i] = name
        parts[name] = render_directive(name, v, n)
    end
    sort(names)
    local out, c = {}, 0
    for j = 1, i do
        c = c + 1
        out[c] = parts[names[j]]
    end
    return concat(out, "; ")
end
local reporting_endpoints = function(list)
    local out, n = {}, 0
    for _, e in ipairs(list) do
        n = n + 1
        out[n] = e.name .. "=\"" .. e.url .. "\""
    end
    return concat(out, ", ")
end
local report_to = function(groups)
    local out, n = {}, 0
    for _, g in ipairs(groups) do
        local eps, m = {}, 0
        for _, e in ipairs(g.endpoints or {}) do
            m = m + 1
            eps[m] = "{\"url\":" .. cjson.encode(e.url) .. "}"
        end
        local max_age = g.max_age
        if max_age == nil then
            max_age = g.maxAge
        end
        local obj = "{\"group\":" .. cjson.encode(g.group)
        obj = obj .. ",\"max_age\":" .. tostring(max_age)
        obj = obj .. ",\"endpoints\":[" .. concat(eps, ",") .. "]}"
        n = n + 1
        out[n] = obj
    end
    return concat(out, ", ")
end
local render_policy = function(policy, n)
    if "table" ~= type(policy) then
        return policy
    end
    if policy._directives then
        return render_csp(policy._directives, n)
    end
    error("content_security_policy must be a string or security.csp{...}", 2)
end
local new = function(opts)
    opts = opts or {}
    local cfg = {}
    for k, v in pairs(default) do
        if opts[k] ~= nil then
            cfg[k] = opts[k]
        else
            cfg[k] = v
        end
    end
    local policy = cfg.content_security_policy
    local needs_nonce = false
    if "table" == type(policy) and policy._directives then
        for _, v in pairs(policy._directives) do
            if uses_nonce(v) then
                needs_nonce = true
                break
            end
        end
    end
    local report_value = cfg.report_to and #cfg.report_to > 0 and report_to(cfg.report_to) or nil
    local endpoints_value = cfg.reporting_endpoints and #cfg.reporting_endpoints > 0 and reporting_endpoints(cfg.reporting_endpoints) or nil
    return function(q, r, nxt)
        local n
        if needs_nonce then
            local b = rnd.bytes(16)
            n = b and ngx.encode_base64(b) or ngx.var.request_id
            q.state.nonce = n
        end
        set_if_empty(r.headers, "X-Content-Type-Options", cfg.x_content_type_options)
        set_if_empty(r.headers, "Referrer-Policy", cfg.referrer_policy)
        set_if_empty(r.headers, "X-Frame-Options", cfg.x_frame_options)
        set_if_empty(r.headers, "Permissions-Policy", cfg.permissions_policy)
        set_if_empty(r.headers, "Cross-Origin-Opener-Policy", cfg.cross_origin_opener_policy)
        set_if_empty(r.headers, "Cross-Origin-Resource-Policy", cfg.cross_origin_resource_policy)
        set_if_empty(r.headers, "Cross-Origin-Embedder-Policy", cfg.cross_origin_embedder_policy)
        set_if_empty(r.headers, "Origin-Agent-Cluster", cfg.origin_agent_cluster)
        set_if_empty(r.headers, "X-DNS-Prefetch-Control", cfg.x_dns_prefetch_control)
        set_if_empty(r.headers, "X-Download-Options", cfg.x_download_options)
        set_if_empty(r.headers, "X-Permitted-Cross-Domain-Policies", cfg.x_permitted_cross_domain_policies)
        set_if_empty(r.headers, "X-XSS-Protection", cfg.x_xss_protection)
        set_if_empty(r.headers, "Content-Security-Policy", render_policy(policy, n))
        set_if_empty(r.headers, "Strict-Transport-Security", hsts(cfg, q.secure()))
        set_if_empty(r.headers, "Report-To", report_value)
        set_if_empty(r.headers, "Reporting-Endpoints", endpoints_value)
        local out = nxt()
        if cfg.remove_powered_by then
            r.headers["X-Powered-By"] = nil
        end
        return out
    end
end
return {new = new, csp = csp, nonce = nonce}
