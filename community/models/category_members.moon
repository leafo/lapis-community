
db = require "lapis.db"
import Model from require "community.model"

class CategoryMembers extends Model
  @timestamp: true
  @primary_key: {"user_id", "category_id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.category_id, "missing category id"

    import safe_insert from require "community.helpers.models"
    safe_insert @, opts

