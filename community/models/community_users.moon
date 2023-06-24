db = require "lapis.db"
import enum from require "lapis.db.model"
import Model, VirtualModel from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_users (
--   user_id integer NOT NULL,
--   posts_count integer DEFAULT 0 NOT NULL,
--   topics_count integer DEFAULT 0 NOT NULL,
--   votes_count integer DEFAULT 0 NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   flair character varying(255),
--   recent_posts_count integer DEFAULT 0 NOT NULL,
--   last_post_at timestamp without time zone,
--   posting_permission smallint DEFAULT 1 NOT NULL,
--   received_up_votes_count integer DEFAULT 0 NOT NULL,
--   received_down_votes_count integer DEFAULT 0 NOT NULL,
--   received_votes_adjustment integer DEFAULT 0 NOT NULL
-- );
-- ALTER TABLE ONLY community_users
--   ADD CONSTRAINT community_users_pkey PRIMARY KEY (user_id);
--
class CommunityUsers extends Model
  @timestamp: true
  @primary_key: "user_id"

  with_user: VirtualModel\make_loader "user_users", (user_id) =>
    assert user_id, "expecting user id"
    UserUsers = require "community.models.virtual.user_users"
    UserUsers\load {
      source_user_id: @user_id
      dest_user_id: user_id
    }

  -- this method is used by any model that wants to know the current IP.
  @current_ip_address: =>
    ngx and ngx.var.remote_addr

  @posting_permissions: enum {
    default: 1
    only_own: 2 -- User blocked from posting except on places they moderate
    blocked: 3 -- User blocked from posting anywhere
    needs_approval: 4 -- User's post will be forced into pending unles they can moderate the destination
  }

  @recent_threshold: "10 minutes"

  -- just so it can be community_users and not community_community_users
  @table_name: =>
    import prefix_table from require "community.model"
    name = prefix_table "users"
    @table_name = -> name
    name

  @relations: {
    {"user", belongs_to: "Users"}

    {"all_warnings", has_many: "warnings"
      key: "user_id"
      order: "id asc"
    }

    {"active_warnings", has_many: "warnings"
      key: "user_id"
      order: "id asc"
      where: db.clause {
        "expires_at IS NULL or now() at time zone 'utc' < expires_at"
      }
    }

    {"pending_posts", has_many: "PendingPosts"
      key: "user_id"
      order: "id asc"
    }
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    if opts.posting_permission
      opts.posting_permission = @posting_permissions\for_db opts.posting_permission

    super opts

  @preload_users: (users) =>
    @include_in users, user_id: "id"
    users

  @for_user: (user_id) =>
    user_id = user_id.id if type(user_id) == "table"
    community_user = @find(:user_id)

    unless community_user
      import insert_on_conflict_ignore from require "community.helpers.models"
      community_user = insert_on_conflict_ignore @, :user_id
      community_user or= @find(:user_id)

    community_user

  @recount: (...) =>
    import Topics, Posts, Votes from require "community.models"

    id_field = "#{db.escape_identifier @table_name!}.user_id"

    db.update @table_name!, {
      -- TODO: this should not count topics, but it currently does
      -- or we need to work out something to make this work
      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!} as posts
          where user_id = #{id_field}
          and not deleted and moderation_log_id is null)
      "

      -- TODO: should this count "uncounted" votes?
      votes_count: db.raw "
        (select count(*) from #{db.escape_identifier Votes\table_name!}
          where user_id = #{id_field})
      "

      topics_count: db.raw "
        (select count(*) from #{db.escape_identifier Topics\table_name!}
          where user_id = #{id_field}
          and not deleted and not permanent)
      "
    }, ...

  -- overridable method for username based mentions
  @find_users_by_name: (names) =>
    import Users from require "models"
    Users\find_all names, key: "username"

  @increment: (user_id, field, amount) =>
    assert user_id, "missing user_id"
    assert field, "missing field"
    assert type(amount) == "number", "missing or invalid number"

    import insert_on_conflict_update from require "community.helpers.models"

    insert_on_conflict_update @, {
      :user_id
    }, {
      [field]: amount
    }, {
      [field]: db.raw "#{db.escape_identifier @table_name!}.#{db.escape_identifier field} + excluded.#{db.escape_identifier field}"
    }

  get_block_recieved: (user) =>
    @with_user(user.id or user.user_id)\get_block_recieved!

  get_block_given: (user) =>
    @with_user(user.id or user.user_id)\get_block_given!

  -- object: where the user is posting to, must be either category for new topic, or topic for new post/reply
  -- returns bool, a warning object if one is applied or nil
  needs_approval_to_post: (object) =>
    switch @posting_permission or @@posting_permissions.default
      when @@posting_permissions.needs_approval
        unless object\allowed_to_moderate @get_user!
          return true

    import Warnings from require "community.models"
    for warning in *@get_active_warnings!
      if warning.restriction == Warnings.restrictions.pending_posting
        return true, warning

    false

  -- how popular are they (function of received votes)
  -- will help sort their replies
  get_popularity_score: =>
    @received_up_votes_count - @received_down_votes_count + @received_votes_adjustment

  refresh_received_votes: =>
    @update {
      received_up_votes_count: db.raw db.interpolate_query "coalesce((select sum(up_votes_count) from posts where not deleted and user_id = ?), 0)", @user_id
      received_down_votes_count: db.raw db.interpolate_query "coalesce((select sum(down_votes_count) from posts where not deleted and user_id = ?), 0)", @user_id
    }, timestamp: false

  -- This function is only responsible for checking the user's own permissions,
  -- and not the permissions of categories or topics
  -- object: where the user is posting to, must be either category for new topic, or topic for new post/reply
  allowed_to_post: (object) =>
    switch @posting_permission or @@posting_permissions.default
      when @@posting_permissions.blocked
        return false
      when @@posting_permissions.only_own
        unless object\allowed_to_moderate @get_user!
          return false

    import Warnings from require "community.models"

    -- make sure they have no warnings blocking posting
    for warning in *@get_active_warnings!
      if warning.restriction == Warnings.restrictions.block_posting
        -- see if they are allowed to moderate, then break the warning
        if object\allowed_to_moderate @get_user!
          break

        return false, "your account has an active warning", warning

    true

  recount: =>
    @@recount user_id: @user_id
    @refresh!

  increment: (field, amount=1) =>
    @update {
      [field]: db.raw db.interpolate_query "#{db.escape_identifier field} + ?", amount
    }, timestamp: false

  increment_from_post: (post, created_topic=false) =>
    @update {
      posts_count: db.raw "posts_count + 1"
      topics_count: if created_topic then db.raw "topics_count + 1"
      -- start over if it's been longer than interval since the last recent post
      recent_posts_count: db.raw db.interpolate_query(
        "(case when last_post_at + ?::interval >= now() at time zone 'utc' then recent_posts_count else 0 end) + 1"
        @@recent_threshold
      )
      last_post_at: db.raw "date_trunc('second', now() at time zone 'utc')"
    }, timestamp: false

  -- how much do their votes count for, an override point
  get_vote_score: (object, positive) => 1

  count_vote_for: (object) =>
    object.user_id != @user_id

  -- this purges the reports the user has *created*, not received
  purge_reports: =>
    import PostReports from require "community.models"

    import OrderedPaginator from require "lapis.db.pagination"

    count = 0

    -- TODO: there is no index on this query
    pager = OrderedPaginator PostReports, "id", "where user_id = ?", @user_id, {
      per_page: 1000
    }

    for report in pager\each_item!
      if report\delete!
        count += 1

    count

  purge_votes: =>
    import Votes from require "community.models"

    count = 0

    import OrderedPaginator from require "lapis.db.pagination"

    pager = OrderedPaginator Votes, {"object_type", "object_id"},"where user_id = ?", @user_id, {
      per_page: 1000
    }

    for vote in pager\each_item!
      if vote\delete!
        count += 1

    count

  -- remove every single post
  purge_posts: =>
    import Posts from require "community.models"

    count = 0

    import OrderedPaginator from require "lapis.db.pagination"

    pager = OrderedPaginator Posts, {"id"}, "where user_id = ?", @user_id, {
      per_page: 1000
    }

    for post in pager\each_item!
      if post\delete "hard"
        count += 1

    count

  posting_rate: (minutes) =>
    assert type(minutes) == "number" and minutes > 0

    date = require "date"
    return 0 unless @last_post_at
    since_last_post = date.diff(date(true), date(@last_post_at))\spanminutes!

    if since_last_post > minutes
      return 0

    import ActivityLogs from require "community.models"

    logs = ActivityLogs\select(
      "where user_id = ? and
        created_at >= (now() at time zone 'utc' - ?::interval) and
        (action, object_type) in ?
      order by id desc"
      @user_id
      "#{minutes} minutes"
      db.list {
        db.list {
          ActivityLogs.actions.post.create
          ActivityLogs.object_types.post
        }
        db.list {
          ActivityLogs.actions.topic.create
          ActivityLogs.object_types.topic
        }
      }
      fields: "id"
    )

    #logs / minutes

