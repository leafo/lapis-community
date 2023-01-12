local types = require("lapis.validate.types")
local empty, db_id, db_enum, limited_text, trimmed_text, valid_text, params_shape
empty, db_id, db_enum, limited_text, trimmed_text, valid_text, params_shape = types.empty, types.db_id, types.db_enum, types.limited_text, types.trimmed_text, types.valid_text, types.params_shape
local empty_html = (empty + trimmed_text * types.custom(function(str)
  local is_empty_html
  is_empty_html = require("community.helpers.html").is_empty_html
  return is_empty_html(str)
end) / nil):describe("empty html")
local color = types.one_of({
  types.pattern("^#" .. tostring(("[a-fA-F%d]"):rep("6")) .. "$"),
  types.pattern("^#" .. tostring(("[a-fA-F%d]"):rep("3")) .. "$")
}):describe("hex color")
local page_number = (types.empty / 1) + (types.one_of({
  types.number / math.floor,
  types.string:length(0, 5) * types.pattern("^%d+$") / tonumber
}) * types.range(1, 1000)):describe("page number")
local db_nullable
db_nullable = function(t)
  local db = require("lapis.db")
  return t + empty / db.NULL
end
local assert_valid
assert_valid = function(params, spec, opts)
  local t = params_shape(spec, opts):assert_errors()
  return t:transform(params)
end
return {
  empty = empty,
  empty_html = empty_html,
  color = color,
  page_number = page_number,
  valid_text = valid_text,
  trimmed_text = trimmed_text,
  limited_text = limited_text,
  db_id = db_id,
  db_enum = db_enum,
  db_nullable = db_nullable,
  assert_valid = assert_valid
}
