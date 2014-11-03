db = require "lapis.nginx.postgres"
schema = require "lapis.db.schema"

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
    {"deleted", boolean}

    {"posts_count", integer}

    {"created_at", time}
    {"updated_at", time}
    {"last_post_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "topics", "category_id", "last_post_at", "id", where: "not deleted"

  create_table "posts", {
    {"id", serial}
    {"topic_id", foreign_key}
    {"user_id", foreign_key}
    {"post_number", integer}

    {"body", text}

    {"down_votes_count", integer}
    {"up_votes_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "posts", "topic_id", "post_number", unique: true

  create_table "post_votes", {
    {"user_id", foreign_key}
    {"post_id", foreign_key}
    {"positive", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, post_id)"
  }

  create_table "post_replies", {
    {"parent_post_id", foreign_key}
    {"child_post_id", foreign_key}

    "PRIMARY KEY (parent_post_id, child_post_id)"
  }

  create_table "category_moderators", {
    {"user_id", foreign_key}
    {"category_id", foreign_key}
    {"admin", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, category_id)"
  }

  create_index "category_moderators", "category_id", "created_at"

{ :make_schema }
