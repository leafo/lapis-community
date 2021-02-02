
db = require "lapis.db"
json = require "cjson"

import next, unpack, ipairs, pairs from _G
import insert, concat from table

-- remove fields that haven't changed
filter_update = (model, update) ->
  for key,val in pairs update
    if model[key] == val
      update[key] = nil

    if val == db.NULL and model[key] == nil
      update[key] = nil

  update

-- returns "update" or "insert" depending on action, the loaded model
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
      insert into #{table_name} (#{concat insert_fields, ", "})
      select #{concat insert_values, ", "}
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

-- 1 arg
memoize1 = (fn) ->
  NIL = {}
  cache = setmetatable {}, __mode: "k"

  (arg, more) =>
    error "memoize1 function received second argument" if more
    key = if arg == nil then NIL else arg

    cache_value = cache[@] and cache[@][key]

    if cache_value
      return unpack cache_value

    res = { fn @, arg }

    unless cache[@]
      cache[@] = setmetatable {}, __mode: "k"

    cache[@][key] = res

    unpack res

insert_on_conflict_ignore = (model, opts) ->
  import encode_values, encode_assigns from require "lapis.db"

  full_insert = {}

  if opts
    for k,v in pairs opts
      full_insert[k] = v

  if model.timestamp
    d = db.format_date!
    full_insert.created_at = d
    full_insert.updated_at = d

  buffer = {
    "insert into "
    db.escape_identifier model\table_name!
    " "
  }

  encode_values full_insert, buffer

  insert buffer, " on conflict do nothing returning *"

  q = concat buffer
  res = db.query q

  if res.affected_rows and res.affected_rows > 0
    model\load res[1]
  else
    nil, res


insert_on_conflict_update = (model, primary, create, update, opts) ->
  import encode_values, encode_assigns from require "lapis.db"

  full_insert = {k,v for k,v in pairs primary}

  if create
    for k,v in pairs create
      full_insert[k] = v

  full_update = update or {k,v for k,v in pairs full_insert when not primary[k]}

  if model.timestamp
    d = db.format_date!
    full_insert.created_at or= d
    full_insert.updated_at or= d
    full_update.updated_at or= d

  buffer = {
    "insert into "
    db.escape_identifier model\table_name!
    " "
  }

  encode_values full_insert, buffer

  if opts and opts.constraint
    insert buffer, " on conflict "
    insert buffer, opts.constraint
    insert buffer, " do update set "
  else
    insert buffer, " on conflict ("

    assert next(primary), "no primary constraint for insert on conflict update"

    for k in pairs primary
      insert buffer, db.escape_identifier k
      insert buffer, ", "

    buffer[#buffer] = ") do update set " -- remove ,

  encode_assigns full_update, buffer

  insert buffer, " returning *"

  if opts and opts.return_inserted
    insert buffer, ", xmax = 0 as inserted"

  q = concat buffer
  res = db.query q

  if res.affected_rows and res.affected_rows > 0
    model\load res[1]
  else
    nil, res

encode_value_list = (tuples) ->
  buffer = {"VALUES ("}
  i = 2

  for j, t in ipairs tuples
    if j > 1
      buffer[i] = "), ("
      i += 1

    for k, v in ipairs t
      if k > 1
        buffer[i] = ", "
        i += 1

      buffer[i] = db.escape_literal v
      i += 1

  buffer[i] = ")"
  i += 1

  table.concat buffer

-- this will ensure json value is decoded after update/insert by using db.raw
-- eg. thing\update data: db_json {hello: "world"}
db_json = (v) ->
  if type(v) == "string"
    v
  else
    db.raw db.escape_literal json.encode v

{ :upsert, :filter_update, :soft_delete, :memoize1,
  :insert_on_conflict_update, :insert_on_conflict_ignore, :encode_value_list, :db_json }
