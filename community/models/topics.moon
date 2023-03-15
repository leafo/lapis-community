db = require "lapis.db"

import Model, VirtualModel from require "community.model"
import slugify from require "lapis.util"
import enum from require "lapis.db.model"
import preload from require "lapis.db.model"

VOTE_TYPES_DEFAULT = { down: true, up: true }

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
--   tags character varying(255)[],
--   rank_adjustment integer DEFAULT 0 NOT NULL,
--   protected boolean DEFAULT false NOT NULL,
--   data jsonb
-- );
-- ALTER TABLE ONLY community_topics
--   ADD CONSTRAINT community_topics_pkey PRIMARY KEY (id);
-- CREATE INDEX community_topics_category_id_idx ON community_topics USING btree (category_id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_topics_category_id_sticky_status_category_order_idx ON community_topics USING btree (category_id, sticky, status, category_order) WHERE ((NOT deleted) AND (category_id IS NOT NULL));
-- CREATE INDEX community_topics_user_id_idx ON community_topics USING btree (user_id) WHERE (user_id IS NOT NULL);
--
class Topics extends Model
  @timestamp: true

  class TopicViewers extends VirtualModel
    @primary_key: {"topic_id", "user_id"}

    @relations: {
      {"subscription", has_one: "Subscriptions", key: {
        user_id: "user_id"
        object_id: "topic_id"
      }, where: {
        object_type: 1
      }}

      {"bookmark", has_one: "Bookmarks", key: {
        user_id: "user_id"
        object_id: "topic_id"
      }, where: {
        object_type: 2
      }}

      {"last_seen", has_one: "UserTopicLastSeens", key: {"user_id", "topic_id"}}

      {"ban", has_one: "Bans", key: {
        banned_user_id: "user_id"
        object_id: "topic_id"
      }, where: {
        object_type: 2
      }}
    }

  @relations: {
    {"category", belongs_to: "Categories"}
    {"user", belongs_to: "Users"}
    {"posts", has_many: "Posts"}
    {"topic_post", has_one: "Posts", key: "topic_id", where: {
      parent_post_id: db.NULL
      post_number: 1
      depth: 1
    }}
    {"last_post", belongs_to: "Posts"}
    {"subscriptions", has_many: "Subscriptions", key: "object_id", where: {object_type: 1}}
    {"moderation_logs", has_many: "ModerationLogs", key: "object_id", where: {object_type: 1}}
  }

  @statuses: enum {
    default: 1
    archived: 2
    spam: 3
    hidden: 4
  }

  @create: (opts={}) =>
    if opts.title
      opts.slug or= slugify opts.title

    opts.status = opts.status and @statuses\for_db opts.status
    opts.category_order or= @update_category_order_sql opts.category_id

    if opts.data
      import db_json from require "community.helpers.models"
      opts.data = db_json opts.data

    super opts, returning: {"status"}

  @update_category_order_sql: (category_id) =>
    return nil unless category_id

    db.raw db.interpolate_query "
      (select coalesce(max(category_order), 0) + 1
      from #{db.escape_identifier @table_name!}
      where category_id = ?)
    ", category_id

  @calculate_score_category_order: (score, created_at, time_bucket) =>
    import Categories from require "community.models"
    start = Categories.score_starting_date

    date = require "date"

    e = date.epoch!

    time_score = (date.diff(date(created_at), e)\spanseconds! - start) / time_bucket
    adjusted_score = 2 * math.log10 math.max 1, math.abs(score) + 1
    adjusted_score = -adjusted_score unless score > 0

    math.floor (time_score + adjusted_score) * 1000

  @recount: (...) =>
    import Posts from require "community.models"

    id_field = "#{db.escape_identifier @table_name!}.id"

    db.update @table_name!, {
      root_posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{id_field}
          and depth = 1)
      "

      deleted_posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{id_field} and
            deleted and
            moderation_log_id is null)
      "

      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where topic_id = #{id_field} and
            not deleted and
            moderation_log_id is null)
      "
    }, ...

  @preload_bans: (topics, user) =>
    return unless user
    return unless next topics

    preload [t\with_user(user.id) for t in *topics], "ban"
    true

  with_user: VirtualModel\make_loader "topic_viewers", (user_id) =>
    assert user_id, "expecting user id"
    TopicViewers\load {
      user_id: user_id
      topic_id: @id
    }

  -- NOTE: this intentionally does not check if
  -- NOTE: this doesn't check ban??
  -- community_user\allowed_to_post, as that's a different phase
  allowed_to_post: (user, req) =>
    return false unless user
    return false if @deleted
    return false if @locked
    return false unless @is_default! or @is_hidden!

    @allowed_to_view user, req

  allowed_to_view: (user, req) =>
    return false if @deleted

    if @category_id
      unless @get_category!\allowed_to_view user, req
        return false

    if @get_ban user
      return false

    true

  allowed_to_edit: (user) =>
    return false if @deleted
    return false unless user
    return true if user\is_admin!
    return false if @is_protected!
    return false if @is_archived!
    return true if user.id == @user_id
    return true if @allowed_to_moderate user

    false

  allowed_to_moderate: (user) =>
    return false if @deleted
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
    is_moderation_log = post\is_moderation_event!

    category_order = unless is_moderation_log or (opts and opts.update_category_order == false)
      import Categories from require "community.models"
      category = @get_category!
      if category and category\order_by_date!
        Topics\update_category_order_sql @category_id

    posts_count = if not is_moderation_log
      db.raw "posts_count + 1"

    root_posts_count = if post.depth == 1
      -- root_posts_count is used for pagination, so it should include
      -- moderation events
      db.raw "root_posts_count + 1"

    @update {
      :posts_count
      :root_posts_count
      last_post_id: not is_moderation_log and post.id or nil
      :category_order
    }, timestamp: false


    if posts_count
      @on_increment_callback "posts_count", 1

    if root_posts_count
      @on_increment_callback "root_posts_count", 1

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
            moderation_log_id is null and
            (depth != 1 or post_number != 1)
        order by id desc
        limit 1
      )", @id, @@statuses.default
    }, timestamp: false

  delete: (force) =>
    if force == "hard"
      @hard_delete!
    else
      @soft_delete!

  hard_delete: =>
    res = db.query "delete from #{db.escape_identifier @@table_name!} where #{db.encode_clause @_primary_cond!} returning *"

    unless res and res.affected_rows and res.affected_rows > 0
      return false

    deleted_topic = unpack res

    was_soft_deleted = deleted_topic.deleted

    for post in *@get_posts!
      post\hard_delete deleted_topic

    import
      PendingPosts
      TopicParticipants
      UserTopicLastSeens
      CategoryPostLogs
      CommunityUsers
      from require "community.models"

    CategoryPostLogs\clear_posts_for_topic @

    if not was_soft_deleted and @user_id
      CommunityUsers\increment @user_id, "topics_count", -1

    if category = @get_category!
      restore_deleted_count = if was_soft_deleted
        db.raw "deleted_topics_count - 1"

      category\update {
        topics_count: db.raw "topics_count - 1"
        deleted_topics_count: restore_deleted_count
      }, timestamp: false

      if category.last_topic_id == @id
        category\refresh_last_topic!

    for model in *{
      PendingPosts
      TopicParticipants
      UserTopicLastSeens
    }
      db.delete model\table_name!, topic_id: assert @id

    true

  -- soft delete does not delete all the posts in the topic, so the post
  -- counters of the users are not incremented
  soft_delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      @update { deleted_at: db.format_date! }, timestamp: false

      import CommunityUsers, Categories, CategoryPostLogs from require "community.models"
      CategoryPostLogs\clear_posts_for_topic @

      if @user_id
        CommunityUsers\increment @user_id, "topics_count", -1

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
    @with_user(user.id)\get_ban!

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

  available_vote_types: (post) =>
    if category = @get_category!
      category\available_vote_types post
    else
      VOTE_TYPES_DEFAULT

  set_seen: (user) =>
    return unless user
    return unless @last_post_id

    import insert_on_conflict_update from require "community.helpers.models"
    import UserTopicLastSeens from require "community.models"

    insert_on_conflict_update UserTopicLastSeens, {
      user_id: user.id
      topic_id: @id
    }, {
      post_id: @last_post_id
    }

  has_unread: (user) =>
    return false unless user
    -- never any unread if topic has no posts
    return false unless @last_post_id

    if last_seen = @with_user(user.id)\get_last_seen!
      last_seen.post_id < @last_post_id
    else
      false

  -- TODO: should this use pagination?
  notification_target_users: =>
    import Subscriptions from require "community.models"
    subs = @get_subscriptions!
    preload subs, "user"

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

  reposition_post: (post, position) =>
    assert post.topic_id == @id, "post is not in topic"
    assert position, "missing position"

    import Posts from require "community.models"

    tbl = db.escape_identifier Posts\table_name!

    cond = {
      parent_post_id: post.parent_post_id or db.NULL
      topic_id: @id
      depth: post.depth
    }

    order_number = if position < post.post_number
      position - 0.5
    else
      position + 0.5

    db.query "
      update #{tbl} as posts set post_number = new_number
      from (
        select id, row_number() over (
          order by (case #{tbl}.id
            when ? then ?
            else #{tbl}.post_number
          end) asc
        ) as new_number
        from #{tbl}
        where #{db.encode_clause cond}
      ) foo
      where posts.id = foo.id and posts.post_number != new_number
    ", post.id, order_number

  renumber_posts: (parent_post, field="post_number") =>
    import Posts from require "community.models"
    cond = if parent_post
      assert parent_post.topic_id == @id, "parent post is not in the correct topic"
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

    order = "order by #{db.escape_identifier field} asc"

    db.query "
      update #{tbl} as posts set post_number = new_number from (
        select id, row_number() over (#{order}) as new_number
        from #{tbl}
        where #{db.encode_clause cond}
        #{order}
      ) foo
      where posts.id = foo.id and posts.post_number != new_number
    "

  -- returns boolean, and potential warning if warning is issued
  post_needs_approval: (user, post_params) =>
    return false if @allowed_to_moderate user

    import Categories, CommunityUsers from require "community.models"

    if category = @get_category!
      if category\get_approval_type! == Categories.approval_types.pending
        return true

    if cu = CommunityUsers\for_user user
      needs_approval, warning = cu\need_approval_to_post!
      if needs_approval
        return true, warning

    false

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
    @status == @@statuses.archived or (@get_category! and @get_category!.archived)

  is_hidden: =>
    @status == @@statuses.hidden

  is_protected: =>
    @protected

  is_default: =>
    @status == @@statuses.default and not @is_archived!

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

  hide: =>
    @refresh "status" unless @status

    switch @status
      when @@statuses.default
        @set_status "hidden"
        true
      else
        nil, "can't hide from status: #{@@statuses\to_name @status}"

  archive: =>
    @refresh "status" unless @status
    switch @status
      when @@statuses.default, @@statuses.hidden
        @set_status "archived"
        true
      else
        nil, "can't archive from status: #{@@statuses\to_name @status}"

  get_tags: =>
    return unless @tags
    category = @get_category!
    return @tags unless category
    tags_by_slug = {t.slug, t for t in *category\get_tags!}
    [tags_by_slug[t] for t in *@tags]

  get_bookmark: (user) =>
    @with_user(user.id)\get_bookmark!

  find_subscription: (user) =>
    @with_user(user.id)\get_subscription!

  is_subscribed: (user) =>
    default_subscribed = user.id == @user_id
    if sub = @find_subscription user
      sub\is_subscribed!
    else
      default_subscribed

  subscribe: (user, req) =>
    import Subscriptions from require "community.models"
    Subscriptions\subscribe @, user, user.id == @user_id

  unsubscribe: (user) =>
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

  get_score: =>
    post = @get_topic_post!

    return 0 unless post
    post.up_votes_count - post.down_votes_count

  calculate_score_category_order: =>
    adjust = @rank_adjustment or 0
    @@calculate_score_category_order @get_score! + adjust, @created_at, @get_category!\topic_score_bucket_size!

  update_rank_adjustment: (amount) =>
    category = @get_category!
    return nil, "no category" unless category
    return nil, "category not ranked by score" unless category\order_by_score!

    @rank_adjustment = amount or 0

    @update {
      rank_adjustment: amount
      category_order: @calculate_score_category_order!
    }

  increment_counter: (field, amount) =>
    res = @update {
      [field]: db.raw db.interpolate_query "#{db.escape_identifier field} + ?", amount
    }, timestamp: false

    @on_increment_callback field, amount

    res

  on_increment_callback: (field, amount) =>
    -- for subclasses

