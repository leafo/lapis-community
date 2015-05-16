import Model from require "community.model"

class Moderators extends Model
  @timestamp: true
  @primary_key: {"user_id", "object_type", "object_id"}

  -- all moderatable objects must implement the following methods:
  -- \allowed_to_edit_moderators(user)

  @relations: {
    {"object", polymorphic_belongs_to: {
      [1]: {"category", "Categories"}
    }}

    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"

    assert opts.object, "missing object"

    opts.object_id = opts.object.id
    opts.object_type = @object_type_for_object opts.object
    opts.object = nil

    Model.create @, opts

  @find_for_object_user: (object, user) =>
    return nil, "invalid object" unless object
    return nil, "invalid user" unless user

    @find {
      object_type: @object_type_for_object object
      object_id: object.id
      user_id: user.id
    }
