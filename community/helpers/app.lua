local assert_valid
assert_valid = require("lapis.validate").assert_valid
local assert_page
assert_page = function(self)
  assert_valid(self.params, {
    {
      "page",
      optional = true,
      is_integer = true
    }
  })
  self.page = math.max(1, tonumber(self.params.page) or 1)
  return self.page
end
local require_login
require_login = function(fn)
  local assert_error
  assert_error = require("lapis.application").assert_error
  return function(self, ...)
    assert_error(self.current_user, "you must be logged in")
    return fn(self, ...)
  end
end
local convert_arrays
convert_arrays = function(p)
  local i = 1
  while true do
    local str_i = tostring(i)
    do
      local v = p[str_i]
      if v then
        p[i] = v
        p[str_i] = nil
      else
        break
      end
    end
    i = i + 1
  end
  for k, v in pairs(p) do
    if type(v) == "table" then
      convert_arrays(v)
    end
  end
  return p
end
return {
  assert_page = assert_page,
  require_login = require_login,
  convert_arrays = convert_arrays
}
