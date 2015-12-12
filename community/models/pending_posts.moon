
db = require "lapis.db"
import Model from require "community.model"

import enum from require "lapis.db.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_pending_posts (
--   id integer NOT NULL,
--   category_id integer,
--   topic_id integer NOT NULL,
--   user_id integer NOT NULL,
--   parent_post_id integer,
--   status smallint NOT NULL,
--   body text NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_pending_posts
--   ADD CONSTRAINT community_pending_posts_pkey PRIMARY KEY (id);
-- CREATE INDEX community_pending_posts_category_id_status_id_idx ON community_pending_posts USING btree (category_id, status, id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_pending_posts_topic_id_status_id_idx ON community_pending_posts USING btree (topic_id, status, id);
--
class PendingPosts extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"user", belongs_to: "Users"}
    {"parent_post", belongs_to: "Posts"}
    {"category", belongs_to: "Categories"}
  }

  @statuses: enum {
    pending: 1
    deleted: 2
    spam: 3
  }

  @create: (opts={}) =>
    opts.status = @statuses\for_db opts.status or "pending"
    Model.create @, opts

  allowed_to_moderate: (user) =>
    topic = @get_topic!
    topic\allowed_to_moderate user

  -- convert to real post
  promote: =>
    import Posts, CommunityUsers from require "community.models"

    post = Posts\create {
      topic_id: @topic_id
      user_id: @user_id
      parent_post: @parent_post
      body: @body
      created_at: @created_at
    }

    topic = @get_topic!

    topic\increment_from_post post

    if category = topic\get_category!
      category\increment_from_post post

    CommunityUsers\for_user(@get_user!)\increment "posts_count"
    topic\increment_participant @get_user!

    @delete!
    post


