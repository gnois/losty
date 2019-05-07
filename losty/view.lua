--
-- Generated from view.lt
--
local tbl = require("losty.tbl")
local set = require("losty.set")
local concat = table.concat
local yield = coroutine.yield
local create = coroutine.create
local resume = coroutine.resume
local gmatch = string.gmatch
local gsub = string.gsub
local normal_tags = set("a", "abbr", "address", "article", "aside", "audio", "b", "bdi", "bdo", "blockquote", "body", "button", "canvas", "caption", "cite", "code", "colgroup", "data", "datagrid", "datalist", "dd", "del", "details", "dfn", "div", "dl", "dt", "em", "eventsource", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "html", "i", "iframe", "ins", "kbd", "label", "legend", "li", "main", "mark", "map", "menu", "meter", "nav", "noscript", "object", "ol", "optgroup", "option", "output", "p", "pre", "progress", "q", "ruby", "rp", "rt", "s", "samp", "script", "section", "select", "small", "span", "strong", "style", "sub", "summary", "details", "sup", "table", "tbody", "td", "textarea", "tfoot", "th", "thead", "time", "title", "tr", "u", "ul", "var", "video")
local void_tags = set("area", "base", "br", "col", "command", "embed", "hr", "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr")
local parse = function(s)
    local r = create(function()
        local acc, n = {}, 1
        for c in gmatch(s, ".") do
            if c == "." or c == "#" or c == "[" then
                if acc[1] == "[" then
                    acc[n] = c
                    n = n + 1
                else
                    if acc[1] then
                        yield(acc)
                    end
                    acc = {c}
                    n = 2
                end
            else
                acc[n] = c
                n = n + 1
                if c == "]" then
                    if n > 3 then
                        yield(acc)
                    end
                    acc = {}
                    n = 1
                end
            end
        end
        if acc[1] then
            yield(acc)
        end
    end)
    return function()
        local code, res = resume(r)
        return res
    end
end
local void = function(tag, attrs)
    local cell = {tag = tag, attrs = {}}
    local classes, n = {}, 1
    if attrs then
        local kind = type(attrs)
        if "string" == kind then
            for v in parse(attrs) do
                if v[1] == "#" then
                    cell.attrs.id = concat(v, "", 2)
                elseif v[1] == "." then
                    classes[n] = concat(v, "", 2)
                    n = n + 1
                elseif v[1] == "[" then
                    local i = tbl.find(v, "=")
                    local key, val
                    if i then
                        key = concat(v, "", 2, i - 1)
                        val = concat(v, "", i + 1, #v - 1)
                        val = gsub(val, "['\"](%w+)['\"]", "%1")
                    else
                        key = concat(v, "", 2, #v - 1)
                        val = true
                    end
                    cell.attrs[key] = val
                else
                    local msg = tag .. "('" .. concat(v) .. "'"
                    error(msg .. " attribute must start with `.` or `#` or `[`")
                end
            end
        elseif "table" == kind then
            for key, val in pairs(attrs) do
                if key == "class" then
                    if val ~= nil and val ~= "" then
                        classes[n] = val
                        n = n + 1
                    end
                else
                    cell.attrs[key] = val
                end
            end
        else
            local msg = tag .. "(" .. kind
            error(msg .. " attribute must be a table or a string")
        end
    end
    if classes[1] then
        cell.attrs["class"] = concat(classes, " ")
    end
    return cell
end
local normal = function(tag, attrs, ...)
    local args
    if attrs then
        args = {...}
        local n = #args
        if n == 0 then
            local kind = type(attrs)
            if "number" == kind or "string" == kind or "table" == kind and attrs[1] or attrs.tag then
                args = attrs
                attrs = nil
            end
        elseif n == 1 then
            if "table" == type(args[n]) and args[n][1] then
                args = args[n]
            end
        end
    end
    local cell = void(tag, attrs)
    cell.children = args
    return cell
end
local html5 = function(node)
    local o, n = {"<!DOCTYPE html>"}, 2
    local convert
    convert = function(cell)
        if cell and cell.tag then
            o[n] = "<" .. cell.tag
            n = n + 1
            for k, v in pairs(cell.attrs) do
                o[n] = " " .. k
                n = n + 1
                if not ("boolean" == type(v)) then
                    o[n] = "=\"" .. v .. "\""
                    n = n + 1
                end
            end
            o[n] = ">"
            n = n + 1
            local child = cell.children
            if child then
                if "table" == type(child) then
                    for _, c in ipairs(child) do
                        if "table" == type(c) then
                            convert(c)
                        else
                            o[n] = tostring(c)
                            n = n + 1
                        end
                    end
                else
                    o[n] = tostring(child)
                    n = n + 1
                end
            end
            if not void_tags.has(cell.tag) then
                o[n] = "</" .. cell.tag .. ">"
                n = n + 1
            end
        end
    end
    convert(node)
    return concat(o)
end
return function(func, args, strict)
    local env = {concat = table.concat, insert = table.insert, remove = table.remove}
    env = setmetatable(env, {__index = function(t, name)
        if void_tags.has(name) then
            return function(attrs)
                return void(name, attrs)
            end
        end
        if normal_tags.has(name) then
            return function(attrs, ...)
                return normal(name, attrs, ...)
            end
        end
        if strict then
            error("Unrecognized html5 tag " .. name)
        end
        return _G[name]
    end})
    func = setfenv(func, env)
    local res = func(args)
    return html5(res)
end
