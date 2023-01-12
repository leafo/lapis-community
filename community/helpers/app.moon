
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

-- convert string array indxes into numbers for post params
-- modifies in place
convert_arrays = (p) ->
  i = 1
  while true
    str_i = "#{i}"
    if v = p[str_i]
      p[i] = v
      p[str_i] = nil
    else
      break
    i += 1

  for k,v in pairs p
    if type(v) == "table"
      convert_arrays v

  p

{:assert_page, :require_current_user, :convert_arrays}
