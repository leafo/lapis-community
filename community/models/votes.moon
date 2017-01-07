db = require "lapis.db"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_votes (
--   user_id integer NOT NULL,
--   object_type integer NOT NULL,
--   object_id integer NOT NULL,
--   positive boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   ip inet,
--   counted boolean DEFAULT true NOT NULL,
--   score integer
-- );
-- ALTER TABLE ONLY community_votes
--   ADD CONSTRAINT community_votes_pkey PRIMARY KEY (user_id, object_type, object_id);
-- CREATE INDEX community_votes_object_type_object_id_idx ON community_votes USING btree (object_type, object_id);
--
class Votes extends Model
  @timestamp: true
  @primary_key: {"user_id", "object_type", "object_id"}

  @current_ip_address: =>
    ngx and ngx.var.remote_addr

  @relations: {
    {"user", belongs_to: "Users"}

    {"object", polymorphic_belongs_to: {
      [1]: {"post", "Posts"}
    }}
  }

  @preload_post_votes: (posts, user_id) =>
    return unless user_id
    posts_with_votes = [p for p in *posts when p.down_votes_count > 0 or p.up_votes_count > 0 or p.user_id == user_id]

    @include_in posts_with_votes, "object_id", {
      flip: true
      where: {
        object_type: Votes.object_types.post
        :user_id
      }
    }

  -- NOTE: vote and unvote are the public interface
  @create: (opts={}) =>
    assert opts.user_id, "missing user id"

    unless opts.object_id and opts.object_type
      assert opts.object, "missing vote object"
      opts.object_id = opts.object.id
      opts.object_type = @object_type_for_object opts.object
      opts.object = nil

    opts.object_type = @object_types\for_db opts.object_type
    opts.ip or= @current_ip_address!

    super opts

  @vote: (object, user, positive=true) =>
    import upsert from require "community.helpers.models"

    object_type = @object_type_for_object object
    old_vote = @find user.id, object_type, object.id

    import CommunityUsers from require "community.models"
    cu = CommunityUsers\for_user user

    params = {
      :object_type
      object_id: object.id
      user_id: user.id
      positive: not not positive
      ip: @current_ip_address!
      counted: cu\count_vote_for object
      score: cu\get_vote_score object, positive
    }

    action, vote = upsert @, params

    -- decrement and increment if positive changed
    if action == "update" and old_vote
      old_vote\decrement!

    vote\increment!

    action, vote

  @unvote: (object, user) =>
    object_type = @object_type_for_object object

    clause = {
      :object_type
      object_id: object.id
      user_id: user.id
    }

    res = unpack db.query "
      delete from #{db.escape_identifier @table_name!}
      where #{db.encode_clause clause}
      returning *
    "

    return unless res

    deleted_vote = @load res
    deleted_vote\decrement!
    true

  name: =>
    @positive and "up" or "down"

  trigger_vote_callback: (res) =>
    object = unpack res
    return unless object

    model = @@model_for_object_type @object_type
    model\load object

    if object.on_vote_callback
      object\on_vote_callback @

    res

  increment: =>
    model = @@model_for_object_type @object_type
    counter_name = @post_counter_name!

    score = @score or 1

    unless @counted == false
      @trigger_vote_callback db.update model\table_name!, {
        [counter_name]: db.raw "#{db.escape_identifier counter_name} + #{db.escape_literal score}"
      }, {
        id: @object_id
      }, db.raw "*"

  decrement: =>
    model = @@model_for_object_type @object_type
    counter_name = @post_counter_name!

    score = @score or 1

    unless @counted == false
      @trigger_vote_callback db.update model\table_name!, {
        [counter_name]: db.raw "#{db.escape_identifier counter_name} - #{db.escape_literal score}"
      }, {
        id: @object_id
      }, db.raw "*"

  updated_counted: (counted) =>
    res = db.update @@table_name!, {
      :counted
    }, {
      user_id: @user_id
      object_type: @object_type
      object_id: @object_type
      counted: not counted
    }

    if res.affected_rows and res.affected_rows > 0
      if counted
        @increment!
      else
        @decrement!

  post_counter_name: =>
    if @positive
      "up_votes_count"
    else
      "down_votes_count"
