--
-- Generated from router.lau
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
local NAME = "^[%a_][%w_]*$"
local ALLOW_ORDER = {
    "GET"
    , "HEAD"
    , "POST"
    , "PUT"
    , "DELETE"
    , "PATCH"
    , "OPTIONS"
}
local new_node = function()
    return {kids = {}, pats = {}}
end
local truncate = function(t, len)
    for i = #t, len + 1, -1 do
        t[i] = nil
    end
end
local router = function()
    local tree = {}
    local has_mw = {}
    local has_name = {}
    local bind = function(matches, m, token, toklen, name, caps, s, e, ...)
        if s == 1 and e == toklen then
            if name then
                caps[#caps + 1] = {name, token}
            else
                matches[m] = token
                m = m + 1
            end
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
    local resolve; resolve = function(path, node, matches, m, caps, mws)
        if node.mw then
            for _, f in ipairs(node.mw) do
                mws[#mws + 1] = f
            end
        end
        local keepmw = mws and #mws or 0
        local keepcap = caps and #caps or 0
        local token
        token, path = next_segment(path)
        if not token then
            return node.leaf, m
        end
        local child = node.kids[token]
        if child then
            local leaf, em = resolve(path, child, matches, m, caps, mws)
            if leaf then
                return leaf, em
            end
            if mws then
                truncate(mws, keepmw)
            end
            if caps then
                truncate(caps, keepcap)
            end
        end
        local toklen = #token
        for _, e in ipairs(node.pats) do
            local prev = m
            local c0 = caps and #caps or 0
            local ok
            ok, m = bind(matches, m, token, toklen, e.name, caps, str_find(token, e.pat))
            if ok then
                local leaf, pm = resolve(path, e.node, matches, m, caps, mws)
                if leaf then
                    return leaf, pm
                end
            end
            m = prev
            if caps then
                truncate(caps, c0)
            end
            if mws then
                truncate(mws, keepmw)
            end
        end
        if node.wilds then
            local rest = token .. path
            for _, w in ipairs(node.wilds) do
                if w.name then
                    caps[#caps + 1] = {w.name, rest}
                    if w.node.leaf then
                        return w.node.leaf, m
                    end
                    if caps then
                        truncate(caps, keepcap)
                    end
                else
                    matches[m] = rest
                    if w.node.leaf then
                        return w.node.leaf, m + 1
                    end
                    matches[m] = nil
                end
            end
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
    local strip = function(pat)
        if str_match(pat, "%b()") == pat then
            return str_sub(pat, 2, -2)
        end
        return pat
    end
    local find_pat = function(node, pat, name)
        for _, e in ipairs(node.pats) do
            if e.pat == pat and e.name == name then
                return e.node
            end
        end
        node.pats[#node.pats + 1] = {pat = pat, name = name, node = new_node()}
        return node.pats[#node.pats].node
    end
    local find_wild = function(node, name)
        for _, w in ipairs(node.wilds) do
            if w.name == name then
                return w.node
            end
        end
        local child = new_node()
        node.wilds[#node.wilds + 1] = {name = name, node = child}
        return child
    end
    local segment = function(token, path)
        if str_sub(token, 1, 1) == "{" then
            if str_sub(token, -1) ~= "}" then
                error("route '" .. path .. "': unbalanced '{' in '" .. token .. "'", 4)
            end
            local inner = str_sub(token, 2, -2)
            if str_find(inner, "[{}]") then
                error("route '" .. path .. "': unexpected brace in '" .. token .. "'", 4)
            end
            if inner == "+" then
                return {kind = "mw"}
            end
            if str_sub(inner, 1, 1) == "*" then
                local wname = str_sub(inner, 2)
                if wname ~= "" and not str_match(wname, NAME) then
                    error("route '" .. path .. "': bad wildcard name '" .. token .. "'", 4)
                end
                return {kind = "wild", name = wname ~= "" and wname or nil}
            end
            if str_sub(inner, 1, 1) == ":" then
                local pat = strip(str_sub(inner, 2))
                local ok, err = check(pat)
                if not ok then
                    error(err .. " in " .. path, 4)
                end
                return {kind = "cap", pat = pat}
            end
            local c = str_find(inner, ":", 1, true)
            local nm, ptn
            if c then
                nm = str_sub(inner, 1, c - 1)
                ptn = strip(str_sub(inner, c + 1))
            else
                nm = inner
                ptn = "[^/]+"
            end
            if not str_match(nm, NAME) then
                error("route '" .. path .. "': '" .. token .. "' is neither a name nor ':{pattern}'", 4)
            end
            local okp, errp = check(ptn)
            if not okp then
                error(errp .. " in " .. path, 4)
            end
            return {kind = "cap", pat = ptn, name = nm}
        end
        if str_sub(token, 1, 1) == ":" then
            error("route '" .. path .. "': patterns moved into braces: write '{:" .. str_sub(token, 2) .. "}'", 4)
        end
        if str_find(token, "%*") then
            error("route '" .. path .. "': '*' is not a route marker: use '{*}' or '{+}'", 4)
        end
        if str_find(token, "[{}]") then
            error("route '" .. path .. "': unexpected brace in '" .. token .. "'", 4)
        end
        return {kind = "lit", token = token}
    end
    local parse = function(path)
        local segs = {}
        for token in string.gmatch(path, "[^/]+") do
            segs[#segs + 1] = segment(token, path)
        end
        return segs
    end
    local build = function(root, segs, path, ...)
        local node = root
        local n = #segs
        for i = 1, n do
            local seg = segs[i]
            if seg.kind == "mw" then
                if i ~= n then
                    error("route '" .. path .. "': '{+}' must be the last segment", 4)
                end
                node.mw = node.mw or {}
                for _, f in ipairs({...}) do
                    node.mw[#node.mw + 1] = f
                end
                return 
            end
            if seg.kind == "wild" then
                if i ~= n then
                    error("route '" .. path .. "': '{*}' must be the last segment", 4)
                end
                node.wilds = node.wilds or {}
                node = find_wild(node, seg.name)
            elseif seg.kind == "cap" then
                node = find_pat(node, seg.pat, seg.name)
            else
                node.kids[seg.token] = node.kids[seg.token] or new_node()
                node = node.kids[seg.token]
            end
        end
        node.leaf = node.leaf or {}
        for _, f in ipairs({...}) do
            node.leaf[#node.leaf + 1] = f
        end
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
        local matches = {}
        local caps
        if has_name[method] then
            caps = {}
        end
        local mws
        if has_mw[method] then
            mws = {}
        end
        local leaf, m = resolve(path, nodes, matches, 1, caps, mws)
        if not leaf then
            return nil, "unmatched path: " .. (path or "")
        end
        truncate(matches, m)
        if caps then
            for _, c in ipairs(caps) do
                matches[c[1]] = c[2]
            end
        end
        if not mws or #mws == 0 then
            return leaf, matches
        end
        local handlers = {}
        for _, f in ipairs(mws) do
            handlers[#handlers + 1] = f
        end
        for _, f in ipairs(leaf) do
            handlers[#handlers + 1] = f
        end
        return handlers, matches
    end, allowed = function(method, path)
        path = path or ""
        local q = str_find(path, "?", 1, true)
        if q then
            path = str_sub(path, 1, q - 1)
        end
        local primary = tree[method]
        local set = {}
        for meth, nodes in pairs(tree) do
            if nodes ~= primary and resolve(path, nodes, {}, 1, {}, {}) then
                set[meth] = true
                if meth == "GET" then
                    set["HEAD"] = true
                end
            end
        end
        if next(set) == nil then
            return nil
        end
        local arr = {}
        for _, m in ipairs(ALLOW_ORDER) do
            if set[m] then
                table.insert(arr, m)
            end
        end
        return arr
    end, set = function(method, path, ...)
        local err = invalid(path)
        if err then
            error("route '" .. path .. "' " .. err, 4)
        end
        if not tree[method] then
            tree[method] = new_node()
        end
        local segs = parse(path)
        local seen = {}
        for _, seg in ipairs(segs) do
            if seg.kind == "mw" then
                has_mw[method] = true
            elseif seg.name then
                if seen[seg.name] then
                    error("route '" .. path .. "': duplicate capture name '" .. seg.name .. "'", 4)
                end
                seen[seg.name] = true
                has_name[method] = true
            end
        end
        build(tree[method], segs, path, ...)
        return tree[method]
    end}
end
return router
