import Model from require "lapis.db.model"

class CategoryModerators extends Model
  @timestamp: true
  @primary_key: {"user_id", "category_id"}

  @relations: {
    {"user", has_one: "Users"}
    {"category", has_one: "Categories"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.category_id, "missing category_id"
    Model.create @, opts

