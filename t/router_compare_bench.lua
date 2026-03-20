local losty_router = require("losty.router")
local regex_router_mod = require("t.regex-router")

local METHOD = "GET"

local function build_routes()
    local routes = {}

    routes[#routes + 1] = { losty = "/", regex = "/", id = 1 }
    routes[#routes + 1] = { losty = "/health", regex = "/health", id = 2 }

    for i = 1, 120 do
        local p = "/static/" .. i
        routes[#routes + 1] = { losty = p, regex = p, id = 1000 + i }
    end

    for i = 1, 80 do
        routes[#routes + 1] = {
            losty = "/users/:%d+/orders/:%d+/r" .. i,
            regex = "/users/:id/orders/:oid/r" .. i,
            id = 2000 + i,
        }
    end

    for i = 1, 50 do
        routes[#routes + 1] = {
            losty = "/api/:%a+/:%a+/:%a+/v" .. i,
            regex = "/api/:a/:b/:c/v" .. i,
            id = 3000 + i,
        }
    end

    return routes
end

local ROUTES = build_routes()

local function build_losty(routes)
    local r = losty_router()
    for i = 1, #routes do
        local it = routes[i]
        r.set(METHOD, it.losty, it.id)
    end

    return function(path)
        local arr = r.match(METHOD, path, false)
        if arr then
            return arr[1]
        end
        return 0
    end
end

local function build_regex(routes)
    local r = regex_router_mod.new()
    for i = 1, #routes do
        local it = routes[i]
        r:add(METHOD, it.regex, it.id)
    end

    return function(path)
        local m = r:match(METHOD, path)
        if m then
            return m.handler
        end
        return 0
    end
end

local probes = {
    { name = "exact_hot", path = "/static/77" },
    { name = "param_mid", path = "/users/120/orders/9/r33" },
    { name = "param_deep", path = "/api/foo/bar/baz/v21" },
    { name = "not_found", path = "/x/y/z" },
}

local function build_mixed_paths()
    local paths = {}

    for i = 1, 120 do
        paths[#paths + 1] = "/static/" .. i
    end

    for i = 1, 80 do
        local uid = 1000 + i
        local oid = 2000 + i
        paths[#paths + 1] = "/users/" .. uid .. "/orders/" .. oid .. "/r" .. i
    end

    for i = 1, 50 do
        paths[#paths + 1] = "/api/foo/bar/baz/v" .. i
    end

    for i = 1, 90 do
        paths[#paths + 1] = "/missing/" .. i
    end

    return paths
end

local MIXED_PATHS = build_mixed_paths()

local iterations = tonumber(arg[1]) or 300000
local warmup = tonumber(arg[2]) or math.max(20000, math.floor(iterations * 0.1))
local mode = arg[3] or "all"

local runners = {
    { name = "losty.router", fn = build_losty(ROUTES) },
    { name = "regex-router", fn = build_regex(ROUTES) },
}

local function bench_one(router_name, fn, c)
    for _ = 1, warmup do
        fn(c.path)
    end

    local t0 = os.clock()
    local checksum = 0
    for _ = 1, iterations do
        checksum = checksum + fn(c.path)
    end
    local dt = os.clock() - t0
    local ops = iterations / dt

    io.write(string.format("%-13s %-10s %12.2f ops/s   %8.3f s   checksum=%d\n", router_name, c.name, ops, dt, checksum))
end

local function bench_mixed(router_name, fn, paths)
    local plen = #paths

    for i = 1, warmup do
        fn(paths[((i - 1) % plen) + 1])
    end

    local t0 = os.clock()
    local checksum = 0
    for i = 1, iterations do
        checksum = checksum + fn(paths[((i - 1) % plen) + 1])
    end
    local dt = os.clock() - t0
    local ops = iterations / dt

    io.write(string.format("%-13s %-10s %12.2f ops/s   %8.3f s   checksum=%d\n", router_name, "mixed", ops, dt, checksum))
end

print("router compare benchmark")
print(string.format("routes=%d mixed_paths=%d iterations=%d warmup=%d mode=%s", #ROUTES, #MIXED_PATHS, iterations, warmup, mode))
if jit then
    print("jit=" .. tostring(jit.status()))
end

for i = 1, #runners do
    local r = runners[i]
    if mode == "single" or mode == "all" then
        for j = 1, #probes do
            bench_one(r.name, r.fn, probes[j])
        end
    end
    if mode == "mixed" or mode == "all" then
        bench_mixed(r.name, r.fn, MIXED_PATHS)
    end
end
