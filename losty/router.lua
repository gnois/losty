--
-- Generated from router.lt
--
local str_sub = string.sub
local str_find = string.find
local str_match = string.match
local next_segment = function(path)
    if not path or path == "" or path == "/" then
        return nil, ""
    end
    local n = #path
    local i = 1
    while i <= n and str_sub(path, i, i) == "/" do
        i = i + 1
    end
    if i > n then
        return nil, ""
    end
    local j = i
    while j <= n and str_sub(path, j, j) ~= "/" do
        j = j + 1
    end
    if j <= n then
        return str_sub(path, i, j - 1), str_sub(path, j)
    end
    return str_sub(path, i), ""
end
local COLON = ":"
local LEAF = "#"
local router = function()
    local tree = {}
    local bind = function(matches, m, token, toklen, s, e, ...)
        if s == 1 and e == toklen then
            matches[m] = token
            m = m + 1
            local n = select("#", ...)
            for i = 1, n do
                local v = select(i, ...)
                if v == nil then
                    break
                end
                matches[m] = v
                m = m + 1
            end
            return true, m
        end
        return false, m
    end
    local resolve
    resolve = function(path, nodes, matches, m)
        local token
        token, path = next_segment(path)
        if not token then
            return nodes[LEAF], matches
        end
        local child = nodes[token]
        if child then
            local func, bindings = resolve(path, child, matches, m)
            if func then
                return func, bindings
            end
        end
        local pattern
        local toklen = #token
        for __, node in ipairs(nodes) do
            pattern, child = next(node)
            local prev = m
            local ok
            ok, m = bind(matches, m, token, toklen, str_find(token, pattern))
            if ok then
                local func, bindings = resolve(path, child, matches, m)
                if func then
                    return func, bindings
                end
            end
            m = prev
        end
        return false
    end
    local check = function(pattern)
        if not str_find(pattern, "[%.%%]") and not str_find(pattern, "%b[]") then
            return false, "'" .. pattern .. "' is not a pattern"
        end
        if str_find(pattern, "[:#]") then
            return false, "'" .. pattern .. "' may not match any url"
        end
        for _, c in ipairs({"%%c", "%%s"}) do
            if str_find(pattern, c) then
                return false, "'" .. str_sub(c, 2) .. "' may not match any url"
            end
        end
        return pcall(str_find, pattern, pattern)
    end
    local find_create = function(nodes, token)
        local x
        for _, n in ipairs(nodes) do
            x = n[token]
            if x then
                break
            end
        end
        if not x then
            x = {}
            table.insert(nodes, {[token] = x})
        end
        return x
    end
    local install = function(nodes, path, ...)
        for token in string.gmatch(path, "[^/]+") do
            if COLON == str_sub(token, 1, 1) then
                if str_match(token, ":%b()") == token then
                    token = str_sub(token, 3, -2)
                else
                    token = str_sub(token, 2)
                end
                local ok, err = check(token)
                if not ok then
                    error(err .. " in " .. path, 5)
                end
                nodes = find_create(nodes, token)
            else
                nodes[token] = nodes[token] or {}
                nodes = nodes[token]
            end
        end
        local old = nodes[LEAF]
        if not old then
            old = {...}
        else
            local o = #old
            for n, f in ipairs({...}) do
                old[o + n] = f
            end
        end
        nodes[LEAF] = old
    end
    local invalid = function(path)
        if not path or #path < 1 then
            return "is empty"
        end
        if str_sub(path, 1, 1) ~= "/" then
            return "does not start with '/'"
        end
        if str_find(path, "%s") then
            return "has space"
        end
        if str_find(path, "//") then
            return "has empty segment"
        end
    end
    return {match = function(method, path, strict)
        local nodes = tree[method]
        if not nodes then
            return nil, "unmatched method: " .. (method or "")
        end
        if strict and str_find(path, "//") then
            return nil, "disallowed double slash path: " .. (path or "")
        end
        path = path or ""
        local q = str_find(path, "?", 1, true)
        if q then
            path = str_sub(path, 1, q - 1)
        end
        local arr, matches = resolve(path, nodes, {}, 1)
        if not arr then
            return nil, "unmatched path: " .. (path or "")
        end
        return arr, matches
    end, set = function(method, path, ...)
        local err = invalid(path)
        if err then
            error("route '" .. path .. "' " .. err, 4)
        end
        if not tree[method] then
            tree[method] = {}
        end
        install(tree[method], path, ...)
        return tree[method]
    end}
end
return router
