db = require "lapis.db"
import Model from require "community.model"

class Votes extends Model
  @timestamp: true
  @primary_key: {"user_id", "object_type", "object_id"}

  @relations: {
    {"user", belongs_to: "Users"}

    {"object", polymorphic_belongs_to: {
      [1]: {"post", "Posts"}
    }}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"

    unless opts.object_id and opts.object_type
      assert opts.object, "missing vote object"
      opts.object_id = opts.object.id
      opts.object_type = @object_type_for_object opts.object
      opts.object = nil

    opts.object_type = @object_types\for_db opts.object_type
    Model.create @, opts

  @vote: (object, user, positive=true) =>
    import upsert from require "community.helpers.models"

    object_type = @object_type_for_object object
    old_vote = @find user.id, object_type, object.id

    params = {
      :object_type
      object_id: object.id
      user_id: user.id
      positive: not not positive
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

  increment: =>
    model = @@model_for_object_type @object_type
    counter_name = @post_counter_name!

    db.update model\table_name!, {
      [counter_name]: db.raw "#{db.escape_identifier counter_name} + 1"
    }, {
      id: @object_id
    }

  decrement: =>
    model = @@model_for_object_type @object_type
    counter_name = @post_counter_name!

    db.update model\table_name!, {
      [counter_name]: db.raw "#{db.escape_identifier counter_name} - 1"
    }, {
      id: @object_id
    }

  post_counter_name: =>
    if @positive
      "up_votes_count"
    else
      "down_votes_count"
