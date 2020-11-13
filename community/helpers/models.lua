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
      error("memoize1 function received second argument")
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
local insert_on_conflict_ignore
insert_on_conflict_ignore = function(model, opts)
  local encode_values, encode_assigns
  do
    local _obj_0 = require("lapis.db")
    encode_values, encode_assigns = _obj_0.encode_values, _obj_0.encode_assigns
  end
  local full_insert = { }
  if opts then
    for k, v in pairs(opts) do
      full_insert[k] = v
    end
  end
  if model.timestamp then
    local d = db.format_date()
    full_insert.created_at = d
    full_insert.updated_at = d
  end
  local buffer = {
    "insert into ",
    db.escape_identifier(model:table_name()),
    " "
  }
  encode_values(full_insert, buffer)
  insert(buffer, " on conflict do nothing returning *")
  local q = concat(buffer)
  local res = db.query(q)
  if res.affected_rows and res.affected_rows > 0 then
    return model:load(res[1])
  else
    return nil, res
  end
end
local insert_on_conflict_update
insert_on_conflict_update = function(model, primary, create, update, opts)
  local encode_values, encode_assigns
  do
    local _obj_0 = require("lapis.db")
    encode_values, encode_assigns = _obj_0.encode_values, _obj_0.encode_assigns
  end
  local full_insert
  do
    local _tbl_0 = { }
    for k, v in pairs(primary) do
      _tbl_0[k] = v
    end
    full_insert = _tbl_0
  end
  if create then
    for k, v in pairs(create) do
      full_insert[k] = v
    end
  end
  local full_update = update or (function()
    local _tbl_0 = { }
    for k, v in pairs(full_insert) do
      if not primary[k] then
        _tbl_0[k] = v
      end
    end
    return _tbl_0
  end)()
  if model.timestamp then
    local d = db.format_date()
    full_insert.created_at = full_insert.created_at or d
    full_insert.updated_at = full_insert.updated_at or d
    full_update.updated_at = full_update.updated_at or d
  end
  local buffer = {
    "insert into ",
    db.escape_identifier(model:table_name()),
    " "
  }
  encode_values(full_insert, buffer)
  if opts and opts.constraint then
    insert(buffer, " on conflict ")
    insert(buffer, opts.constraint)
    insert(buffer, " do update set ")
  else
    insert(buffer, " on conflict (")
    assert(next(primary), "no primary constraint for insert on conflict update")
    for k in pairs(primary) do
      insert(buffer, db.escape_identifier(k))
      insert(buffer, ", ")
    end
    buffer[#buffer] = ") do update set "
  end
  encode_assigns(full_update, buffer)
  insert(buffer, " returning *")
  if opts and opts.return_inserted then
    insert(buffer, ", xmax = 0 as inserted")
  end
  local q = concat(buffer)
  local res = db.query(q)
  if res.affected_rows and res.affected_rows > 0 then
    return model:load(res[1])
  else
    return nil, res
  end
end
local encode_value_list
encode_value_list = function(tuples)
  local buffer = {
    "VALUES ("
  }
  local i = 2
  for j, t in ipairs(tuples) do
    if j > 1 then
      buffer[i] = "), ("
      i = i + 1
    end
    for k, v in ipairs(t) do
      if k > 1 then
        buffer[i] = ", "
        i = i + 1
      end
      buffer[i] = db.escape_literal(v)
      i = i + 1
    end
  end
  buffer[i] = ")"
  i = i + 1
  return table.concat(buffer)
end
return {
  upsert = upsert,
  filter_update = filter_update,
  soft_delete = soft_delete,
  memoize1 = memoize1,
  insert_on_conflict_update = insert_on_conflict_update,
  insert_on_conflict_ignore = insert_on_conflict_ignore,
  encode_value_list = encode_value_list
}
