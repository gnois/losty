local M = {}
M.__index = M

local function split_path(path)
  local parts = {}
  for segment in string.gmatch(path, "[^/]+") do
    parts[#parts + 1] = segment
  end
  return parts
end

local function compile_pattern(path)
  local keys = {}
  local pattern = "^"

  if path == "/" then
    return "^/$", keys
  end

  for segment in string.gmatch(path, "[^/]+") do
    if string.sub(segment, 1, 1) == ":" then
      keys[#keys + 1] = string.sub(segment, 2)
      pattern = pattern .. "/([^/]+)"
    else
      pattern = pattern .. "/" .. segment
    end
  end

  pattern = pattern .. "$"
  return pattern, keys
end

function M.new()
  return setmetatable({
    routes = {},
  }, M)
end

function M:add(method, path, handler)
  local pattern, keys = compile_pattern(path)
  self.routes[#self.routes + 1] = {
    method = method,
    path = path,
    pattern = pattern,
    keys = keys,
    handler = handler,
  }
end

function M:match(method, path)
  for _, route in ipairs(self.routes) do
    if route.method == method then
      local captures = { string.match(path, route.pattern) }
      if #captures > 0 or path == route.path then
        local params = {}
        for idx, key in ipairs(route.keys) do
          params[key] = captures[idx]
        end
        return {
          handler = route.handler,
          method = route.method,
          path = route.path,
          params = params,
        }
      end
    end
  end

  return nil
end

return M
