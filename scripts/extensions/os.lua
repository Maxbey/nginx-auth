local M = {}

function M.getenv(env, default)
  -- same as os.getenv, just that a default value can be passed
  -- if 'env' doesn't exist, the default is returned 
  ngx.log(ngx.INFO, string.format("trying to get env '%s'", env))
  local value = os.getenv(env)
  if value ~= nil then
    ngx.log(ngx.INFO, string.format("env variable '%s' value is '%s'", env, value))
    return value
  end

  ngx.log(ngx.INFO, string.format("no value for env '%s', returning default: '%s'. maybe you forgot to add 'env %s;' to nginx.conf?", env, default, env))
  return default
end

return M
