--
-- Generated from schedule.lt
--
local SecPerDay = 24 * 60 * 60
local day_at = function(ndays, hh, mm, ss)
    local later = os.time() + ndays * SecPerDay
    local t = os.date("*t", later)
    t.hour = hh
    t.min = mm or 0
    t.sec = ss or 0
    t.yday = nil
    t.wday = nil
    return os.time(t)
end
local task
task = function(premature, cycle, fn, ...)
    if premature then
        ngx.log(ngx.WARN, "schedule task premature end at worker ", ngx.worker.id())
    else
        fn(...)
        if cycle and cycle > 0 then
            local ok, err = ngx.timer.every(cycle, fn, ...)
            if not ok then
                ngx.log(ngx.ERR, "ngx.timer.every() failed: ", err)
            end
        end
    end
end
return function(worker, cycle, ndays, hh, mm, ss, fn, ...)
    if ngx.worker.id() == worker then
        local later = day_at(ndays, hh, mm, ss)
        local wait = later - os.time()
        if wait < 0 then
            wait = wait + SecPerDay
        end
        local ok, err = ngx.timer.at(wait, task, cycle, fn, ...)
        if not ok then
            ngx.log(ngx.ERR, "ngx.timer.at() failed at worker ", worker, ": ", err)
        end
    end
end
