db = require "lapis.db"
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
--   flair character varying(255)
-- );
-- ALTER TABLE ONLY community_users
--   ADD CONSTRAINT community_users_pkey PRIMARY KEY (user_id);
--
class CommunityUsers extends Model
  @timestamp: true
  @primary_key: "user_id"

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
    Model.create @, opts

  @preload_users: (users) =>
    @include_in users, "user_id", flip: true
    users

  @for_user: (user_id) =>
    user_id = user_id.id if type(user_id) == "table"
    community_user = @find(:user_id)

    unless community_user
      import safe_insert from require "community.helpers.models"
      community_user = safe_insert @, :user_id
      community_user or= @find(:user_id)

    community_user

  @recount: (...) =>
    import Topics, Posts, Votes from require "community.models"

    id_field = "#{db.escape_identifier @table_name!}.user_id"

    db.update @table_name!, {
      posts_count: db.raw "
        (select count(*) from #{db.escape_identifier Posts\table_name!}
          where user_id = #{id_field}
          and not deleted)
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

  recount: =>
    @@recount user_id: @user_id

  increment: (field, amount=1) =>
    @update {
      [field]: db.raw db.interpolate_query "#{db.escape_identifier field} + ?", amount
    }, timestamp: false

  -- how much do their votes count for, an override point
  get_vote_score: (object) => 1

  -- remove every single post
  purge_posts: =>
    import Posts from require "community.models"

    posts = Posts\select "where user_id = ?", @user_id
    for post in *posts
      post\delete "hard"

    @update {
      posts_count: 0
      topics_count: 0
    }

    true


