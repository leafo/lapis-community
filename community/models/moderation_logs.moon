import enum from require "lapis.db.model"
import Model from require "community.model"

class ModerationLogs extends Model
  @timestamp: true
  @primary_key: {"id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"log_objects", has_many: "ModerationLogObjects"}

    {"object", polymorphic_belongs_to: {
      [1]: {"topic", "Topics"}
    }}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.action, "missing action"

    object = assert opts.object, "missing object"
    opts.object = nil
    opts.object_id = object.id
    opts.object_type = @object_type_for_object object

    log_objects = opts.log_objects
    opts.log_objects = nil

    with l = Model.create @, opts
      if log_objects
        l\set_log_objects log_objects

  set_log_objects: (objects) =>
    import ModerationLogObjects from require "community.models"
    for o in *objects
      ModerationLogObjects\create {
        object_type: ModerationLogObjects.object_type_for_object object
        object_id: object
      }

