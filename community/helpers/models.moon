
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

upsert = (model, insert, update, cond) ->
  table_name = db.escape_identifier model\table_name!

  primary_keys = { model\primary_keys! }
  is_primary_key = {k, true for k in *primary_keys}

  unless update
    update = { k,v for k,v in pairs insert when not is_primary_key[k] }

  unless cond
    cond = { k,v for k,v in pairs insert when is_primary_key[k] }


  if model.timestamp
    time = db.format_date!
    update.updated_at = time
    insert.created_at = time
    insert.updated_at = time

  insert_fields = [k for k in pairs insert]
  insert_values = [db.escape_literal insert[k] for k in *insert_fields]
  insert_fields = [db.escape_identifier k for k in *insert_fields]

  assert next(insert_fields), "no fields to insert for upsert"

  res = db.query "
    with updates as (
      update #{table_name}
      set #{db.encode_assigns update}
      where #{db.encode_clause cond}
      returning *
    ),
    inserts as (
      insert into #{table_name} (#{table.concat insert_fields, ", "})
      select #{table.concat insert_values, ", "}
      where not exists(select 1 from updates)
      returning *
    )
    select *, 'update' as _upsert_type from updates
    union
    select *, 'insert' as _upsert_type from inserts
  "

  res = unpack res
  upsert_type = res._upsert_type
  res._upsert_type = nil
  upsert_type, model\load res

-- set deleted to true
soft_delete = =>
  primary = @_primary_cond!
  primary.deleted = false

  res = db.update @@table_name!, {
    deleted: true
  }, primary

  res.affected_rows and res.affected_rows > 0

{ :upsert, :safe_insert, :filter_update, :soft_delete }
