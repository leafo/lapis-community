
import with_params from require "lapis.validate"
shapes = require "community.helpers.shapes"

assert_page = with_params {
  {"page", shapes.page_number}
}, (params) =>
  @page = params.page
  @page

require_current_user = (fn) ->
  import assert_error from require "lapis.application"
  (...) =>
    assert_error @current_user, "you must be logged in"
    fn @, ...

{:assert_page, :require_current_user}
