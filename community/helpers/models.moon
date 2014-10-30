
db = require "lapis.db"

import insert, concat from table

-- return false on update
-- return result of create on create
upsert = (model, data, opts) ->
  error "can't upsert with no data" unless next data

  -- split data into primary keys and rest
  primary_keys = { model\primary_keys! }
  update_data = {k,v for k,v in pairs data}

  for key in *primary_keys
    key_value = data[key]
    unless key_value
      error "missing primary key `#{key}` for upsert"

    primary_keys[key] = key_value
    update_data[key] = nil

  -- remove array items
  for i=#primary_keys, 1, -1
    primary_keys[i] = nil

  -- update
  if next update_data
    if model.timestamp
      time = db.format_date!
      update_data.updated_at = time

    res = db.update model\table_name!, update_data, primary_keys
    if res.affected_rows and res.affected_rows > 0
      return false

  table_name = db.escape_identifier model\table_name!

  if opts and opts.before_create
    opts.before_create data

  columns = [key for key in pairs data]
  values = [db.escape_literal data[col] for col in *columns]

  if model.timestamp
    time = db.escape_literal db.format_date!
    insert columns, "created_at"
    insert columns, "updated_at"
    insert values, time
    insert values, time

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
    db.encode_clause primary_keys
    ")"
  }, "  "

  db.query q

{ :upsert }
