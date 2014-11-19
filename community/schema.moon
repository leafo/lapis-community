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
    {"user_id", foreign_key null: true}
    {"parent_category_id", foreign_key null: true}

    {"topics_count", integer}

    {"membership_type", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_table "category_members", {
    {"user_id", foreign_key}
    {"category_id", foreign_key}

    {"approved", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, category_id)"
  }

  create_index "category_members", "category_id", "user_id", where: "approved"

  create_table "topics", {
    {"id", serial}
    {"category_id", foreign_key}
    {"user_id", foreign_key}
    {"title", varchar}
    {"slug", varchar}
    {"locked", boolean}
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
    {"deleted", boolean}

    {"body", text}

    {"down_votes_count", integer}
    {"up_votes_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "posts", "topic_id", "post_number", unique: true

  create_table "post_edits", {
    {"id", serial}
    {"post_id", foreign_key}
    {"user_id", foreign_key}

    {"body_before", text}
    {"reason", text null: true}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "post_edits", "post_id", "id", unique: true

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

    {"accepted", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, category_id)"
  }

  create_index "category_moderators", "category_id", "created_at"

  create_table "post_reports", {
    {"id", serial}
    {"category_id", foreign_key} -- denormalized
    {"post_id", foreign_key}
    {"user_id", foreign_key}

    {"status", integer}

    {"reason", integer}
    {"body", text}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index "post_reports", "post_id", "id"
  create_index "post_reports", "category_id", "id"

{ :make_schema }
