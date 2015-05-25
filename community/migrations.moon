db = require "lapis.db.postgres"
schema = require "lapis.db.schema"

import create_table, create_index, drop_table from schema
{prefix_table: T} = require "community.model"

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


{
  [1]: ->
    create_table T"categories", {
      {"id", serial}
      {"title", varchar}
      {"slug", varchar}
      {"user_id", foreign_key null: true}
      {"parent_category_id", foreign_key null: true}

      {"last_topic_id", foreign_key null: true}

      {"topics_count", integer}
      {"views_count", integer}

      {"short_description", text null: true}
      {"description", text null: true}
      {"rules", text null: true}

      {"membership_type", integer}
      {"voting_type", integer}

      {"archived", boolean}
      {"hidden", boolean}

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
      {"user_id", foreign_key null: true}
      {"title", varchar null: true}
      {"slug", varchar null: true}

      {"last_post_id", foreign_key null: true}

      {"locked", boolean}
      {"sticky", boolean}
      {"deleted", boolean}

      {"posts_count", integer}
      {"root_posts_count", integer}

      {"views_count", integer}

      {"category_order", integer}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (id)"
    }

    create_index T"topics", "category_id", "sticky", "category_order", where: "not deleted and category_id is not null"

    create_table T"posts", {
      {"id", serial}
      {"topic_id", foreign_key}
      {"user_id", foreign_key}
      {"parent_post_id", foreign_key null: true}

      {"post_number", integer}
      {"depth", integer}

      {"deleted", boolean}

      {"body", text}

      {"down_votes_count", integer}
      {"up_votes_count", integer}

      {"edits_count", integer}
      {"last_edited_at", time null: true}

      {"deleted_at", time}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (id)"
    }

    create_index T"posts", "topic_id", "parent_post_id", "depth", "post_number", unique: true
    create_index T"posts", "parent_post_id", "post_number", unique: true
    create_index T"posts", "topic_id", "id", where: "not deleted" -- for fetching latest post from topic

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

    create_table T"votes", {
      {"user_id", foreign_key}

      {"object_type", foreign_key}
      {"object_id", foreign_key}

      {"positive", boolean}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (user_id, object_type, object_id)"
    }

    create_index T"votes", "object_type", "object_id"

    create_table T"post_replies", {
      {"parent_post_id", foreign_key}
      {"child_post_id", foreign_key}

      "PRIMARY KEY (parent_post_id, child_post_id)"
    }

    create_table T"moderators", {
      {"user_id", foreign_key}
      {"object_type", foreign_key}
      {"object_id", foreign_key}

      {"admin", boolean}

      {"accepted", boolean}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (user_id, object_type, object_id)"
    }

    create_index T"moderators", "object_type", "object_id", "created_at"

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
      {"blocking_user_id", foreign_key}
      {"blocked_user_id", foreign_key}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (blocking_user_id, blocked_user_id)"
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

    create_index T"bans", "banned_user_id"
    create_index T"bans", "banning_user_id"

    create_table T"moderation_logs", {
      {"id", serial}

      {"category_id", foreign_key null: true}

      {"object_type", integer}
      {"object_id", foreign_key}

      {"user_id", foreign_key}
      {"action", varchar}
      {"reason", text null: true}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (id)"
    }

    create_index T"moderation_logs", "user_id"
    create_index T"moderation_logs", "object_type", "object_id", "action", "id"
    create_index T"moderation_logs", "category_id", "id", where: "category_id is not null"

    create_table T"moderation_log_objects", {
      {"moderation_log_id", foreign_key}
      {"object_type", integer}
      {"object_id", foreign_key}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (moderation_log_id, object_type, object_id)"
    }

    create_table T"category_groups", {
      {"id", serial}

      {"title", varchar null: true}
      {"user_id", foreign_key null: true}

      {"categories_count", integer}

      {"description", text null: true}
      {"rules", text null: true}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (id)"
    }

    create_table T"category_group_categories", {
      {"category_group_id", foreign_key}
      {"category_id", foreign_key}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (category_group_id, category_id)"
    }

    create_index T"category_group_categories", "category_id", unique: true

    create_table T"user_topic_last_seens", {
      {"user_id", foreign_key}
      {"topic_id", foreign_key}
      {"post_id", foreign_key}

      "PRIMARY KEY (user_id, topic_id)"
    }
    
    create_table T"bookmarks", {
      {"user_id", foreign_key}
      {"object_type", integer}
      {"object_id", foreign_key}

      {"created_at", time}
      {"updated_at", time}

      "PRIMARY KEY (user_id, object_type, object_id)"
    }

    create_index T"bookmarks", "user_id", "created_at"


}
