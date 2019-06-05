--
-- Generated from view.lt
--
local tbl = require("losty.tbl")
local set = require("losty.set")
local concat = table.concat
local remove = table.remove
local insert = table.insert
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
local NoChild = function(tag)
    return "<" .. tag .. "> cannot have child element"
end
local void = function(tag, attrs)
    local cell = {_tag = tag, attrs = {}}
    local classes, n = {}, 1
    if attrs ~= nil then
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
            if attrs[1] then
                error(NoChild(tag))
            end
            for key, val in pairs(attrs) do
                if key == "_tag" then
                    error(NoChild(tag))
                end
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
            local msg = tag .. "(" .. kind .. ")"
            error("Attribute must be a table or a string: " .. msg)
        end
    end
    if classes[1] then
        cell.attrs["class"] = concat(classes, " ")
    end
    return cell
end
local normal = function(tag, ...)
    local args = {...}
    local attr
    if args[2] then
        local a = args[1]
        local k = type(a)
        if a == nil then
            attr = true
        elseif "string" == k then
            attr = true
        elseif "table" == k then
            attr = a[1] == nil and a._tag == nil
        end
    end
    local attrib
    if attr then
        attrib = args[1]
        remove(args, 1)
    end
    local cell = void(tag, attrib)
    cell._children = args
    return cell
end
local markup
markup = function(nodes)
    if nodes ~= nil then
        local o, n = {}, 1
        if "table" == type(nodes) then
            if nodes and nodes._tag then
                o[n] = "<" .. nodes._tag
                n = n + 1
                for k, v in pairs(nodes.attrs) do
                    o[n] = " " .. k
                    n = n + 1
                    if "boolean" ~= type(v) then
                        o[n] = "=\"" .. v .. "\""
                        n = n + 1
                    end
                end
                o[n] = ">"
                n = n + 1
                if not void_tags.has(nodes._tag) then
                    o[n] = markup(nodes._children)
                    n = n + 1
                    o[n] = "</" .. nodes._tag .. ">"
                    n = n + 1
                end
            else
                for _, c in ipairs(nodes) do
                    o[n] = markup(c)
                    n = n + 1
                end
            end
        else
            o[n] = tostring(nodes)
            n = n + 1
        end
        return concat(o)
    end
    return ""
end
local view = function(func, args, naked, strict)
    local env = {concat = concat, insert = insert, remove = remove}
    env = setmetatable(env, {__index = function(t, name)
        if void_tags.has(name) then
            return function(attrs, w, x, y, z)
                if w or x or y or z then
                    error(NoChild(name))
                end
                return void(name, attrs)
            end
        end
        if normal_tags.has(name) then
            return function(...)
                return normal(name, ...)
            end
        end
        if strict then
            error("Unrecognized html5 tag <" .. name .. ">")
        end
        return _G[name]
    end})
    func = setfenv(func, env)
    local list = func(args)
    local html = markup(list)
    if naked then
        return html
    end
    return "<!DOCTYPE html> " .. html
end
return view
