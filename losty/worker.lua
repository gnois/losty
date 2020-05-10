--
-- Generated from worker.lt
--
ngx.update_time()
local seed = ngx.now() % 1 * 11111 % 1 * 11111 * ngx.worker.pid()
math.randomseed(seed)
