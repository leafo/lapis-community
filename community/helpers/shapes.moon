
tableshape = require "tableshape"
import types from tableshape

import strip_bad_chars from require "community.helpers.unicode"
import trim from require "lapis.util"

-- valid utf8, bad chars removed
valid_text = types.string / strip_bad_chars

trimmed_text = valid_text / trim * types.custom(
  (v) -> v != "", "expected text"
  describe: -> "not empty"
)

limited_text = (max_len, min_len=1) ->
  out = trimmed_text * types.string\length min_len, max_len
  out\describe "text between #{min_len} and #{max_len} characters"

empty = types.one_of {
  types.nil
  types.pattern("^%s*$") / nil
  types.literal(require("cjson").null) / nil
  if ngx
    types.literal(ngx.null) / nil
}, describe: -> "empty"

color = types.one_of({
  types.pattern "^##{"[a-fA-F%d]"\rep "6"}$"
  types.pattern "^##{"[a-fA-F%d]"\rep "3"}$"
})\describe "hex color"

page_number = types.one_of({
  empty / 1
  types.one_of({
    types.number
    types.string / trim * types.pattern("^%d+$") / tonumber
  })\describe "an integer"
}) / (n) -> math.floor math.max 1, n

db_id = types.one_of({
  types.number * types.custom (v) -> v == math.floor(v)
  types.string / trim * types.pattern("^%d+$") / tonumber
}, describe: -> "integer") * types.range(0, 2147483647)\describe "database id"

db_enum = (e) ->
  names = {unpack e}

  types.one_of {
    types.one_of(names) / e\for_db
    (db_id / (v) -> e[v] and e\for_db v) * db_id
  }, describe: ->
    "enum(#{table.concat names, ", "})"

test_valid = (object, validations, opts) ->
  local errors
  out = {}

  pass, err = types.table object
  unless pass
    return nil, {err}

  for v in *validations
    {key, shape} = v
    res, state_or_err = shape\_transform object[key]

    if res == tableshape.FailedTransform
      err_msg = v.error or "#{v.label or key}: #{state_or_err}"
      if opts and opts.prefix
        err_msg = "#{opts.prefix}: #{err_msg}"

      if errors
        table.insert errors, err_msg
      else
        errors = { err_msg }
    else
      out[key] = res

  if errors
    nil, errors
  else
    out

assert_valid = (...) ->
  result, errors = test_valid ...
  unless result
    coroutine.yield "error", errors
    error "should have yielded"

  result

{
  :empty
  :color
  :page_number
  :valid_text, :trimmed_text, :limited_text
  :db_id, :db_enum

  :test_valid, :assert_valid
}
