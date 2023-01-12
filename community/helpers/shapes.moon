
types = require "lapis.validate.types"
import empty, db_id, db_enum, limited_text, trimmed_text, valid_text, params_shape from types

empty_html = (empty + trimmed_text  * types.custom((str) ->
  import is_empty_html from require "community.helpers.html"
  is_empty_html str
) / nil)\describe "empty html"

color = types.one_of({
  types.pattern "^##{"[a-fA-F%d]"\rep "6"}$"
  types.pattern "^##{"[a-fA-F%d]"\rep "3"}$"
})\describe "hex color"

page_number = (types.empty / 1) + (types.one_of({
  types.number / math.floor
  types.string\length(0,5) * types.pattern("^%d+$") / tonumber
}) * types.range(1, 1000))\describe "page number"

db_nullable = (t) ->
  db = require "lapis.db"
  t + empty / db.NULL

assert_valid = (params, spec, opts) ->
  t = params_shape(spec, opts)\assert_errors!
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
