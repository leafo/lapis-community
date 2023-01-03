
import types from require "tableshape"
import db_id, db_enum, limited_text, trimmed_text, valid_text, validate_params from require "lapis.validate.types"

import trim from require "lapis.util"

empty = types.one_of({
  types.nil
  types.pattern("^%s*$") / nil
  types.literal(require("cjson").null) / nil
  if ngx
    types.literal(ngx.null) / nil
})\describe "empty"

empty_html = empty + types.custom((str) ->
  import is_empty_html from require "community.helpers.html"
  is_empty_html str
) / nil

color = types.one_of({
  types.pattern "^##{"[a-fA-F%d]"\rep "6"}$"
  types.pattern "^##{"[a-fA-F%d]"\rep "3"}$"
})\describe "hex color"

page_number = types.one_of({
  empty / 1
  types.one_of({
    types.number
    types.string\length(1,10) / trim * types.pattern("^%d+$") / tonumber
  })\describe "an integer"
}) / (n) -> math.floor math.max 1, n

db_nullable = (t) ->
  db = require "lapis.db"
  t + empty / db.NULL

assert_valid = (params, spec, opts) ->
  t = validate_params(spec, opts)\assert_errors!
  t\transform params

{
  :empty, :empty_html
  :color
  :page_number
  :valid_text, :trimmed_text, :limited_text
  :db_id, :db_enum
  :db_nullable

  :assert_valid
}
