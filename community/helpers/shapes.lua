local types = require("lapis.validate.types")
local empty_html = (types.empty + types.trimmed_text * types.custom(function(str)
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
local parse_utc_datetime
parse_utc_datetime = function(str)
  local day, time, fraction, zone = str:match("^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d:%d%d)([%.%d]*)(.*)$")
  if not (day) then
    return nil
  end
  if not (fraction == "" or fraction:match("^%.%d+$")) then
    return nil
  end
  local offset_minutes
  if zone == "Z" then
    offset_minutes = 0
  else
    local sign, h, m = zone:match("^([+-])(%d%d):(%d%d)$")
    if not (sign) then
      return nil
    end
    h, m = tonumber(h), tonumber(m)
    if h > 14 or m > 59 then
      return nil
    end
    offset_minutes = (h * 60 + m) * (sign == "-" and -1 or 1)
  end
  local date = require("date")
  local local_str = tostring(day) .. " " .. tostring(time)
  local ok, d = pcall(date, local_str)
  if not (ok and d) then
    return nil
  end
  if not (d:fmt("%Y-%m-%d %H:%M:%S") == local_str) then
    return nil
  end
  d:addminutes(-offset_minutes)
  return d:fmt("%Y-%m-%d %H:%M:%S")
end
local utc_datetime = (types.string / parse_utc_datetime * types.string):describe("ISO 8601 date with timezone")
local db_nullable
db_nullable = function(t)
  local db = require("lapis.db")
  return t + types.empty / db.NULL
end
local default
default = function(value)
  if type(value) == "table" then
    error("You used table for default value. In order to prevent you from accidentally sharing the same reference across many requests you must pass a function that returns the table")
  end
  return types.empty / value + types.any
end
local convert_array = types.table / function(t)
  local result = { }
  local i = 1
  while true do
    local str_i = tostring(i)
    do
      local v = t[str_i] or t[i]
      if v then
        result[i] = v
      else
        break
      end
    end
    i = i + 1
  end
  return result
end
return {
  empty_html = empty_html,
  color = color,
  page_number = page_number,
  utc_datetime = utc_datetime,
  db_nullable = db_nullable,
  default = default,
  convert_array = convert_array
}
