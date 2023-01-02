
import assert_valid from require "lapis.validate"

assert_page = =>
  assert_valid @params, {
    {"page", optional: true, is_integer: true}
  }

  @page = math.max 1, tonumber(@params.page) or 1
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

{:assert_page, :require_current_usre, :convert_arrays}
