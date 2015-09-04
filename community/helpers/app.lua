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
  return function(self)
    assert_error(self.current_user, "you must be logged in")
    return fn(self)
  end
end
return {
  assert_page = assert_page,
  require_login = require_login
}
