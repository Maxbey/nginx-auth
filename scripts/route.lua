local M = {}
local redis = require "extensions.redis"
local cjson = require "cjson"

function M.add_client(svc, client)
  -- add a new client. used for debugging purposes
  -- the clients are saved in a set
  -- to make sure there are no duplicates
  local red, err = redis.pool:pop()
  if err ~= nil then
    ngx.log(ngx.WARN, "can't add client: " .. err)
    return
  end
  red:sadd(svc, client)
  redis.pool:put({args=red})
end


function M.client_authorized(svc, client)
  local authorized = false
  local red, err = redis.pool:pop()
  if err ~= nil then
    ngx.log(ngx.WARN, "can't access redis: " .. err)
    redis.pool:put({args=red})
    return authorized
  end
  authorized, err = red:sismember(svc, client)
  if err ~= nil then
    ngx.log(ngx.WARN, "can't access members redis: " .. err)
    redis.pool:put({args=red})
    return authorized
  end

  redis.pool:put({args=red})

  return authorized ~= 0
end

function M.authorize(svc)
  -- gets the route for this request
  -- the route is based on the Json Web Token (JWT)
  -- that was passed in the request headers
  -- each JWT should contain the following:
  -- { "service": "foo", "client": "bar" }
  -- the following steps take place once this function is invoked:
  -- 1. The request token is decrypted
  -- 2. The token schema is verified
  -- 3. A check is made wether the client embedded
  --    in the token is still registered
  -- 4. The route for the service that was embedded in the token
  --    is returned.

  local jwt = require("nginx-jwt")
  local data = jwt.auth({
      client="^.+$",
      service=function (s) return s == svc end
  })
  -- now that we know the service exists,
  -- we need to check that the salt is still active

  local c = data["client"]
  if not M.client_authorized(svc, c) then
    ngx.log(ngx.WARN, string.format("client '%s' is not authorized to access service '%s'", client, svc))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  ngx.log(ngx.INFO, string.format("client '%s' is authorized to access service '%s'", c, svc))
end

return M
