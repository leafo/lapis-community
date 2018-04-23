
db = require "lapis.db"
import Model from require "community.model"

import enum from require "lapis.db.model"

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
--   body_format smallint DEFAULT 1 NOT NULL
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
  }

  @statuses: enum {
    pending: 1
    deleted: 2
    spam: 3
  }

  @create: (opts={}) =>
    opts.status = @statuses\for_db opts.status or "pending"
    import Posts from require "community.models"
    opts.body_format = Posts.body_formats\for_db opts.body_format or 1
    super opts

  allowed_to_moderate: (user) =>
    if parent = @get_topic! or @get_category!
      if parent\allowed_to_moderate user
        return true

    false

  -- convert to real post
  promote: =>
    import Posts, Topics, CommunityUsers from require "community.models"

    topic = @get_topic!
    created_topic = false
    unless topic
      category = assert @get_category!, "attempting to create new pending topic but there is no category_id"
      created_topic = true

      topic = Topics\create {
        user_id: @user_id
        category_id: @category_id
        category_order: category\next_topic_category_order!
        title: assert @title, "missing title for pending topic"
      }

    post = Posts\create {
      topic_id: topic.id
      user_id: @user_id
      parent_post: @parent_post
      body: @body
      created_at: @created_at
    }

    topic\increment_from_post post, category_order: false

    if created_topic
      @get_category!\increment_from_topic topic
      CommunityUsers\for_user(@get_user!)\increment "topics_count"
    else
      CommunityUsers\for_user(@get_user!)\increment "posts_count"

    topic\increment_participant @get_user!

    @delete!
    post

