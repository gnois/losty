--
-- Generated from security.lt
--
local default = {
    x_content_type_options = "nosniff"
    , referrer_policy = "strict-origin-when-cross-origin"
    , x_frame_options = "SAMEORIGIN"
    , permissions_policy = "geolocation=(), microphone=(), camera=()"
    , cross_origin_opener_policy = "same-origin"
    , cross_origin_resource_policy = "same-site"
    , cross_origin_embedder_policy = nil
    , content_security_policy = nil
    , hsts_max_age = 31536000
    , hsts_include_subdomains = true
    , hsts_preload = false
}
local set_if_empty = function(headers, key, val)
    if val ~= nil and headers[key] == nil then
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
    return table.concat(out, "; ")
end
return function(opts)
    opts = opts or {}
    local cfg = {}
    for k, v in pairs(default) do
        cfg[k] = opts[k] ~= nil and opts[k] or v
    end
    return function(q, r)
        set_if_empty(r.headers, "X-Content-Type-Options", cfg.x_content_type_options)
        set_if_empty(r.headers, "Referrer-Policy", cfg.referrer_policy)
        set_if_empty(r.headers, "X-Frame-Options", cfg.x_frame_options)
        set_if_empty(r.headers, "Permissions-Policy", cfg.permissions_policy)
        set_if_empty(r.headers, "Cross-Origin-Opener-Policy", cfg.cross_origin_opener_policy)
        set_if_empty(r.headers, "Cross-Origin-Resource-Policy", cfg.cross_origin_resource_policy)
        set_if_empty(r.headers, "Cross-Origin-Embedder-Policy", cfg.cross_origin_embedder_policy)
        set_if_empty(r.headers, "Content-Security-Policy", cfg.content_security_policy)
        set_if_empty(r.headers, "Strict-Transport-Security", hsts(cfg, q.secure()))
        return q.next()
    end
end
