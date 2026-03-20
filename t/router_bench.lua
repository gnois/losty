local router = require("losty.router")

local function build_router()
    local r = router()
    local G = "GET"

    r.set(G, "/", 1)
    r.set(G, "/health", 2)

    for i = 1, 80 do
        r.set(G, "/static/" .. i, i)
    end

    for i = 1, 60 do
        r.set(G, "/page/:%d+/item/:%a+/v" .. i, 1000 + i)
    end

    for i = 1, 40 do
        r.set(G, "/api/:%a+/:%d+/:%w+/r" .. i, 2000 + i)
    end

    return r
end

local rt = build_router()
local method = "GET"

local cases = {
    {
        name = "exact_hot",
        path = "/static/40",
        expected = 40,
    },
    {
        name = "pattern_short",
        path = "/page/1234/item/alpha/v22",
        expected = 1022,
    },
    {
        name = "pattern_deep",
        path = "/api/users/9876/token99/r33",
        expected = 2033,
    },
    {
        name = "not_found",
        path = "/missing/route",
        expected = 0,
    },
}

local iterations = tonumber(arg[1]) or 300000
local warmup = tonumber(arg[2]) or math.max(10000, math.floor(iterations * 0.1))

local function run_case(c)
    for _ = 1, warmup do
        rt.match(method, c.path)
    end

    local t0 = os.clock()
    local checksum = 0
    for _ = 1, iterations do
        local arr = rt.match(method, c.path)
        if arr then
            checksum = checksum + arr[1]
        end
    end
    local dt = os.clock() - t0
    local ops = iterations / dt

    local expected_sum = c.expected * iterations
    if checksum ~= expected_sum then
        error("checksum mismatch for " .. c.name .. ": " .. checksum .. " ~= " .. expected_sum)
    end

    io.write(string.format("%-16s %12.2f ops/s   %8.3f s   checksum=%d\n", c.name, ops, dt, checksum))
end

print("router benchmark")
print(string.format("iterations=%d warmup=%d", iterations, warmup))
if jit then
    print("jit=" .. tostring(jit.status()))
end

for _, c in ipairs(cases) do
    run_case(c)
end
