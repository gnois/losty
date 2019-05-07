--
-- Generated from now.lt
--
local ffi = require("ffi")
ffi.cdef([[
	typedef long time_t; 
 	typedef struct timeval {
		time_t tv_sec;
		time_t tv_usec;
	} timeval;
	
	int gettimeofday(struct timeval* t, void* tzp);
]])
local tmv = ffi.new("timeval")
return function()
    ffi.C.gettimeofday(tmv, nil)
    return tonumber(tmv.tv_sec) * 1000000 + tonumber(tmv.tv_usec)
end
