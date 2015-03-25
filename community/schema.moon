db = require "lapis.nginx.postgres"
schema = require "lapis.db.schema"

import create_table, create_index, drop_table from schema
{prefix_table: T} = require "community.model"

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

  create_table T"categories", {
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

  create_table T"category_members", {
    {"user_id", foreign_key}
    {"category_id", foreign_key}

    {"accepted", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, category_id)"
  }

  create_index T"category_members", "category_id", "user_id", where: "accepted"

  create_table T"topics", {
    {"id", serial}
    {"category_id", foreign_key null: true}
    {"user_id", foreign_key}
    {"title", varchar null: true}
    {"slug", varchar null: true}
    {"locked", boolean}
    {"deleted", boolean}

    {"posts_count", integer}

    {"created_at", time}
    {"updated_at", time}
    {"last_post_at", time}

    "PRIMARY KEY (id)"
  }

  create_index T"topics", "category_id", "last_post_at", "id", where: "not deleted"

  create_table T"posts", {
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

  create_index T"posts", "topic_id", "post_number", unique: true

  create_table T"post_edits", {
    {"id", serial}
    {"post_id", foreign_key}
    {"user_id", foreign_key}

    {"body_before", text}
    {"reason", text null: true}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index T"post_edits", "post_id", "id", unique: true

  create_table T"post_votes", {
    {"user_id", foreign_key}
    {"post_id", foreign_key}
    {"positive", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, post_id)"
  }

  create_table T"post_replies", {
    {"parent_post_id", foreign_key}
    {"child_post_id", foreign_key}

    "PRIMARY KEY (parent_post_id, child_post_id)"
  }

  create_table T"category_moderators", {
    {"user_id", foreign_key}
    {"category_id", foreign_key}
    {"admin", boolean}

    {"accepted", boolean}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id, category_id)"
  }

  create_index T"category_moderators", "category_id", "created_at"

  create_table T"post_reports", {
    {"id", serial}
    {"category_id", foreign_key null: true} -- denormalized
    {"post_id", foreign_key}
    {"user_id", foreign_key}

    {"status", integer}

    {"reason", integer}
    {"body", text}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (id)"
  }

  create_index T"post_reports", "post_id", "id"
  create_index T"post_reports", "category_id", "id", where: "category_id is not null"

  create_table T"users", {
    {"user_id", foreign_key}

    {"posts_count", integer}
    {"topics_count", integer}
    {"votes_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (user_id)"
  }

  create_table T"topic_participants", {
    {"topic_id", foreign_key}
    {"user_id", foreign_key}
    {"posts_count", integer}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (topic_id, user_id)"
  }

  create_table T"topic_tags", {
    {"topic_id", foreign_key}
    {"slug", varchar}
    {"label", varchar}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (topic_id, slug)"
  }

  -- user blocks user
  create_table T"blocks", {
    {"blocker_id", foreign_key}
    {"blocked_id", foreign_key}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (blocker_id, blocked_id)"
  }

  -- user blocked from thing
  create_table T"bans", {
    {"object_type", integer}
    {"object_id", foreign_key}

    {"banned_user_id", foreign_key}

    {"reason", text null: true}
    {"banning_user_id", foreign_key null: true}

    {"created_at", time}
    {"updated_at", time}

    "PRIMARY KEY (object_type, object_id, banned_user_id)"
  }

{ :make_schema }
