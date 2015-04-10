
import assert_valid from require "lapis.validate"

assert_page = =>
  assert_valid @params, {
    {"page", optional: true, is_integer: true}
  }

  @page = math.max 1, tonumber(@params.page) or 1
  @page

require_login = (fn) ->
  import assert_error from require "lapis.application"
  =>
    assert_error @current_user, "you must be logged in"
    fn @

{:assert_page, :require_login}
