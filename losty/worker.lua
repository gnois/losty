--
-- Generated from worker.lt
--
ngx.update_time()
math.randomseed(ngx.now() * 1000 + ngx.worker.pid())
