
import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

class Bans extends Model
  @timestamp: true
  @primary_key: {"object_type", "object_id", "banned_user_id"}

  @relations: {
    {"banned_user", belongs_to: "Users"}
    {"banning_user", belongs_to: "Users"}

    {"object", polymorphic_belongs_to: {
      [1]: {"category", "Categories"}
      [2]: {"topic", "Topics"}
    }}
  }

  @find_for_object: (object, user) =>
    return nil unless user
    Bans\find {
      object_type: @object_type_for_object object
      object_id: object.id
      banned_user_id: user.id
    }

  @create: (opts) =>
    assert opts.object, "missing object"

    opts.object_id = opts.object.id
    opts.object_type = @object_type_for_object opts.object
    opts.object = nil

    safe_insert @, opts

