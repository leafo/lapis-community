
db = require "lapis.db"
import Model from require "community.model"

import enum from require "lapis.db.model"

import db_json from require "community.helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_pending_posts (
--   id integer NOT NULL,
--   category_id integer,
--   topic_id integer,
--   user_id integer NOT NULL,
--   parent_post_id integer,
--   status smallint NOT NULL,
--   body text NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   title character varying(255),
--   body_format smallint DEFAULT 1 NOT NULL,
--   data jsonb,
--   reason smallint DEFAULT 1 NOT NULL
-- );
-- ALTER TABLE ONLY community_pending_posts
--   ADD CONSTRAINT community_pending_posts_pkey PRIMARY KEY (id);
-- CREATE INDEX community_pending_posts_category_id_status_id_idx ON community_pending_posts USING btree (category_id, status, id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_pending_posts_topic_id_status_id_idx ON community_pending_posts USING btree (topic_id, status, id) WHERE (topic_id IS NOT NULL);
--
class PendingPosts extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"user", belongs_to: "Users"}
    {"parent_post", belongs_to: "Posts"}
    {"category", belongs_to: "Categories"}

    {"activity_log_create"
      has_one: "ActivityLogs"
      key: "object_id", where: {
        object_type: 4
        action: db.list { 1, 2 } -- create_post, create_topic
      }
    }
  }

  @statuses: enum {
    pending: 1
    deleted: 2
    spam: 3
    ignored: 4
  }

  @reasons: enum {
    manual: 1 -- community configuration put this post into the queue
    risky: 2 -- automated scans determined this poster is risky
    warning: 3 -- account has active warning with pending restriction
  }

  @create: (opts={}) =>
    opts.status = @statuses\for_db opts.status or "pending"
    opts.reason = @reasons\for_db opts.reason or "manual"

    import Posts from require "community.models"
    opts.body_format = Posts.body_formats\for_db opts.body_format or 1

    if opts.data
      opts.data = db_json opts.data

    super opts

  allowed_to_moderate: (user) =>
    if parent = @get_topic! or @get_category!
      if parent\allowed_to_moderate user
        return true

    false

  is_topic: =>
    not @topic_id

  -- Convert pending to real post, and delete the pending post
  -- note this does not check if post is currently allowed to be added to
  -- topic (because it's deleted, locked, etc.) If desired that check needs to
  -- be done before calling promote
  promote: (req_or_flow=nil) =>
    import Posts, Topics, CommunityUsers from require "community.models"

    created_topic = false

    -- create the topic
    topic = if @is_topic!
      category = @get_category!

      unless category
        return nil, "could not create topic for pending post due to lack of category"

      created_topic = true

      topic = Topics\create {
        user_id: @user_id
        category_id: @category_id
        category_order: category\next_topic_category_order!
        title: assert @title, "missing title for pending topic"
        tags: if @data and @data.topic_tags
          db.array @data.topic_tags
      }
    else
      @get_topic!

    unless topic
      return nil, "failed to get or create topic to place pending post"

    post = Posts\create {
      topic_id: topic.id
      user_id: @user_id
      parent_post: @get_parent_post!
      body: @body
      body_format: @body_format
      created_at: @created_at
    }, returning: "*"

    topic\increment_from_post post, category_order: false

    cu = CommunityUsers\for_user @get_user!
    cu\increment_from_post post, created_topic

    if created_topic
      @get_category!\increment_from_topic topic

    post\on_body_updated_callback req_or_flow

    topic\increment_participant @get_user!

    @delete!
    post

