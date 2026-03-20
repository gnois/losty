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
local esc = function(txt, quote)
    if txt == nil then
        return ""
    end
    txt = tostring(txt)
    txt = gsub(txt, "&", "&amp;")
    txt = gsub(txt, "<", "&lt;")
    txt = gsub(txt, ">", "&gt;")
    if quote then
        txt = gsub(txt, "\"", "&quot;")
        txt = gsub(txt, "'", "&#39;")
    end
    return txt
end
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
                    error(msg .. " attribute must start with `.` or `#` or `[`", 2)
                end
            end
        elseif "table" == kind then
            if attrs[1] then
                error(NoChild(tag), 2)
            end
            for key, val in pairs(attrs) do
                if key == "_tag" then
                    error(NoChild(tag), 2)
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
            error("Attribute must be a table or a string: " .. msg, 2)
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
                        o[n] = "=\"" .. esc(v, true) .. "\""
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
            o[n] = esc(nodes)
            n = n + 1
        end
        return concat(o)
    end
    return ""
end
local view = function(func, args)
    local env = {concat = concat, insert = insert, remove = remove}
    env = setmetatable(env, {__index = function(t, name)
        if void_tags.has(name) then
            return function(attrs, w, x, y, z)
                if w or x or y or z then
                    error(NoChild(name), 2)
                end
                return void(name, attrs)
            end
        end
        local x = _G[name]
        if x then
            return x
        end
        return function(...)
            return normal(name, ...)
        end
    end})
    local oldenv = getfenv(func)
    setfenv(func, env)
    local ok, list = xpcall(function()
        return func(args)
    end, function(err)
        return err
    end)
    setfenv(func, oldenv)
    if not ok then
        error(list, 2)
    end
    local html = markup(list)
    return html
end
local test = function()
    local v = function(fn, a)
        return view(fn, a, true)
    end
    local as = assert
    local pr = print
    as(v(function()
        return br()
    end) == "<br>")
    as(v(function()
        return br(nil)
    end) == "<br>")
    as(v(function()
        return br("")
    end) == "<br>")
    as(v(function()
        return br({})
    end) == "<br>")
    local htm = v(function()
        return img({src = "/a.png", alt = "A"})
    end)
    as(htm == "<img alt=\"A\" src=\"/a.png\">" or htm == "<img src=\"/a.png\" alt=\"A\">")
    as(pcall(v, function()
        return hr(hr())
    end) == false)
    as(pcall(v, function()
        return hr({div(), span()})
    end) == false)
    as(v(function()
        return div()
    end) == "<div></div>")
    as(v(function()
        return div("foo")
    end) == "<div>foo</div>")
    as(v(function()
        return div(".foo", "")
    end) == "<div class=\"foo\"></div>")
    as(pcall(v, function()
        return div("   .foo", "")
    end) == false)
    as(v(function()
        return div("#id1.foo", "")
    end) == "<div class=\"foo\" id=\"id1\"></div>")
    as(v(function()
        return div("[class=foo][title=bar]", {})
    end) == "<div title=\"bar\" class=\"foo\"></div>")
    as(v(function()
        return div("[id=id1][title='bar']", "x")
    end) == "<div title=\"bar\" id=\"id1\">x</div>")
    as(v(function()
        return div("[title=\"bar\"]", 1)
    end) == "<div title=\"bar\">1</div>")
    as(v(function()
        return p(h1("blog"))
    end) == "<p><h1>blog</h1></p>")
    as(v(function()
        return nav(span("z"), span(1), span(false))
    end) == "<nav><span>z</span><span>1</span><span>false</span></nav>")
    as(v(function()
        return p({"AA", mark("mk")}, "YY", "ZZ")
    end) == "<p>AA<mark>mk</mark>YYZZ</p>")
    as(v(function()
        return p({"AA", mark("mk"), "ZZ"})
    end) == "<p>AA<mark>mk</mark>ZZ</p>")
    as(v(function()
        return ul({li("item1"), li("item2")})
    end) == "<ul><li>item1</li><li>item2</li></ul>")
    as(v(function()
        return a({href = "/"}, strong(nil, "Home"))
    end) == "<a href=\"/\"><strong>Home</strong></a>")
    as(v(function()
        return {img("[src=/img/tmp file.png]"), span("span1")}
    end) == "<img src=\"/img/tmp file.png\"><span>span1</span>")
    as(v(function()
        return {"AAA", "bbb", p("para")}
    end) == "AAAbbb<p>para</p>")
    print("pass")
end
test()
return view
