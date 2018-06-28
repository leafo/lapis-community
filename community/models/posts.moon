db = require "lapis.db"
import Model from require "community.model"
import enum from require "lapis.db.model"

date = require "date"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_posts (
--   id integer NOT NULL,
--   topic_id integer NOT NULL,
--   user_id integer NOT NULL,
--   parent_post_id integer,
--   post_number integer DEFAULT 0 NOT NULL,
--   depth integer DEFAULT 0 NOT NULL,
--   deleted boolean DEFAULT false NOT NULL,
--   body text NOT NULL,
--   down_votes_count integer DEFAULT 0 NOT NULL,
--   up_votes_count integer DEFAULT 0 NOT NULL,
--   edits_count integer DEFAULT 0 NOT NULL,
--   last_edited_at timestamp without time zone,
--   deleted_at timestamp without time zone,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   status smallint DEFAULT 1 NOT NULL,
--   moderation_log_id integer,
--   body_format smallint DEFAULT 1 NOT NULL
-- );
-- ALTER TABLE ONLY community_posts
--   ADD CONSTRAINT community_posts_moderation_log_id_key UNIQUE (moderation_log_id);
-- ALTER TABLE ONLY community_posts
--   ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);
-- CREATE UNIQUE INDEX community_posts_parent_post_id_post_number_idx ON community_posts USING btree (parent_post_id, post_number);
-- CREATE INDEX community_posts_parent_post_id_status_post_number_idx ON community_posts USING btree (parent_post_id, status, post_number);
-- CREATE INDEX community_posts_topic_id_id_idx ON community_posts USING btree (topic_id, id) WHERE (NOT deleted);
-- CREATE UNIQUE INDEX community_posts_topic_id_parent_post_id_depth_post_number_idx ON community_posts USING btree (topic_id, parent_post_id, depth, post_number);
-- CREATE INDEX community_posts_topic_id_parent_post_id_depth_status_post_numbe ON community_posts USING btree (topic_id, parent_post_id, depth, status, post_number);
-- CREATE INDEX community_posts_user_id_status_id_idx ON community_posts USING btree (user_id, status, id) WHERE (NOT deleted);
--
class Posts extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"user", belongs_to: "Users"}
    {"parent_post", belongs_to: "Posts"}
    {"edits", has_many: "PostEdits", order: "id asc"}

    {"reports", has_many: "PostReports", oreder: "id desc"}

    {"votes", has_many: "Votes", key: "object_id", where: {
      object_type: 1
    }}

    {"moderation_log", belongs_to: "ModerationLogs"}

    {"posts_search", has_one: "PostsSearch"}
  }

  @statuses: enum {
    default: 1
    archived: 2
    spam: 2
  }

  @body_formats: enum {
    html: 1
    markdown: 2
  }

  @create: (opts={}) =>
    assert opts.topic_id, "missing topic id"
    assert opts.user_id, "missing user id"
    assert opts.body, "missing body"

    parent = if id = opts.parent_post_id
      @find id
    else
      with opts.parent_post
        opts.parent_post = nil

    if parent
      assert parent.topic_id == opts.topic_id, "invalid parent (#{parent.topic_id } != #{opts.topic_id})"
      opts.depth = parent.depth + 1
      opts.parent_post_id = parent.id
    else
      opts.depth = 1

    number_cond = {
      topic_id: opts.topic_id
      depth: opts.depth
      parent_post_id: opts.parent_post_id or db.NULL
    }

    post_number = db.interpolate_query "
     (select coalesce(max(post_number), 0) from #{db.escape_identifier @table_name!}
       where #{db.encode_clause number_cond}) + 1
    "

    opts.status = opts.status and @statuses\for_db opts.status
    opts.post_number = db.raw post_number
    opts.body_format = if opts.body_format
      @body_formats\for_db opts.body_format

    super opts, returning: {"status"}

  @preload_mentioned_users: (posts) =>
    import CommunityUsers from require "community.models"

    all_usernames = {}
    usernames_by_post = {}

    for post in *posts
      usernames = @_parse_usernames post.body
      if next usernames
        usernames_by_post[post.id] = usernames
        for u in *usernames
          table.insert all_usernames, u

    users = CommunityUsers\find_users_by_name all_usernames
    users_by_username = {u.username, u for u in *users}

    for post in *posts
      post.mentioned_users = for uname in *usernames_by_post[post.id] or {}
        continue unless users_by_username[uname]
        users_by_username[uname]

    posts

  @_parse_usernames: (body) =>
    [username for username in body\gmatch "@([%w-_]+)"]

  get_mentioned_users: =>
    unless @mentioned_users
      usernames = @@_parse_usernames @body
      import CommunityUsers from require "community.models"
      @mentioned_users = CommunityUsers\find_users_by_name usernames

    @mentioned_users

  filled_body: (r) =>
    body = @body

    if m = @get_mentioned_users!
      mentions_by_username = {u.username, u for u in *m}
      import escape from require "lapis.html"

      body = body\gsub "@([%w-_]+)", (username) ->
        user = mentions_by_username[username]
        return "@#{username}" unless user
        "<a href='#{escape r\build_url r\url_for user}'>@#{escape user\name_for_display!}</a>"

    body

  is_topic_post: =>
    @post_number == 1 and @depth == 1

  allowed_to_vote: (user, direction) =>
    return false if @is_moderation_event!
    return false unless user
    return false if @deleted
    return false if @is_archived!

    topic = @get_topic!

    if category = @topic\get_category!
      category\allowed_to_vote user, direction, @
    else
      true

  allowed_to_edit: (user, action="edit") =>
    return false if @deleted and action != "delete"
    return false unless user
    return true if user\is_admin!
    return false if @is_archived!
    return true if user.id == @user_id
    return false if @is_protected!
    return false if action != "delete" and @deleted

    topic = @get_topic!

    return true if topic\allowed_to_moderate user

    false

  allowed_to_reply: (user, req) =>
    return false if @deleted
    return false if @is_moderation_event!
    return false unless user
    return false unless @is_default!
    topic = @get_topic!
    topic\allowed_to_post user, req

  should_soft_delete: =>
    return false if @is_moderation_event!

    -- older than 10 mins or has replies
    delta = date.diff date(true), date(@created_at)
    delta\spanminutes! > 10 or @has_replies! or @has_next_post!

  delete: (force) =>
    @topic = @get_topic!

    if @is_topic_post! and not @topic.permanent
      return @topic\delete!

    if force != "soft" and (force == "hard" or not @should_soft_delete!)
      return @hard_delete!, "hard"

    @soft_delete!, "soft"

  soft_delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      @update { deleted_at: db.format_date! }, timestamp: false
      import CommunityUsers, Topics, CategoryPostLogs from require "community.models"

      unless @is_moderation_event!
        CommunityUsers\for_user(@get_user!)\increment "posts_count", -1
        CategoryPostLogs\clear_post @

        if topic = @get_topic!
          if topic.last_post_id == @id
            topic\refresh_last_post!

          if category = topic\get_category!
            if category.last_topic_id = topic.id
              category\refresh_last_topic!

          topic\update {
            deleted_posts_count: db.raw "deleted_posts_count + 1"
          }, timestamp: false

      return true

  false

  hard_delete: =>
    return false unless Model.delete @

    import
      CommunityUsers
      ModerationLogs
      PostEdits
      PostReports
      Votes
      ActivityLogs
      CategoryPostLogs
      from require "community.models"

    CommunityUsers\for_user(@get_user!)\increment "posts_count", -1
    CategoryPostLogs\clear_post @

    orphans = @@select "where parent_post_id = ?", @id

    if topic = @get_topic!
      topic\renumber_posts @get_parent_post!

      if topic.last_post_id == @id
        topic\refresh_last_post!

      if category = topic\get_category!
        if category.last_topic_id = topic.id
          category\refresh_last_topic!

      -- it was already soft deleted, no need to update the counts
      unless @deleted
        topic\update {
          posts_count: not @is_moderation_event! and db.raw("posts_count - 1") or nil
          root_posts_count: if @depth == 1
            db.raw "root_posts_count - 1"
        }, timestamp: false

    db.delete ModerationLogs\table_name!, {
      object_type: ModerationLogs.object_types.post_report
      object_id: db.list {
        db.raw db.interpolate_query "
          select id from #{db.escape_identifier PostReports\table_name!}
          where post_id = ?
        ", @id
      }
    }

    for model in *{PostEdits, PostReports}
      db.delete model\table_name!, post_id: @id

    for model in *{Votes, ActivityLogs}
      db.delete model\table_name!, {
        object_type: model.object_types.post
        object_id: @id
      }

    for orphan_post in *orphans
      orphan_post\hard_delete!

    true

  allowed_to_report: (user, req) =>
    return false if @deleted
    return false if @is_moderation_event!
    return false unless user
    return false if user.id == @user_id
    return false unless @is_default!
    return false unless @allowed_to_view user, req
    true

  allowed_to_view: (user, req) =>
    @get_topic!\allowed_to_view user, req

  notification_targets: (extra_targets) =>
    return {} if @is_moderation_event!

    targets = {}

    for user in *@get_mentioned_users!
      targets[user.id] or= {"mention", user.id}

    if parent = @get_parent_post!
      targets[parent.user_id] = {"reply", parent\get_user!, parent}

    topic = @get_topic!
    for target_user in *topic\notification_target_users!
      targets[target_user.id] or= {"post", target_user, topic}

    if category = @is_topic_post! and topic\get_category!
      for target_user in *category\notification_target_users!
        targets[target_user.id] or= {"topic", target_user, category, topic}

      category_group = category\get_category_group!
      if category_group
        for target_user in *category_group\notification_target_users!
          targets[target_user.id] or= {"topic", target_user, category_group, topic}

    if extra_targets
      for t in *extra_targets
        user = t[2]
        targets[user.id] or= t

    -- don't notify poster of own post
    targets[@user_id] = nil

    [v for _, v in pairs targets]

  get_ancestors: =>
    unless @ancestors
      if @depth == 1
        @ancestors = {}
        return @ancestors

      tname = db.escape_identifier @@table_name!

      @ancestors = db.query "
        with recursive nested as (
          (select * from #{tname} where id = ?)
          union
          select pr.* from #{tname} pr, nested
            where pr.id = nested.parent_post_id
        )
        select * from nested
      ", @parent_post_id

      for post in *@ancestors
        @@load post

      table.sort @ancestors, (a,b) ->
        a.depth > b.depth

    @ancestors

  get_root_ancestor: =>
    ancestors = @get_ancestors!
    ancestors[#ancestors]

  has_replies: =>
    not not unpack Posts\select "where parent_post_id = ? and not deleted limit 1", @id, fields: "1"

  -- post next in the same depth/parent
  has_next_post: =>
    clause = db.encode_clause {
      topic_id: @topic_id
      parent_post_id: @parent_post_id or db.NULL
      depth: @depth
    }

    not not unpack Posts\select "
      where #{clause} and post_number > ?
      limit 1
    ", @post_number, fields: "1"

  set_status: (status) =>
    @update status: @@statuses\for_db status

    import CategoryPostLogs from require "community.models"
    if @status == @@statuses.default
      CategoryPostLogs\log_post @
    else
      CategoryPostLogs\clear_post @

    topic = @get_topic!
    if topic.last_post_id == @id
      topic\refresh_last_post!

  archive: =>
    return nil unless @status == @@statuses.default
    return nil, "can only archive root post" unless @depth == 1
    @set_status "archived"
    true

  is_archived: =>
    @status == @@statuses.archived

  is_default: =>
    @status == @@statuses.default

  is_protected: =>
    @get_topic!\is_protected!

  vote_score: =>
    @up_votes_count - @down_votes_count

  on_vote_callback: (vote) =>
    if topic = @is_topic_post! and @get_topic!
      topic.topic_post = @

      category = topic\get_category!
      if category and category\order_by_score!
        topic\update {
          category_order: topic\calculate_score_category_order!
        }

  is_moderation_event: =>
    not not @moderation_log_id

  refresh_search_index: =>
    search = @get_posts_search!
    if @should_index_for_search!
      import PostsSearch from require "community.models"
      PostsSearch\index_post @
    else
      if search
        search\delete!

  -- returns nil by default so you can override and do what you want
  -- with it
  should_index_for_search: =>
    if @deleted
      return false

    topic = @get_topic!

    if not topic or topic.deleted
      return false

    nil


