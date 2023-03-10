local db = require("lapis.db.postgres")
local schema = require("lapis.db.schema")
local config = require("lapis.config").get()
local create_table, create_index, drop_table, add_column, drop_column, drop_index
create_table, create_index, drop_table, add_column, drop_column, drop_index = schema.create_table, schema.create_index, schema.drop_table, schema.add_column, schema.drop_column, schema.drop_index
local T
T = require("community.model").prefix_table
local serial, varchar, text, time, integer, foreign_key, boolean, numeric, double, enum
do
  local _obj_0 = schema.types
  serial, varchar, text, time, integer, foreign_key, boolean, numeric, double, enum = _obj_0.serial, _obj_0.varchar, _obj_0.text, _obj_0.time, _obj_0.integer, _obj_0.foreign_key, _obj_0.boolean, _obj_0.numeric, _obj_0.double, _obj_0.enum
end
return {
  [1] = function()
    create_table(T("categories"), {
      {
        "id",
        serial
      },
      {
        "title",
        varchar
      },
      {
        "slug",
        varchar
      },
      {
        "user_id",
        foreign_key({
          null = true
        })
      },
      {
        "parent_category_id",
        foreign_key({
          null = true
        })
      },
      {
        "last_topic_id",
        foreign_key({
          null = true
        })
      },
      {
        "topics_count",
        integer
      },
      {
        "deleted_topics_count",
        integer
      },
      {
        "views_count",
        integer
      },
      {
        "short_description",
        text({
          null = true
        })
      },
      {
        "description",
        text({
          null = true
        })
      },
      {
        "rules",
        text({
          null = true
        })
      },
      {
        "membership_type",
        integer
      },
      {
        "voting_type",
        integer
      },
      {
        "archived",
        boolean
      },
      {
        "hidden",
        boolean
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_table(T("category_members"), {
      {
        "user_id",
        foreign_key
      },
      {
        "category_id",
        foreign_key
      },
      {
        "accepted",
        boolean
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (user_id, category_id)"
    })
    create_index(T("category_members"), "category_id", "user_id", {
      where = "accepted"
    })
    create_table(T("topics"), {
      {
        "id",
        serial
      },
      {
        "category_id",
        foreign_key({
          null = true
        })
      },
      {
        "user_id",
        foreign_key({
          null = true
        })
      },
      {
        "title",
        varchar({
          null = true
        })
      },
      {
        "slug",
        varchar({
          null = true
        })
      },
      {
        "last_post_id",
        foreign_key({
          null = true
        })
      },
      {
        "locked",
        boolean
      },
      {
        "sticky",
        boolean
      },
      {
        "permanent",
        boolean
      },
      {
        "deleted",
        boolean
      },
      {
        "posts_count",
        integer
      },
      {
        "deleted_posts_count",
        integer
      },
      {
        "root_posts_count",
        integer
      },
      {
        "views_count",
        integer
      },
      {
        "category_order",
        integer
      },
      {
        "deleted_at",
        time({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("topics"), "category_id", "sticky", "category_order", {
      where = "not deleted and category_id is not null"
    })
    create_table(T("posts"), {
      {
        "id",
        serial
      },
      {
        "topic_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "parent_post_id",
        foreign_key({
          null = true
        })
      },
      {
        "post_number",
        integer
      },
      {
        "depth",
        integer
      },
      {
        "deleted",
        boolean
      },
      {
        "body",
        text
      },
      {
        "down_votes_count",
        integer
      },
      {
        "up_votes_count",
        integer
      },
      {
        "edits_count",
        integer
      },
      {
        "last_edited_at",
        time({
          null = true
        })
      },
      {
        "deleted_at",
        time({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("posts"), "topic_id", "parent_post_id", "depth", "post_number", {
      unique = true
    })
    create_index(T("posts"), "parent_post_id", "post_number", {
      unique = true
    })
    create_index(T("posts"), "topic_id", "id", {
      where = "not deleted"
    })
    create_table(T("post_edits"), {
      {
        "id",
        serial
      },
      {
        "post_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "body_before",
        text
      },
      {
        "reason",
        text({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("post_edits"), "post_id", "id", {
      unique = true
    })
    create_table(T("votes"), {
      {
        "user_id",
        foreign_key
      },
      {
        "object_type",
        foreign_key
      },
      {
        "object_id",
        foreign_key
      },
      {
        "positive",
        boolean
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (user_id, object_type, object_id)"
    })
    create_index(T("votes"), "object_type", "object_id")
    create_table(T("moderators"), {
      {
        "user_id",
        foreign_key
      },
      {
        "object_type",
        foreign_key
      },
      {
        "object_id",
        foreign_key
      },
      {
        "admin",
        boolean
      },
      {
        "accepted",
        boolean
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (user_id, object_type, object_id)"
    })
    create_index(T("moderators"), "object_type", "object_id", "created_at")
    create_table(T("post_reports"), {
      {
        "id",
        serial
      },
      {
        "category_id",
        foreign_key({
          null = true
        })
      },
      {
        "post_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "category_report_number",
        integer
      },
      {
        "moderating_user_id",
        foreign_key({
          null = true
        })
      },
      {
        "status",
        integer
      },
      {
        "reason",
        integer
      },
      {
        "body",
        text({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("post_reports"), "post_id", "id", "status")
    create_index(T("post_reports"), "category_id", "id", {
      where = "category_id is not null"
    })
    create_table(T("users"), {
      {
        "user_id",
        foreign_key
      },
      {
        "posts_count",
        integer
      },
      {
        "topics_count",
        integer
      },
      {
        "votes_count",
        integer
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (user_id)"
    })
    create_table(T("topic_participants"), {
      {
        "topic_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "posts_count",
        integer
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (topic_id, user_id)"
    })
    create_table(T("topic_tags"), {
      {
        "topic_id",
        foreign_key
      },
      {
        "slug",
        varchar
      },
      {
        "label",
        varchar
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (topic_id, slug)"
    })
    create_table(T("blocks"), {
      {
        "blocking_user_id",
        foreign_key
      },
      {
        "blocked_user_id",
        foreign_key
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (blocking_user_id, blocked_user_id)"
    })
    create_table(T("bans"), {
      {
        "object_type",
        integer
      },
      {
        "object_id",
        foreign_key
      },
      {
        "banned_user_id",
        foreign_key
      },
      {
        "reason",
        text({
          null = true
        })
      },
      {
        "banning_user_id",
        foreign_key({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (object_type, object_id, banned_user_id)"
    })
    create_index(T("bans"), "banned_user_id")
    create_index(T("bans"), "banning_user_id")
    create_index(T("bans"), "object_type", "object_id", "created_at")
    create_table(T("moderation_logs"), {
      {
        "id",
        serial
      },
      {
        "category_id",
        foreign_key({
          null = true
        })
      },
      {
        "object_type",
        integer
      },
      {
        "object_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "action",
        varchar
      },
      {
        "reason",
        text({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("moderation_logs"), "user_id")
    create_index(T("moderation_logs"), "object_type", "object_id", "action", "id")
    create_index(T("moderation_logs"), "category_id", "id", {
      where = "category_id is not null"
    })
    create_table(T("moderation_log_objects"), {
      {
        "moderation_log_id",
        foreign_key
      },
      {
        "object_type",
        integer
      },
      {
        "object_id",
        foreign_key
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (moderation_log_id, object_type, object_id)"
    })
    create_table(T("category_groups"), {
      {
        "id",
        serial
      },
      {
        "title",
        varchar({
          null = true
        })
      },
      {
        "user_id",
        foreign_key({
          null = true
        })
      },
      {
        "categories_count",
        integer
      },
      {
        "description",
        text({
          null = true
        })
      },
      {
        "rules",
        text({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_table(T("category_group_categories"), {
      {
        "category_group_id",
        foreign_key
      },
      {
        "category_id",
        foreign_key
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (category_group_id, category_id)"
    })
    create_index(T("category_group_categories"), "category_id", {
      unique = true
    })
    create_table(T("user_topic_last_seens"), {
      {
        "user_id",
        foreign_key
      },
      {
        "topic_id",
        foreign_key
      },
      {
        "post_id",
        foreign_key
      },
      "PRIMARY KEY (user_id, topic_id)"
    })
    create_table(T("bookmarks"), {
      {
        "user_id",
        foreign_key
      },
      {
        "object_type",
        integer
      },
      {
        "object_id",
        foreign_key
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (user_id, object_type, object_id)"
    })
    create_index(T("bookmarks"), "user_id", "created_at")
    create_table(T("activity_logs"), {
      {
        "id",
        serial
      },
      {
        "user_id",
        foreign_key
      },
      {
        "object_type",
        integer
      },
      {
        "object_id",
        foreign_key
      },
      {
        "publishable",
        boolean
      },
      {
        "action",
        integer
      },
      {
        "data",
        text({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    return create_index(T("activity_logs"), "user_id", "id")
  end,
  [2] = function()
    db.query("alter table " .. tostring(T("categories")) .. "\n      alter column membership_type drop default,\n      alter column voting_type drop default,\n\n      alter column membership_type drop not null,\n      alter column voting_type drop not null,\n\n      alter column title drop not null,\n      alter column slug drop not null\n    ")
    add_column(T("categories"), "category_groups_count", integer)
    return db.update(T("categories"), {
      category_groups_count = db.raw("(\n        select count(*) from " .. tostring(T("category_group_categories")) .. "\n        where category_id = id\n      )")
    })
  end,
  [3] = function()
    create_table(T("pending_posts"), {
      {
        "id",
        serial
      },
      {
        "category_id",
        foreign_key({
          null = true
        })
      },
      {
        "topic_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "parent_post_id",
        foreign_key({
          null = true
        })
      },
      {
        "status",
        enum
      },
      {
        "body",
        text
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    create_index(T("pending_posts"), "category_id", "status", "id", {
      where = "category_id is not null"
    })
    create_index(T("pending_posts"), "topic_id", "status", "id")
    return add_column(T("categories"), "approval_type", enum({
      null = true
    }))
  end,
  [4] = function(self)
    add_column(T("categories"), "position", integer({
      default = 0
    }))
    db.query("\n      update " .. tostring(T("categories")) .. " set position = foo.row_number\n      from (\n        select id, parent_category_id, row_number()\n        over (partition by parent_category_id order by created_at asc)\n        from " .. tostring(T("categories")) .. "\n        where parent_category_id is not null\n      ) as foo\n      where " .. tostring(T("categories")) .. ".id = foo.id\n    ")
    return create_index(T("categories"), "parent_category_id", "position", {
      where = "parent_category_id is not null"
    })
  end,
  [5] = function(self)
    add_column(T("categories"), "directory", boolean({
      default = false
    }))
    add_column(T("topics"), "status", enum({
      default = 1
    }))
    add_column(T("posts"), "status", enum({
      default = 1
    }))
    create_index(T("topics"), "category_id", "sticky", "status", "category_order", {
      where = "not deleted and category_id is not null"
    })
    drop_index(T("topics"), "category_id", "sticky", "category_order", {
      where = "not deleted and category_id is not null"
    })
    create_index(T("posts"), "topic_id", "parent_post_id", "depth", "status", "post_number")
    return create_index(T("posts"), "parent_post_id", "status", "post_number")
  end,
  [6] = function(self)
    return create_table(T("user_category_last_seens"), {
      {
        "user_id",
        foreign_key
      },
      {
        "category_id",
        foreign_key
      },
      {
        "category_order",
        integer
      },
      {
        "topic_id",
        foreign_key
      },
      "PRIMARY KEY (user_id, category_id)"
    })
  end,
  [7] = function(self)
    add_column(T("categories"), "topic_posting_type", enum({
      null = true
    }))
    return add_column(T("users"), "flair", varchar({
      null = true
    }))
  end,
  [8] = function(self)
    return create_index(T("posts"), "user_id", "status", "id", {
      where = "not deleted"
    })
  end,
  [9] = function(self)
    add_column(T("topics"), "tags", varchar({
      array = true,
      null = true
    }))
    drop_table(T("topic_tags"))
    create_table(T("category_tags"), {
      {
        "id",
        serial
      },
      {
        "category_id",
        foreign_key
      },
      {
        "slug",
        varchar
      },
      {
        "label",
        text({
          null = true
        })
      },
      {
        "color",
        varchar({
          null = true
        })
      },
      {
        "image_url",
        varchar({
          null = true
        })
      },
      {
        "tag_order",
        integer({
          defaut = 1
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    return create_index(T("category_tags"), "category_id", "slug", {
      unique = true
    })
  end,
  [10] = function(self)
    create_table(T("topic_subscriptions"), {
      {
        "topic_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "subscribed",
        boolean({
          default = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (topic_id, user_id)"
    })
    return create_index(T("topic_subscriptions"), "user_id")
  end,
  [11] = function(self)
    create_table(T("category_post_logs"), {
      {
        "category_id",
        foreign_key
      },
      {
        "post_id",
        foreign_key
      },
      "PRIMARY KEY (category_id, post_id)"
    })
    return create_index(T("category_post_logs"), "post_id")
  end,
  [12] = function(self)
    create_table(T("subscriptions"), {
      {
        "object_type",
        enum
      },
      {
        "object_id",
        foreign_key
      },
      {
        "user_id",
        foreign_key
      },
      {
        "subscribed",
        boolean({
          default = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (object_type, object_id, user_id)"
    })
    create_index(T("subscriptions"), "user_id")
    db.query("\n      insert into " .. tostring(T("subscriptions")) .. " (created_at, updated_at, subscribed, user_id, object_type, object_id)\n      select created_at, updated_at, subscribed, user_id, 1 as object_type, topic_id as object_id\n      from " .. tostring(T("topic_subscriptions")) .. "\n    ")
    return drop_table(T("topic_subscriptions"))
  end,
  [13] = function(self)
    return add_column(T("moderation_logs"), "data", "jsonb")
  end,
  [14] = function(self)
    return add_column(T("categories"), "category_order_type", enum({
      default = 1
    }))
  end,
  [15] = function(self)
    return add_column(T("votes"), "ip", "inet")
  end,
  [16] = function(self)
    return add_column(T("topics"), "rank_adjustment", integer({
      default = 0
    }))
  end,
  [17] = function(self)
    return add_column(T("votes"), "counted", boolean({
      default = true
    }))
  end,
  [18] = function(self)
    return add_column(T("votes"), "score", integer({
      null = true,
      default = db.NULL
    }))
  end,
  [19] = function(self)
    return add_column(T("posts"), "moderation_log_id", foreign_key({
      null = true,
      unique = true
    }))
  end,
  [20] = function(self)
    db.query("alter table " .. tostring(T("pending_posts")) .. "\n      alter column topic_id drop not null\n    ")
    drop_index(T("pending_posts"), "topic_id", "status", "id")
    create_index(T("pending_posts"), "topic_id", "status", "id", {
      where = "topic_id is not null"
    })
    return add_column(T("pending_posts"), "title", varchar({
      null = true
    }))
  end,
  [21] = function(self)
    return add_column(T("topics"), "protected", boolean({
      default = false
    }))
  end,
  [22] = function(self)
    add_column(T("posts"), "body_format", enum({
      default = 1
    }))
    add_column(T("post_edits"), "body_format", enum({
      default = 1
    }))
    return add_column(T("pending_posts"), "body_format", enum({
      default = 1
    }))
  end,
  [23] = function(self)
    return add_column(T("post_reports"), "moderated_at", time({
      null = true
    }))
  end,
  [24] = function(self)
    return create_index(T("activity_logs"), "object_type", "object_id")
  end,
  [25] = function(self)
    create_table(T("posts_search"), {
      {
        "post_id",
        foreign_key
      },
      {
        "topic_id",
        foreign_key
      },
      {
        "category_id",
        foreign_key({
          null = true
        })
      },
      {
        "posted_at",
        time
      },
      {
        "words",
        "tsvector"
      },
      "PRIMARY KEY (post_id)"
    })
    create_index(T("posts_search"), "post_id")
    local idx = db.escape_identifier(schema.gen_index_name(T("posts_search"), "words"))
    return db.query("create index " .. tostring(idx) .. " on " .. tostring(T("posts_search")) .. " using gin(words)")
  end,
  [26] = function(self)
    return add_column(T("posts"), "pin_position", integer({
      null = true,
      default = db.NULL
    }))
  end,
  [27] = function(self)
    add_column(T("users"), "recent_posts_count", integer({
      default = 0
    }))
    return add_column(T("users"), "last_post_at", time({
      null = true
    }))
  end,
  [28] = function(self)
    return create_index(T("user_topic_last_seens"), "topic_id")
  end,
  [29] = function(self)
    return add_column(T("users"), "posting_permission", enum({
      default = 1
    }))
  end,
  [30] = function(self)
    drop_index(T("posts"), "user_id", "status", "id")
    return create_index(T("posts"), "user_id", "id")
  end,
  [31] = function(self)
    return create_index(T("topics"), "user_id", {
      where = "user_id is not null"
    })
  end,
  [32] = function(self)
    return create_index(T("topics"), "category_id", {
      where = "category_id is not null"
    })
  end,
  [33] = function(self)
    add_column(T("users"), "received_up_votes_count", integer({
      default = 0
    }))
    add_column(T("users"), "received_down_votes_count", integer({
      default = 0
    }))
    add_column(T("users"), "received_votes_adjustment", integer({
      default = 0
    }))
    local posts_table = db.escape_identifier(T("posts"))
    local users_table = db.escape_identifier(T("users"))
    return db.update(T("users"), {
      received_up_votes_count = db.raw("coalesce((select sum(up_votes_count) from " .. tostring(posts_table) .. " where not deleted and " .. tostring(posts_table) .. ".user_id = " .. tostring(users_table) .. ".user_id), 0)"),
      received_down_votes_count = db.raw("coalesce((select sum(down_votes_count) from " .. tostring(posts_table) .. " where not deleted and " .. tostring(posts_table) .. ".user_id = " .. tostring(users_table) .. ".user_id), 0)")
    })
  end,
  [34] = function(self)
    add_column(T("posts"), "popularity_score", integer({
      null = true
    }))
    create_index(T("posts"), "topic_id", "popularity_score", {
      where = "popularity_score is not null"
    })
    return create_index(T("posts"), "parent_post_id", "popularity_score", {
      where = "popularity_score is not null and parent_post_id is not null"
    })
  end,
  [35] = function(self)
    return add_column(T("topics"), "data", "jsonb")
  end,
  [36] = function(self)
    create_index(T("posts"), "moderation_log_id", {
      unique = true,
      index_name = tostring(T("posts")) .. "_moderation_log_id_not_null_key",
      where = "moderation_log_id is not null"
    })
    return db.query("alter table " .. tostring(db.escape_identifier(T("posts"))) .. " drop constraint " .. tostring(db.escape_identifier(tostring(T("posts")) .. "_moderation_log_id_key")))
  end,
  [37] = function(self)
    add_column(T("post_reports"), "post_user_id", foreign_key({
      null = true
    }))
    create_index(T("post_reports"), "post_user_id", {
      where = "post_user_id is not null"
    })
    add_column(T("post_reports"), "post_parent_post_id", foreign_key({
      null = true
    }))
    add_column(T("post_reports"), "post_body", text({
      null = true
    }))
    add_column(T("post_reports"), "post_body_format", enum({
      null = true
    }))
    return db.query("update " .. tostring(db.escape_identifier(T("post_reports"))) .. " as pr\n        set post_user_id = p.user_id,\n          post_parent_post_id = p.parent_post_id,\n          post_body = p.body,\n          post_body_format = p.body_format\n\n        from " .. tostring(db.escape_identifier(T("posts"))) .. " as p\n          where pr.post_id = p.id")
  end,
  [38] = function(self)
    add_column(T("post_reports"), "post_topic_id", foreign_key({
      null = true
    }))
    return db.query("update " .. tostring(db.escape_identifier(T("post_reports"))) .. " as pr\n        set post_topic_id = p.topic_id\n        from " .. tostring(db.escape_identifier(T("posts"))) .. " as p\n          where pr.post_id = p.id")
  end,
  [39] = function(self)
    return add_column(T("category_tags"), "description", text({
      null = true
    }))
  end,
  [40] = function(self)
    return db.query("alter table " .. tostring(db.escape_identifier(T("activity_logs"))) .. " alter column data type jsonb using data::jsonb")
  end,
  [41] = function(self)
    return add_column(T("pending_posts"), "data", "jsonb")
  end,
  [42] = function(self)
    add_column(T("pending_posts"), "reason", enum({
      default = 1
    }))
    db.query("delete from " .. tostring(db.escape_identifier(T("activity_logs"))) .. " where object_type = ? and action = ?", 3, 3)
    add_column(T("activity_logs"), "ip", "inet")
    return drop_column(T("activity_logs"), "publishable")
  end,
  [43] = function(self)
    return add_column(T("categories"), "data", "jsonb")
  end,
  [44] = function(self)
    create_table(T("warnings"), {
      {
        "id",
        serial
      },
      {
        "user_id",
        foreign_key
      },
      {
        "reason",
        text({
          null = true
        })
      },
      {
        "data",
        "jsonb"
      },
      {
        "restriction",
        enum({
          default = 1
        })
      },
      {
        "duration",
        "interval not null"
      },
      {
        "first_seen_at",
        time({
          null = true
        })
      },
      {
        "expires_at",
        time({
          null = true
        })
      },
      {
        "moderating_user_id",
        foreign_key({
          null = true
        })
      },
      {
        "post_id",
        foreign_key({
          null = true
        })
      },
      {
        "post_report_id",
        foreign_key({
          null = true
        })
      },
      {
        "created_at",
        time
      },
      {
        "updated_at",
        time
      },
      "PRIMARY KEY (id)"
    })
    return create_index(T("warnings"), "user_id")
  end
}
