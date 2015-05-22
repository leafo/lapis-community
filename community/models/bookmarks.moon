db = require "lapis.db"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

class Bookmarks extends Model
  @primary_key: { "user_id", "object_type", "object_id" }
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"object", polymorphic_belongs_to: {
      [1]: {"user", "Users"}
      [2]: {"topic", "Topics"}
      [3]: {"post", "Posts"}
    }}
  }

  @create: (opts={}) =>
    opts.object_type = @object_types\for_db opts.object_type
    safe_insert @, opts
