local types
types = require("tableshape").types
local db_id, db_enum, limited_text, trimmed_text, valid_text, validate_params
do
  local _obj_0 = require("lapis.validate.types")
  db_id, db_enum, limited_text, trimmed_text, valid_text, validate_params = _obj_0.db_id, _obj_0.db_enum, _obj_0.limited_text, _obj_0.trimmed_text, _obj_0.valid_text, _obj_0.validate_params
end
local trim
trim = require("lapis.util").trim
local empty = types.one_of({
  types["nil"],
  types.pattern("^%s*$") / nil,
  types.literal(require("cjson").null) / nil,
  (function()
    if ngx then
      return types.literal(ngx.null) / nil
    end
  end)()
}):describe("empty")
local empty_html = empty + types.custom(function(str)
  local is_empty_html
  is_empty_html = require("community.helpers.html").is_empty_html
  return is_empty_html(str)
end) / nil
local color = types.one_of({
  types.pattern("^#" .. tostring(("[a-fA-F%d]"):rep("6")) .. "$"),
  types.pattern("^#" .. tostring(("[a-fA-F%d]"):rep("3")) .. "$")
}):describe("hex color")
local page_number = types.one_of({
  empty / 1,
  types.one_of({
    types.number,
    types.string:length(1, 10) / trim * types.pattern("^%d+$") / tonumber
  }):describe("an integer")
}) / function(n)
  return math.floor(math.max(1, n))
end
local db_nullable
db_nullable = function(t)
  local db = require("lapis.db")
  return t + empty / db.NULL
end
local assert_valid
assert_valid = function(params, spec, opts)
  local t = validate_params(spec, opts):assert_errors()
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
