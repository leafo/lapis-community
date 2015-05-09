db = require "lapis.db.postgres"
schema = require "lapis.db.schema"

import create_table, create_index, drop_table from schema

make_schema = ->
  require("community.schema").run_migrations!

  {
    :serial
    :varchar
    :time
    :integer
  } = schema.types

  create_table "users", {
    {"id", serial}
    {"username", varchar}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "users", db.raw"lower(username)", unique: true

{ :make_schema }
