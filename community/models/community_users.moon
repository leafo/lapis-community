db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

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
--   posting_permission smallint DEFAULT 1 NOT NULL
-- );
-- ALTER TABLE ONLY community_users
--   ADD CONSTRAINT community_users_pkey PRIMARY KEY (user_id);
--
class CommunityUsers extends Model
  @timestamp: true
  @primary_key: "user_id"

  @posting_permissions: enum {
    default: 1
    only_own: 2
    blocked: 3
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
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    if opts.posting_permission
      opts.posting_permission = @posting_permissions\for_db opts.posting_permission

    super opts

  @preload_users: (users) =>
    @include_in users, "user_id", flip: true
    users

  @allowed_to_post: (user, object) =>
    if community_user = @find user_id: user.id
      community_user.user = user
      community_user\allowed_to_post object
    else
      true -- default is true

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
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where user_id = #{id_field}
          and not deleted and moderation_log_id is null)
      "

      votes_count: db.raw "
        (select count(*) from #{db.escape_identifier Votes\table_name!}
          where user_id = #{id_field})
      "

      topics_count: db.raw "
        (select count(*) from #{db.escape_identifier Topics\table_name!}
          where user_id = #{id_field}
          and not deleted)
      "
    }, ...

  @find_users_by_name: (names) =>
    import Users from require "models"
    Users\find_all names, key: "username"

  -- how popular are they (function of received votes)
  -- will help sort their replies
  get_popularity_score: =>
    @received_up_votes_count - @received_down_votes_count + @received_votes_adjustment

  refresh_received_votes: =>
    @update {
      received_up_votes_count: db.raw db.interpolate_query "coalesce((select sum(up_votes_count) from posts where not deleted and user_id = ?), 0)", @user_id
      received_down_votes_count: db.raw db.interpolate_query "coalesce((select sum(down_votes_count) from posts where not deleted and user_id = ?), 0)", @user_id
    }, timestamp: false

  allowed_to_post: (object) =>
    switch @posting_permission or @@posting_permissions.default
      when @@posting_permissions.default
        true
      when @@posting_permissions.blocked
        false
      when @@posting_permissions.only_own
        if object.allowed_to_edit
          object\allowed_to_edit @get_user!
        else
          false
      else
        error "unknown posting permission: #{@posting_permission}"

  recount: =>
    @@recount user_id: @user_id
    @refresh!

  increment: (field, amount=1) =>
    @update {
      [field]: db.raw db.interpolate_query "#{db.escape_identifier field} + ?", amount
    }, timestamp: false

  increment_from_post: (post, created_topic=false) =>
    @update {
      posts_count: if not created_topic then db.raw "posts_count + 1"
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

  purge_votes: =>
    import Votes from require "community.models"

    decrement = 0
    for vote in *Votes\select "where user_id = ?", @user_id
      if vote\delete!
        decrement += 1

    @update {
      votes_count: db.raw db.interpolate_query "votes_count - ?", decrement
    }

    true

  -- remove every single post
  purge_posts: =>
    import Posts from require "community.models"

    posts = Posts\select "where user_id = ?", @user_id
    for post in *posts
      post\delete "hard"

    -- TODO: this should no longer be necessary since counter adjustment is fixed
    @update {
      posts_count: 0
      topics_count: 0
    }

    true

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




