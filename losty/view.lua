--
-- Generated from view.lau
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
local match = string.match
local sort = table.sort
local find = string.find
local esc_map = {["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;", ["'"] = "&#39;"}
local esc_text = "[&<>]"
local esc_quote = "[&<>\"']"
local esc = function(txt, quote)
    if nil == txt then
        return ""
    end
    txt = tostring(txt)
    local pattern = esc_text
    if quote then
        pattern = esc_quote
    end
    if nil == find(txt, pattern) then
        return txt
    end
    local out = gsub(txt, pattern, esc_map)
    return out
end
local void_tags = set("area", "base", "br", "col", "command", "embed", "hr", "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr")
local valid_tags = {
    a = true
    , abbr = true
    , address = true
    , area = true
    , article = true
    , aside = true
    , audio = true
    , b = true
    , base = true
    , bdi = true
    , bdo = true
    , blockquote = true
    , body = true
    , br = true
    , button = true
    , canvas = true
    , caption = true
    , cite = true
    , code = true
    , col = true
    , colgroup = true
    , command = true
    , data = true
    , datalist = true
    , dd = true
    , del = true
    , details = true
    , dfn = true
    , dialog = true
    , div = true
    , dl = true
    , dt = true
    , em = true
    , embed = true
    , fieldset = true
    , figcaption = true
    , figure = true
    , footer = true
    , form = true
    , h1 = true
    , h2 = true
    , h3 = true
    , h4 = true
    , h5 = true
    , h6 = true
    , head = true
    , header = true
    , hgroup = true
    , hr = true
    , html = true
    , i = true
    , iframe = true
    , img = true
    , input = true
    , ins = true
    , kbd = true
    , keygen = true
    , label = true
    , legend = true
    , li = true
    , link = true
    , main = true
    , map = true
    , mark = true
    , menu = true
    , meta = true
    , meter = true
    , nav = true
    , noscript = true
    , object = true
    , ol = true
    , optgroup = true
    , option = true
    , output = true
    , p = true
    , param = true
    , picture = true
    , pre = true
    , progress = true
    , q = true
    , rp = true
    , rt = true
    , ruby = true
    , s = true
    , samp = true
    , script = true
    , search = true
    , section = true
    , select = true
    , slot = true
    , small = true
    , source = true
    , span = true
    , strong = true
    , style = true
    , sub = true
    , summary = true
    , sup = true
    , table = true
    , tbody = true
    , td = true
    , template = true
    , textarea = true
    , tfoot = true
    , th = true
    , thead = true
    , time = true
    , title = true
    , tr = true
    , track = true
    , u = true
    , ul = true
    , var = true
    , video = true
    , wbr = true
}
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
    if nil ~= attrs then
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
    local nargs = select("#", ...)
    local attr
    if nargs > 1 then
        local a = args[1]
        local k = type(a)
        if nil == a then
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
        for i = 1, nargs - 1 do
            args[i] = args[i + 1]
        end
        args[nargs] = nil
    end
    local cell = void(tag, attrib)
    cell._children = args
    return cell
end
local attr_name = "^[%w_%-:%.]+$"
local tag_name = "^[%w_%-:]+$"
local max_depth = 256
local raw = function(s)
    if nil == s then
        return {_raw = ""}
    end
    return {_raw = tostring(s)}
end
local markup
markup = function(nodes, depth, validate)
    if nil == depth then
        depth = 1
    elseif depth > max_depth then
        error("markup: nesting too deep (circular reference?)", 2)
    end
    if nil ~= nodes then
        local o, n = {}, 1
        if "table" == type(nodes) then
            if nil ~= nodes._raw then
                o[n] = nodes._raw
                n = n + 1
            elseif nodes and nodes._tag then
                if "string" ~= type(nodes._tag) or not match(nodes._tag, tag_name) then
                    error("Invalid tag name: " .. tostring(nodes._tag), 2)
                end
                if validate and nil == valid_tags[nodes._tag] then
                    error("Invalid html5 tag: " .. nodes._tag, 2)
                end
                o[n] = "<" .. nodes._tag
                n = n + 1
                if nil ~= nodes.attrs then
                    local names = {}
                    local nn = 0
                    for k, v in pairs(nodes.attrs) do
                        if "string" ~= type(k) or not match(k, attr_name) then
                            error("Invalid attribute name: " .. tostring(k), 2)
                        end
                        if "table" == type(v) or "function" == type(v) or "userdata" == type(v) or "thread" == type(v) then
                            error("Invalid value for attribute '" .. k .. "': " .. type(v), 2)
                        end
                        nn = nn + 1
                        names[nn] = k
                    end
                    sort(names)
                    for i = 1, nn do
                        local key = names[i]
                        local val = nodes.attrs[key]
                        if false ~= val then
                            o[n] = " " .. key
                            n = n + 1
                            if "boolean" ~= type(val) then
                                o[n] = "=\"" .. esc(val, true) .. "\""
                                n = n + 1
                            end
                        end
                    end
                end
                o[n] = ">"
                n = n + 1
                if not void_tags.has(nodes._tag) then
                    o[n] = markup(nodes._children, depth + 1, validate)
                    n = n + 1
                    o[n] = "</" .. nodes._tag .. ">"
                    n = n + 1
                end
            else
                for _, c in ipairs(nodes) do
                    o[n] = markup(c, depth + 1, validate)
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
local safe_globals = {
    assert = assert
    , error = error
    , getmetatable = getmetatable
    , ipairs = ipairs
    , math = math
    , next = next
    , pairs = pairs
    , pcall = pcall
    , print = print
    , rawequal = rawequal
    , rawget = rawget
    , rawset = rawset
    , setmetatable = setmetatable
    , string = string
    , tonumber = tonumber
    , tostring = tostring
    , type = type
    , unpack = unpack
    , xpcall = xpcall
}
local view = function(func, args, validate)
    local env = {concat = concat, insert = insert, remove = remove, raw = raw}
    env = setmetatable(env, {__index = function(t, name)
        if void_tags.has(name) then
            return function(attrs, w, x, y, z)
                if w or x or y or z then
                    error(NoChild(name), 2)
                end
                return void(name, attrs)
            end
        end
        local x = safe_globals[name]
        if nil ~= x then
            return x
        end
        return function(...)
            return normal(name, ...)
        end
    end})
    local oldenv
    if "function" == type(func) then
        oldenv = getfenv(func)
        if not pcall(setfenv, func, env) then
            oldenv = nil
        end
    end
    local ok, list = xpcall(function()
        return func(args)
    end, function(err)
        return err
    end)
    if nil ~= oldenv then
        setfenv(func, oldenv)
    end
    if not ok then
        error(list, 2)
    end
    local html = markup(list, 1, validate)
    return html
end
return view
