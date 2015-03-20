
import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

class Bans extends Model
  @timestamp: true
  @primary_key: {"object_type", "object_id", "blocked_id"}

  @relations: {
    {"banned_user", belongs_to: "Users"}
  }

  @object_types: enum {
    category: 1
  }

  @object_type_name_for_object: (object) =>
    models = require "community.models"

    switch object.__class
      when models.Categories
        "category"
      else
        error "unknown object: #{object.__class.__name}"

  @model_for_object_type: (t) =>
    type_name = @object_types\to_name t
    models = require "community.models"

    switch type_name
      when "category"
        models.Categories
      else
        error "no model for type #{type_name}"

  @create: (opts) =>
    assert opts.object, "missing object"

    opts.object_id = opts.object.id
    opts.object_type = @object_types\for_db @object_type_name_for_object opts.object
    opts.object = nil

    safe_insert @, opts

  get_object: =>
    unless @object
      model = @@model_for_object_type @object_type
      @object = model\find @object_id

    @object
