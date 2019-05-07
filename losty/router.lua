--
-- Generated from router.lt
--
return function()
    local COLON = string.byte(":", 1)
    local LEAF = "~"
    local tree = {}
    local K = {}
    local resolve
    resolve = function(path, node, params)
        local _, token
        _, _, token, path = string.find(path, "([^/]+)(.*)")
        if not token then
            return node[LEAF], params
        end
        for child_token, child_node in pairs(node) do
            if child_token == token then
                local func, bindings = resolve(path, child_node, params)
                if func then
                    return func, bindings
                end
            end
        end
        for child_token, child_node in pairs(node) do
            if string.byte(child_token, 1) == COLON then
                local name = string.sub(child_token, 2)
                local value = params[name]
                params[name] = token or value
                local func, bindings = resolve(path, child_node, params)
                if func then
                    return func, bindings
                end
                params[name] = value
            end
        end
        return false
    end
    local install = function(node, path, ...)
        for token in string.gmatch(path, "[^/]+") do
            node[token] = node[token] or {}
            node = node[token]
        end
        local old = node[LEAF]
        if nil == old then
            node[LEAF] = {...}
        else
            for _, f in ipairs({...}) do
                old[#old + 1] = f
            end
            node[LEAF] = old
        end
    end
    K.match = function(method, path)
        local node = tree[method]
        if not node then
            return nil, string.format("Unknown method: %s", method)
        end
        path = string.gsub(path, "%?.*", "")
        local func, params = resolve(path, node, {})
        if not func then
            return nil, string.format("Could not resolve %s %s", method, path)
        end
        return func, params
    end
    K.set = function(method, path, ...)
        assert(path and #path > 0)
        if not tree[method] then
            tree[method] = {}
        end
        install(tree[method], path, ...)
    end
    return K
end
