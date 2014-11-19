
db = require "lapis.db"
import Model from require "lapis.db.model"

class CategoryMembers extends Model
  @timestamp: true
  @primary_key: {"user_id", "category_id"}

  @new: (opts={}) =>
    assert opts.user_id, "missing user id"
    assert opts.category_id, "missing category id"

