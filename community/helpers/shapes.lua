local tableshape = require("tableshape")
local types
types = tableshape.types
local strip_bad_chars
strip_bad_chars = require("community.helpers.unicode").strip_bad_chars
local trim
trim = require("lapis.util").trim
local valid_text = types.string / strip_bad_chars
local trimmed_text = valid_text / trim * types.custom(function(v)
  return v ~= "", "expected text"
end, {
  describe = function()
    return "not empty"
  end
})
local limited_text
limited_text = function(max_len, min_len)
  if min_len == nil then
    min_len = 1
  end
  local out = trimmed_text * types.string:length(min_len, max_len)
  return out:describe("text between " .. tostring(min_len) .. " and " .. tostring(max_len) .. " characters")
end
local empty = types.one_of({
  types["nil"],
  types.pattern("^%s*$") / nil,
  types.literal(require("cjson").null) / nil,
  (function()
    if ngx then
      return types.literal(ngx.null) / nil
    end
  end)()
}, {
  describe = function()
    return "empty"
  end
})
local db_id = types.one_of({
  types.number * types.custom(function(v)
    return v == math.floor(v)
  end),
  types.string / trim * types.pattern("^%d+$") / tonumber
}, {
  describe = function()
    return "integer"
  end
}) * types.range(0, 2147483647):describe("database id")
local db_enum
db_enum = function(e)
  local names = {
    unpack(e)
  }
  return types.one_of({
    types.one_of(names) / (function()
      local _base_0 = e
      local _fn_0 = _base_0.for_db
      return function(...)
        return _fn_0(_base_0, ...)
      end
    end)(),
    (db_id / function(v)
      return e[v] and e:for_db(v)
    end) * db_id
  }, {
    describe = function()
      return "enum(" .. tostring(table.concat(names, ", ")) .. ")"
    end
  })
end
local test_valid
test_valid = function(object, validations)
  local errors
  local out = { }
  local pass, err = types.table(object)
  if not (pass) then
    return nil, {
      err
    }
  end
  for _index_0 = 1, #validations do
    local v = validations[_index_0]
    local key, shape
    key, shape = v[1], v[2]
    local res, state_or_err = shape:_transform(object[key])
    if res == tableshape.FailedTransform then
      local err_msg = v.error or tostring(v.label or key) .. ": " .. tostring(state_or_err)
      if errors then
        table.insert(errors, err_msg)
      else
        errors = {
          err_msg
        }
      end
    else
      out[key] = res
    end
  end
  if errors then
    return nil, errors
  else
    return out
  end
end
local assert_valid
assert_valid = function(...)
  local result, errors = test_valid(...)
  if not (result) then
    coroutine.yield("error", errors)
    error("should have yielded")
  end
  return result
end
return {
  empty = empty,
  valid_text = valid_text,
  trimmed_text = trimmed_text,
  limited_text = limited_text,
  db_id = db_id,
  db_enum = db_enum,
  test_valid = test_valid,
  assert_valid = assert_valid
}
