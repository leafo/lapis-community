db = require "lapis.db"
import Model from require "community.model"

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
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_posts
--   ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);
-- CREATE UNIQUE INDEX community_posts_parent_post_id_post_number_idx ON community_posts USING btree (parent_post_id, post_number);
-- CREATE INDEX community_posts_topic_id_id_idx ON community_posts USING btree (topic_id, id) WHERE (NOT deleted);
-- CREATE UNIQUE INDEX community_posts_topic_id_parent_post_id_depth_post_number_idx ON community_posts USING btree (topic_id, parent_post_id, depth, post_number);
--
class Posts extends Model
  @timestamp: true

  @relations: {
    {"topic", belongs_to: "Topics"}
    {"user", belongs_to: "Users"}
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
      assert parent.topic_id == opts.topic_id, "invalid parent"
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

    opts.post_number = db.raw post_number
    Model.create @, opts

  @preload_mentioned_users: (posts) =>
    import Users from require "models"
    all_usernames = {}
    usernames_by_post = {}

    for post in *posts
      usernames = @_parse_usernames post.body
      if next usernames
        usernames_by_post[post.id] = usernames
        for u in *usernames
          table.insert all_usernames, u

    users = Users\find_all all_usernames, key: "username"
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
      import Users from require "models"
      @mentioned_users = Users\find_all usernames, key: "username"

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
    return false unless user
    return false if @deleted

    topic = @get_topic!
    category = @topic\get_category!

    if category
      category\allowed_to_vote user, direction
    else
      true

  allowed_to_edit: (user) =>
    return false unless user
    return true if user\is_admin!
    return true if user.id == @user_id
    return false if @deleted

    topic = @get_topic!

    return true if topic\allowed_to_moderate user

    false

  allowed_to_reply: (user) =>
    return false unless user
    true

  delete: =>
    import soft_delete from require "community.helpers.models"

    if soft_delete @
      @update { deleted_at: db.format_date! }, timestamp: false
      import CommunityUsers, Topics from require "community.models"
      CommunityUsers\for_user(@get_user!)\increment "posts_count", -1

      Topics\load(id: @topic_id)\update {
        deleted_posts_count: db.raw "deleted_posts_count + 1"
      }, timestamp: false

      return true

  false

  allowed_to_report: (user) =>
    return false unless user
    return false if user.id == @user_id
    return false unless @allowed_to_view user
    true

  allowed_to_view: (user) =>
    @get_topic!\allowed_to_view user

