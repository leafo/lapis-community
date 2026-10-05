types = require "lapis.validate.types"

empty_html = (types.empty + types.trimmed_text  * types.custom((str) ->
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

parse_utc_datetime = (str) ->
  day, time, fraction, zone = str\match "^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d:%d%d)([%.%d]*)(.*)$"
  return nil unless day
  return nil unless fraction == "" or fraction\match "^%.%d+$"

  offset_minutes = if zone == "Z"
    0
  else
    sign, h, m = zone\match "^([+-])(%d%d):(%d%d)$"
    return nil unless sign
    h, m = tonumber(h), tonumber(m)
    return nil if h > 14 or m > 59
    (h * 60 + m) * (sign == "-" and -1 or 1)

  date = require "date"
  local_str = "#{day} #{time}"
  ok, d = pcall date, local_str
  return nil unless ok and d

  -- date rolls out of range fields over instead of failing, eg. month 13
  return nil unless d\fmt("%Y-%m-%d %H:%M:%S") == local_str

  d\addminutes -offset_minutes
  d\fmt "%Y-%m-%d %H:%M:%S"

-- timezone is required, a bare time would be ambiguous
utc_datetime = (types.string / parse_utc_datetime * types.string)\describe "ISO 8601 date with timezone"

db_nullable = (t) ->
  db = require "lapis.db"
  t + types.empty / db.NULL

default = (value) ->
  if type(value) == "table"
    error "You used table for default value. In order to prevent you from accidentally sharing the same reference across many requests you must pass a function that returns the table"

  types.empty / value + types.any

-- this will create a copy of the table with all string sequential integer
-- fields converted to numbers, essentially extracting the array from the
-- table. Any other fields will be dropped
convert_array = types.table / (t) ->
  result = {}
  i = 1

  while true
    str_i = "#{i}"
    if v = t[str_i] or t[i]
      result[i] = v
    else
      break

    i += 1

  result


{
  :empty_html
  :color
  :page_number
  :utc_datetime
  :db_nullable
  :default
  :convert_array
}
