--
-- Generated from router.lt
--
local str_sub = string.sub
local str_find = string.find
local str_match = string.match
local COLON = ":"
local LEAF = "#"
local router = function()
    local tree = {}
    local resolve
    resolve = function(path, nodes, matches, m)
        local _, token
        _, _, token, path = str_find(path, "([^/]+)(.*)")
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
            if (function(s, e, ...)
                if s == 1 and e == toklen then
                    matches[m] = token
                    m = m + 1
                    for ___, v in ipairs({...}) do
                        matches[m] = v
                        m = m + 1
                    end
                    return true
                end
            end)(str_find(token, pattern)) then
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
                    error(err .. " in " .. path, 2)
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
        if not str_sub(path, 1, 1) == "/" then
            return "does not start with '/'"
        end
        if str_find(path, "%s") then
            return "has space"
        end
        if str_find(path, "//") then
            return "has empty segment"
        end
    end
    return {match = function(method, path)
        local nodes = tree[method]
        if not nodes then
            return nil, "unmatched method: " .. (method or "")
        end
        path = string.gsub(path, "%?.*", "")
        local arr, matches = resolve(path, nodes, {}, 1)
        if not arr then
            return nil, "unmatched path: " .. (path or "")
        end
        return arr, matches
    end, set = function(method, path, ...)
        local err = invalid(path)
        if err then
            error("route '" .. path .. "' " .. err, 2)
        end
        if not tree[method] then
            tree[method] = {}
        end
        install(tree[method], path, ...)
        return tree[method]
    end}
end
return router
