local with_params
with_params = require("lapis.validate").with_params
local shapes = require("community.helpers.shapes")
local assert_page = with_params({
  {
    "page",
    shapes.page_number
  }
}, function(self, params)
  self.page = params.page
  return self.page
end)
local require_current_user
require_current_user = function(fn)
  local assert_error
  assert_error = require("lapis.application").assert_error
  return function(self, ...)
    assert_error(self.current_user, "you must be logged in")
    return fn(self, ...)
  end
end
return {
  assert_page = assert_page,
  require_current_user = require_current_user
}
