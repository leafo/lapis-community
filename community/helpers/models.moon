
db = require "lapis.db"

import insert, concat from table

-- remove fields that haven't changed
filter_update = (model, update) ->
  for key,val in pairs update
    if model[key] == val
      update[key] = nil

    if val == db.NULL and model[key] == nil
      update[key] = nil

  update

-- safe_insert Model, {color: true, id: 100}, {id: 100}
safe_insert = (data, check_cond=data) =>
  table_name = db.escape_identifier @table_name!

  if @timestamp
    data = {k,v for k,v in pairs data}
    time = db.format_date!
    data.created_at = time
    data.updated_at = time

  columns = [key for key in pairs data]
  values = [db.escape_literal data[col] for col in *columns]

  for i, col in ipairs columns
    columns[i] = db.escape_identifier col

  q = concat {
    "insert into"
    table_name
    "("
    concat columns, ", "
    ")"
    "select"
    concat values, ", "
    "where not exists ( select 1 from"
    table_name
    "where"
    db.encode_clause check_cond
    ") returning *"
  }, "  "

  res = db.query q
  if next res
    @load (unpack res)
  else
    nil, "already exists"

upsert = (data, keys) =>
  unless keys
    keys = {k, data[k] for k in *{@primary_keys!}}

  assert next(keys), "no primary keys provided"

  res = safe_insert @, data, keys
  return res, "insert" if res

  db.update @table_name!, data, keys
  @load(data), "update"

{ :upsert }
