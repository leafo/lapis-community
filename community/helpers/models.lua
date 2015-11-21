local db = require("lapis.db")
local next, unpack, ipairs, pairs
do
  local _obj_0 = _G
  next, unpack, ipairs, pairs = _obj_0.next, _obj_0.unpack, _obj_0.ipairs, _obj_0.pairs
end
local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local filter_update
filter_update = function(model, update)
  for key, val in pairs(update) do
    if model[key] == val then
      update[key] = nil
    end
    if val == db.NULL and model[key] == nil then
      update[key] = nil
    end
  end
  return update
end
local safe_insert
safe_insert = function(self, data, check_cond)
  if check_cond == nil then
    check_cond = data
  end
  local table_name = db.escape_identifier(self:table_name())
  if self.timestamp then
    do
      local _tbl_0 = { }
      for k, v in pairs(data) do
        _tbl_0[k] = v
      end
      data = _tbl_0
    end
    local time = db.format_date()
    data.created_at = time
    data.updated_at = time
  end
  local columns
  do
    local _accum_0 = { }
    local _len_0 = 1
    for key in pairs(data) do
      _accum_0[_len_0] = key
      _len_0 = _len_0 + 1
    end
    columns = _accum_0
  end
  local values
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #columns do
      local col = columns[_index_0]
      _accum_0[_len_0] = db.escape_literal(data[col])
      _len_0 = _len_0 + 1
    end
    values = _accum_0
  end
  for i, col in ipairs(columns) do
    columns[i] = db.escape_identifier(col)
  end
  local q = concat({
    "insert into",
    table_name,
    "(",
    concat(columns, ", "),
    ")",
    "select",
    concat(values, ", "),
    "where not exists ( select 1 from",
    table_name,
    "where",
    db.encode_clause(check_cond),
    ") returning *"
  }, "  ")
  local res = db.query(q)
  if next(res) then
    return self:load((unpack(res)))
  else
    return nil, "already exists"
  end
end
local upsert
upsert = function(model, insert, update, cond)
  local table_name = db.escape_identifier(model:table_name())
  local primary_keys = {
    model:primary_keys()
  }
  local is_primary_key
  do
    local _tbl_0 = { }
    for _index_0 = 1, #primary_keys do
      local k = primary_keys[_index_0]
      _tbl_0[k] = true
    end
    is_primary_key = _tbl_0
  end
  if not (update) then
    do
      local _tbl_0 = { }
      for k, v in pairs(insert) do
        if not is_primary_key[k] then
          _tbl_0[k] = v
        end
      end
      update = _tbl_0
    end
  end
  if not (cond) then
    do
      local _tbl_0 = { }
      for k, v in pairs(insert) do
        if is_primary_key[k] then
          _tbl_0[k] = v
        end
      end
      cond = _tbl_0
    end
  end
  if model.timestamp then
    local time = db.format_date()
    update.updated_at = time
    insert.created_at = time
    insert.updated_at = time
  end
  local insert_fields
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k in pairs(insert) do
      _accum_0[_len_0] = k
      _len_0 = _len_0 + 1
    end
    insert_fields = _accum_0
  end
  local insert_values
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #insert_fields do
      local k = insert_fields[_index_0]
      _accum_0[_len_0] = db.escape_literal(insert[k])
      _len_0 = _len_0 + 1
    end
    insert_values = _accum_0
  end
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #insert_fields do
      local k = insert_fields[_index_0]
      _accum_0[_len_0] = db.escape_identifier(k)
      _len_0 = _len_0 + 1
    end
    insert_fields = _accum_0
  end
  assert(next(insert_fields), "no fields to insert for upsert")
  local res = db.query("\n    with updates as (\n      update " .. tostring(table_name) .. "\n      set " .. tostring(db.encode_assigns(update)) .. "\n      where " .. tostring(db.encode_clause(cond)) .. "\n      returning *\n    ),\n    inserts as (\n      insert into " .. tostring(table_name) .. " (" .. tostring(concat(insert_fields, ", ")) .. ")\n      select " .. tostring(concat(insert_values, ", ")) .. "\n      where not exists(select 1 from updates)\n      returning *\n    )\n    select *, 'update' as _upsert_type from updates\n    union\n    select *, 'insert' as _upsert_type from inserts\n  ")
  res = unpack(res)
  local upsert_type = res._upsert_type
  res._upsert_type = nil
  return upsert_type, model:load(res)
end
local soft_delete
soft_delete = function(self)
  local primary = self:_primary_cond()
  primary.deleted = false
  local res = db.update(self.__class:table_name(), {
    deleted = true
  }, primary)
  return res.affected_rows and res.affected_rows > 0
end
local memoize1
memoize1 = function(fn)
  local NIL = { }
  local cache = setmetatable({ }, {
    __mode = "k"
  })
  return function(self, arg, more)
    if more then
      error("memoize1 function recieved second argument")
    end
    local key
    if arg == nil then
      key = NIL
    else
      key = arg
    end
    local cache_value = cache[self] and cache[self][key]
    if cache_value then
      return unpack(cache_value)
    end
    local res = {
      fn(self, arg)
    }
    if not (cache[self]) then
      cache[self] = setmetatable({ }, {
        __mode = "k"
      })
    end
    cache[self][key] = res
    return unpack(res)
  end
end
return {
  upsert = upsert,
  safe_insert = safe_insert,
  filter_update = filter_update,
  soft_delete = soft_delete,
  memoize1 = memoize1
}
