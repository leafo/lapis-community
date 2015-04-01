db = require "lapis.db.postgres"
schema = require "lapis.db.schema"

import create_table, create_index, drop_table from schema

make_schema = ->
  {
    :serial
    :varchar
    :time
    :integer
  } = schema.types

  create_table "users", {
    {"id", serial}
    {"username", varchar}
    {"password", varchar}
    {"email", varchar}

    {"display_name", varchar null: true}

    {"posts_count", integer}
    {"topics_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "users", db.raw"lower(username)", unique: true
  create_index "users", db.raw"lower(email)", unique: true


{ :make_schema }
