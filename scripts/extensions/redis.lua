local M = {}

local redis = require "resty.redis"
local os_ext = require "extensions.os"

local host = os_ext.getenv("REDIS_HOST", "redis")
local port = tonumber(os_ext.getenv("REDIS_PORT", 6379))

-- timeout after 30 seconds


-- Ensure you configure the connection pool size properly in the set_keepalive .
-- Basically if your NGINX handle n concurrent requests and your NGINX has m workers,
-- then the connection pool size should be configured as n/m. For example,
-- if your NGINX usually handles 1000 concurrent requests and you have 10 NGINX workers,
-- then the connection pool size should be 100.

local P = {}


function P.pop()
  local red = redis:new()
  red:set_timeout(3000)
  ok, err = red:connect(host, port)
  if not ok then
    return nil, err
  end
  return red, nil
end

function P.put(args)
  if args["red"] == nil then
    return
  end
  ok, err = args["red"]:set_keepalive(30000, 100)
  if not ok then
    return err
  end
  return nil
end

M.pool = P

return M
