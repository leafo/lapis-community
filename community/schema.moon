db = require "lapis.nginx.postgres"
schema = require "lapis.db.schema"
migrations = require "lapis.db.migrations"

import create_table, create_index, drop_table from schema

make_schema = ->
  {
    :serial
    :varchar
    :text
    :time
    :integer
    :foreign_key
    :boolean
    :numeric
    :double
  } = schema.types

  create_table "categories", {
    {"id", serial}
    {"name", varchar}
    {"slug", varchar}
    {"parent_category_id", foreign_key null: true}

    {"topics_count", integer}

    {"created_at", time}
    {"updated_at", time}


    "PRIMARY KEY (id)"
  }

  create_table "topics", {
    {"id", serial}
    {"category_id", foreign_key}
    {"user_id", foreign_key}
    {"title", varchar}
    {"slug", varchar}

    {"posts_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_table "posts", {
    {"id", serial}
    {"topic_id", foreign_key}
    {"user_id", foreign_key}

    {"body", text}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

{ :make_schema }
