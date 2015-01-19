import Model from require "community.model"

class CategoryModerators extends Model
  @timestamp: true
  @primary_key: {"user_id", "category_id"}

  @relations: {
    {"user", belongs_to: "Users"}
    {"category", belongs_to: "Categories"}
  }

  @create: (opts={}) =>
    assert opts.user_id, "missing user_id"
    assert opts.category_id, "missing category_id"
    Model.create @, opts

