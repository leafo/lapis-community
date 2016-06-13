db = require "lapis.db"

import Model from require "community.model"
import slugify from require "lapis.util"
import memoize1 from require "community.helpers.models"
import enum from require "lapis.db.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_topics (
--   id integer NOT NULL,
--   category_id integer,
--   user_id integer,
--   title character varying(255),
--   slug character varying(255),
--   last_post_id integer,
--   locked boolean DEFAULT false NOT NULL,
--   sticky boolean DEFAULT false NOT NULL,
--   permanent boolean DEFAULT false NOT NULL,
--   deleted boolean DEFAULT false NOT NULL,
--   posts_count integer DEFAULT 0 NOT NULL,
--   deleted_posts_count integer DEFAULT 0 NOT NULL,
--   root_posts_count integer DEFAULT 0 NOT NULL,
--   views_count integer DEFAULT 0 NOT NULL,
--   category_order integer DEFAULT 0 NOT NULL,
--   deleted_at timestamp without time zone,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   status smallint DEFAULT 1 NOT NULL,
--   tags character varying(255)[]
-- );
-- ALTER TABLE ONLY community_topics
--   ADD CONSTRAINT community_topics_pkey PRIMARY KEY (id);
-- CREATE INDEX community_topics_category_id_sticky_status_category_order_idx ON community_topics USING btree (category_id, sticky, status, category_order) WHERE ((NOT deleted) AND (category_id IS NOT NULL));
--
class Topics extends Model
  @timestamp: true

  @relations: {
    {"category", belongs_to: "Categories"}
    {"user", belongs_to: "Users"}
    {"topic_post", has_one: "Posts", key: "topic_id", where: {
      parent_post_id: db.NULL
      post_number: 1
      depth: 1
    }}
    {"last_post", belongs_to: "Posts"}
    {"subscriptions", has_many: "Subscriptions", key: "object_id", where: {object_type: 1}}
  }

  @statuses: enum {
    default: 1
    archived: 2
    spam: 2
  }

  @create: (opts={}) =>
    if opts.title
      opts.slug or= slugify opts.title

    opts.status = opts.status and @statuses\for_db opts.status
    opts.category_order = @update_category_order_sql opts.category_id

    Model.create @, opts, returning: {"status"}

  @update_category_order_sql: (category_id) =>
    return nil unless category_id

    db.raw db.interpolate_query "
      (select coalesce(max(category_order), 0) + 1
      from #{db.escape_identifier @table_name!}
      where category_id = ?)
    ", category_id

  @recount: (where) =>
    import Posts from require "community.models"
    db.update @table_name!, {
      root_posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id
          and depth = 1)
      "

      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{db.escape_identifier @table_name!}.id)
      "
    }, where

  @preload_bans: (topics, user) =>
    return unless user
    return unless next topics

    import Bans from require "community.models"
    bans = Bans\select "
      where banned_user_id = ? and object_type = ? and object_id in ?
    ", user.id, Bans.object_types.topic, db.list [t.id for t in *topics]

    bans_by_topic_id = {b.object_id, b for b in *bans}
    for t in *topics
      t.user_bans or= {}
      t.user_bans[user.id] = bans_by_topic_id[t.id] or false

    true

  allowed_to_post: (user) =>
    return false unless user
    return false if @deleted
    return false if @locked
    return false unless @is_default!

    @allowed_to_view user

  allowed_to_view: memoize1 (user) =>
    return false if @deleted

    can_view = if @category_id
      @get_category!\allowed_to_view user
    else
      true

    if can_view
      return false if @get_ban user

    can_view

  allowed_to_edit: memoize1 (user) =>
    return false if @deleted
    return false unless user
    return true if user\is_admin!
    return false if @is_archived!
    return true if user.id == @user_id
    return true if @allowed_to_moderate user

    false

  allowed_to_moderate: memoize1 (user) =>
    return false unless user
    return true if user\is_admin!
    return false unless @category_id

    import Categories from require "community.models"

    @get_category!\allowed_to_moderate user

  increment_participant: (user) =>
    return unless user
    import TopicParticipants from require "community.models"
    TopicParticipants\increment @id, user.id

  decrement_participant: (user) =>
    return unless user
    import TopicParticipants from require "community.models"
    TopicParticipants\decrement @id, user.id

  increment_from_post: (post, opts) =>
    assert post.topic_id == @id, "invalid post sent to topic"

    category_order = unless opts and opts.update_category_order == false
      Topics\update_category_order_sql @category_id

    @update {
      posts_count: db.raw "posts_count + 1"
      root_posts_count: if post.depth == 1
        db.raw "root_posts_count + 1"
      last_post_id: post.id
      :category_order
    }, timestamp: false

    if category = @get_category!
      category\increment_from_post post

  refresh_last_post: =>
    import Posts from require "community.models"

    @update {
      last_post_id: db.raw db.interpolate_query "(
        select id from #{db.escape_identifier Posts\table_name!}
        where
          topic_id = ? and
            not deleted and
            status = ? and
            (depth != 1 or post_number != 1)
        order by id desc
        limit 1
      )", @id, @@statuses.default
    }, timestamp: false

  delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      @update { deleted_at: db.format_date! }, timestamp: false

      import CommunityUsers, Categories, CategoryPostLogs from require "community.models"
      CategoryPostLogs\clear_posts_for_topic @

      if @user_id
        CommunityUsers\for_user(@get_user!)\increment "topics_count", -1

      if category = @get_category!
        category\update {
          deleted_topics_count: db.raw "deleted_topics_count + 1"
        }, timestamp: false

        if category.last_topic_id == @id
          category\refresh_last_topic!

      return true

    false

  get_ban: (user) =>
    return nil unless user

    @user_bans or= {}
    ban = @user_bans[user.id]

    if ban != nil
      return ban

    @user_bans[user.id] = @find_ban(user) or false
    @user_bans[user.id]

  find_ban: (user) =>
    return nil unless user
    import Bans from require "community.models"
    Bans\find_for_object @, user

  find_recent_log: (action) =>
    import ModerationLogs from require "community.models"
    unpack ModerationLogs\select "
      where object_type = ? and object_id = ? and action = ?
      order by id desc
      limit 1
    ", ModerationLogs.object_types.topic, @id, action

  -- most recent log entry for locking
  get_lock_log: =>
    return unless @locked

    unless @lock_log
      @lock_log = @find_recent_log "topic.lock"

    @lock_log

  -- most recent log entry for sticking
  get_sticky_log: =>
    return unless @sticky

    unless @sticky_log
      import ModerationLogs from require "community.models"
      @sticky_log = @find_recent_log "topic.stick"

    @sticky_log

  available_vote_types: =>
    if category = @get_category!
      category\available_vote_types!
    else
      { down: true, up: true }

  set_seen: (user) =>
    return unless user
    return unless @last_post_id

    import upsert from require "community.helpers.models"
    import UserTopicLastSeens from require "community.models"

    upsert UserTopicLastSeens, {
      user_id: user.id
      topic_id: @id
      post_id: @last_post_id
    }

  -- this assumes UserTopicLastSeens has been preloaded
  has_unread: (user) =>
    return unless user
    return unless @user_topic_last_seen
    return unless @last_post_id

    assert @user_topic_last_seen.user_id == user.id, "unexpected user for last seen"
    @user_topic_last_seen.post_id < @last_post_id

  notification_target_users: =>
    import Subscriptions from require "community.models"
    subs = @get_subscriptions!
    Subscriptions\preload_relations subs, "user"

    include_owner = true
    targets = for sub in *subs
      include_owner = false if sub.user_id == @user_id
      continue unless sub.subscribed
      sub\get_user!

    if include_owner
      table.insert targets, @get_user!

    targets

  find_latest_root_post: =>
    import Posts from require "community.models"
    unpack Posts\select "
      where topic_id = ? and depth = 1 order by post_number desc limit 1
    ", @id

  renumber_posts: (parent_post) =>
    import Posts from require "community.models"
    cond = if parent_post
      assert parent_post.topic_id == @id, "expecting"
      {
        parent_post_id: parent_post.id
      }
    else
      {
        topic_id: @id
        parent_post_id: db.NULL
        depth: 1
      }

    tbl = db.escape_identifier Posts\table_name!

    db.query "
      update #{tbl} as posts set post_number = new_number from (
        select id, row_number() over () as new_number
        from #{tbl}
        where #{db.encode_clause cond}
        order by post_number asc
      ) foo
      where posts.id = foo.id and posts.post_number != new_number
    "

  post_needs_approval: =>
    category = @get_category!
    return false unless category
    import Categories from require "community.models"
    category\get_approval_type! == Categories.approval_types.pending

  get_root_order_ranges: (status="default") =>
    import Posts from require "community.models"
    status = Posts.statuses\for_db status

    res = db.query "
      select min(post_number), max(post_number)
      from #{db.escape_identifier Posts\table_name!}
      where topic_id = ? and depth = 1 and parent_post_id is null and status = ?
    ", @id, status

    if res = unpack res
      res.min, res.max

  is_archived: =>
    @status == @@statuses.archived

  is_default: =>
    @status == @@statuses.default

  set_status: (status) =>
    @update status: @@statuses\for_db status

    import CategoryPostLogs from require "community.models"
    if @status == @@statuses.default
      CategoryPostLogs\log_topic_posts @
    else
      CategoryPostLogs\clear_posts_for_topic @

    category = @get_category!
    if category and category.last_topic_id == @id
      category\refresh_last_topic!

  archive: =>
    @refresh "status" unless @status
    return nil unless @status == @@statuses.default
    @set_status "archived"
    true

  get_tags: =>
    return unless @tags
    category = @get_category!
    return @tags unless category
    tags_by_slug = {t.slug, t for t in *category\get_tags!}
    [tags_by_slug[t] for t in *@tags]


  get_bookmark: memoize1 (user) =>
    import Bookmarks from require "community.models"
    Bookmarks\get @, user

  find_subscription: (user) =>
    import Subscriptions from require "community.models"
    Subscriptions\find_subscription @, user

  is_subscribed: memoize1 (user) =>
    import Subscriptions from require "community.models"
    return unless user
    Subscriptions\is_subscribed @, user, user.id == @user_id

  subscribe: (user) =>
    return unless @allowed_to_view user
    return unless user
    import Subscriptions from require "community.models"
    Subscriptions\subscribe @, user, user.id == @user_id

  unsubscribe: (user) =>
    return unless user
    import Subscriptions from require "community.models"
    Subscriptions\unsubscribe @, user, user.id == @user_id

  can_move_to: (user, target_category) =>
    return nil, "missing category" unless target_category
    return nil, "can't move to same category" if target_category.id == @category_id

    parent = @movable_parent_category user

    valid_children = {c.id, true for c in *parent\get_flat_children!}
    valid_children[parent.id] = true

    return nil, "invalid parent category" unless valid_children[target_category.id]
    true

  -- find the highest level category this topic can be moved around in
  movable_parent_category: (user) =>
    category = @get_category!
    return nil, "no category" unless category
    ancestors = category\get_ancestors!

    for i=#ancestors,1,-1
      a = ancestors[i]
      if a\allowed_to_moderate user
        return a

    category

  -- moves without checking permissio:
  move_to_category: (new_category) =>
    assert new_category, "missing category"
    return nil, "can't move topic that isn't part of category" unless @category_id
    return nil, "can't move to directory" if new_category.directory
    return nil, "can't move deleted topic" if @deleted

    -- pending posts

    old_category = @get_category!

    import Posts, CategoryPostLogs, ModerationLogs,
      PendingPosts, PostReports from require "community.models"

    -- this must happen before updating category id
    CategoryPostLogs\clear_posts_for_topic @

    @update {
      category_id: new_category.id
    }

    @clear_loaded_relation "category"

    new_category\refresh_last_topic!
    old_category\refresh_last_topic!

    -- moderation logs
    db.update ModerationLogs\table_name!, {
      category_id: new_category.id
    }, {
      object_type: ModerationLogs.object_types.topic
      object_id: @id
      category_id: old_category.id
    }

    topic_posts = db.list {
      db.raw db.interpolate_query "
        select id from #{db.escape_identifier Posts\table_name!}
        where topic_id = ?
      ", @id
    }

    -- post reports
    db.update PostReports\table_name!, {
      category_id: new_category.id
    }, {
      category_id: old_category.id
      post_id: topic_posts
    }

    db.update PendingPosts\table_name!, {
      category_id: new_category.id
    }, {
      topic_id: @id
      category_id: old_category.id
    }

    CategoryPostLogs\log_topic_posts @
    old_category\update {
      topics_count: db.raw "topics_count - 1"
    }, timestamp: false

    new_category\update {
      topics_count: db.raw "topics_count + 1"
    }, timestamp: false


    true

