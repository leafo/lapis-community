import enum from require "lapis.db.model"
import Model from require "community.model"
import to_json from require "lapis.util"

class ActivityLogs extends Model
  @timestamp: true

  @actions: {
    topic: enum {
      create: 1
      delete: 2
    }

    post: enum {
      create: 1
      delete: 2
      edit: 3
      vote: 3
    }
  }

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}

    {"object", polymorphic_belongs_to: {
      [1]: {"topic", "Topics"}
      [2]: {"post", "Posts"}
      [3]: {"category", "Categories"}
    }}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.action, "missing action"

    object = assert opts.object, "missing object"
    opts.object = nil
    opts.object_id = assert object.id, "object does not have id"
    opts.object_type = @object_type_for_object object

    type_name = @object_types\to_name opts.object_type
    actions = @actions[type_name]
    unless actions
      error "missing action for type: #{type_name}"
    opts.action = actions\for_db opts.action

    if opts.data
      opts.data = to_json opts.data

    Model.create @, opts

  action_name: =>
    @@actions[@@object_types\to_name @object_type][@action]

