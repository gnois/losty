--
-- Generated from replay.lt
--
return function(dict_name, default_ttl)
    local dict = ngx.shared[dict_name]
    if not dict then
        error("missing lua_shared_dict " .. tostring(dict_name), 2)
    end
    default_ttl = default_ttl or 300
    local seen = function(nonce, ttl)
        if not nonce or #nonce < 8 then
            return false, "nonce required"
        end
        ttl = ttl or default_ttl
        local ok, err = dict:safe_add(nonce, true, ttl)
        if ok then
            return true
        end
        if err == "exists" then
            return false, "replay"
        end
        return false, err
    end
    return {seen = seen, handler = function(noncefn, ttl)
        return function(q, r)
            local nonce
            if noncefn then
                nonce = noncefn(q)
            else
                nonce = q.headers["Idempotency-Key"] or q.headers["X-Request-Id"]
            end
            local ok, err = seen(nonce, ttl)
            if ok then
                return q.next()
            end
            r.status = ngx.HTTP_CONFLICT
            return {fail = err}
        end
    end}
end
