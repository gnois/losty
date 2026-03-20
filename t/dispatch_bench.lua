local dispatch = require("losty.dispatch")

local function mk_case(name, depth, next_call, init_call, expected)
    local handlers = {}
    for i = 1, depth - 1 do
        handlers[i] = function(q, r, ...)
            return next_call(q, r, ...)
        end
    end
    handlers[depth] = function(q, r, ...)
        return expected
    end

    local req, res = {}, {}

    local run = function()
        return init_call(handlers, req, res)
    end

    return {
        name = name,
        run = run,
        expected = expected,
    }
end

local cases = {
    mk_case(
        "depth4_noargs",
        4,
        function(q)
            return q.next()
        end,
        function(handlers, req, res)
            return dispatch(handlers, req, res)
        end,
        1
    ),
    mk_case(
        "depth8_twoargs_with_nil",
        8,
        function(q)
            return q.next(11, nil)
        end,
        function(handlers, req, res)
            return dispatch(handlers, req, res)
        end,
        2
    ),
    mk_case(
        "depth12_fourargs_mixed_nil",
        12,
        function(q)
            return q.next(nil, 7, nil, 9)
        end,
        function(handlers, req, res)
            return dispatch(handlers, req, res, 5, nil)
        end,
        3
    ),
    mk_case(
        "depth16_onearg",
        16,
        function(q)
            return q.next(42)
        end,
        function(handlers, req, res)
            return dispatch(handlers, req, res)
        end,
        4
    ),
}

local iterations = tonumber(arg[1]) or 200000
local warmup = tonumber(arg[2]) or math.max(10000, math.floor(iterations * 0.1))

local function bench_case(c)
    for _ = 1, warmup do
        c.run()
    end

    local t0 = os.clock()
    local checksum = 0
    for _ = 1, iterations do
        checksum = checksum + c.run()
    end
    local dt = os.clock() - t0
    local ops = iterations / dt

    if checksum ~= c.expected * iterations then
        error("checksum mismatch for " .. c.name .. ": " .. checksum)
    end

    io.write(string.format("%-28s %12.2f ops/s   %8.3f s   checksum=%d\n", c.name, ops, dt, checksum))
end

print("dispatch benchmark")
print(string.format("iterations=%d warmup=%d", iterations, warmup))
if jit then
    print("jit=" .. tostring(jit.status()))
end

for _, c in ipairs(cases) do
    bench_case(c)
end
