db = require "lapis.db"
import Model from require "community.model"

import preload from require "lapis.db.model"

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

  @relations: {
    {"user", belongs_to: "Users"}

    {"object", polymorphic_belongs_to: {
      [1]: {"post", "Posts"}
    }}
  }

  -- this function tries to avoid fecthing for empty data by filtering to
  -- posts we know have a vote. This will not work if the vote counter cache
  -- is out of sync
  @preload_post_votes: (posts, user_id) =>
    return unless user_id
    with_votes = [p\with_viewing_user(user_id) for p in *posts when p.down_votes_count > 0 or p.up_votes_count > 0 or p.user_id == user_id]
    preload with_votes, "vote"

  -- NOTE: vote and unvote are the public interface
  @create: (opts={}) =>
    assert opts.user_id, "missing user id"

    unless opts.object_id and opts.object_type
      assert opts.object, "missing vote object"
      opts.object_id = opts.object.id
      opts.object_type = @object_type_for_object opts.object
      opts.object = nil

    opts.object_type = @object_types\for_db opts.object_type

    unless opts.ip
      import CommunityUsers from require "community.models"
      opts.ip = CommunityUsers\current_ip_address!

    super opts

  -- this will attempt to record a vote, and update any related counters
  -- if the vote could not be atomically created (because another request
  -- created a vote) then this method will return nil
  @vote: (object, user, positive=true, opts) =>
    assert user, "missing user to create vote from"
    assert object, "missing object to create vote from"

    import insert_on_conflict_ignore from require "community.helpers.models"

    object_type = @object_type_for_object object

    -- try to clear out existing vote
    @load({
      :object_type
      object_id: object.id
      user_id: user.id
    })\delete!

    import CommunityUsers from require "community.models"

    local cu

    score = if opts and opts.score != nil
      opts.score
    else
      cu or= CommunityUsers\for_user user
      cu\get_vote_score object, positive

    counted = if opts and opts.counted != nil
      opts.counted
    else
      cu or= CommunityUsers\for_user user
      cu\count_vote_for object

    vote = insert_on_conflict_ignore @, {
      :object_type
      object_id: object.id
      user_id: user.id
      positive: not not positive
      ip: CommunityUsers\current_ip_address!
      :counted
      :score
    }

    if vote
      vote\increment!

    vote

  @unvote: (object, user) =>
    object_type = @object_type_for_object object

    @load({
      :object_type
      object_id: object.id
      user_id: user.id
    })\delete!

  delete: =>
    -- we refetch the row on delete to ensure the decrement is looking the
    -- most recent vote data

    deleted, res = super db.raw "*"

    if res and res[1]
      deleted_vote = @@load res[1]
      deleted_vote\decrement!

    deleted

  name: =>
    @positive and "up" or "down"

  -- kind: "increment", "decrement"
  trigger_vote_callback: (kind) =>
    object = @get_object!
    if object.on_vote_callback
      object\on_vote_callback kind, @

  -- increment applies the vote (whether it's positive or negative)
  increment: =>
    return if @counted == false

    import CommunityUsers from require "community.models"
    CommunityUsers\increment @user_id, "votes_count", 1
    @trigger_vote_callback "increment"

  -- decrement undoes the vote (regardless of positive or negative)
  decrement: =>
    return if @counted == false

    import CommunityUsers from require "community.models"
    CommunityUsers\increment @user_id, "votes_count", -1
    @trigger_vote_callback "decrement"

  update_counted: (counted) =>
    assert type(counted) == "boolean", "expected boolean for counted"

    res = db.update @@table_name!, {
      :counted
    }, {
      user_id: @user_id
      object_type: @object_type
      object_id: @object_id
      counted: not counted
    }

    if res.affected_rows and res.affected_rows > 0
      -- temporarily set to true so we can incrment/decrement
      @counted = true

      if counted
        @increment!
      else
        @decrement!

      @counted = counted
      true

  score_adjustment: =>
    @score or 1

  -- returns up/down score without contribution, and then vote's contribution
  base_and_adjustment: (object=@get_object!) =>
    assert @object_type == @@object_type_for_object(object), "invalid object type"
    assert @object_id == object.id, "invalid object id"

    up_score = object.up_votes_count or 0
    down_score = object.down_votes_count or 0

    adjustment = @score_adjustment!

    -- if we're counted, remove it
    if @counted
      if @positive
        up_score -= adjustment
      else
        down_score -= adjustment

    adjustment = -adjustment unless @positive
    up_score, down_score, adjustment

