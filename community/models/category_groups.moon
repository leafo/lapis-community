
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

class CategoryGroups extends Model
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"category_group_categories", has_many: "CategoryGroupCategories"}
  }

  add_category: (category) =>
    import CategoryGroupCategories from require "community.models"

    group_category = CategoryGroupCategories\create {
      category_id: category.id
      category_group_id: @id
    }

    if group_category
      @update categories_count: db.raw "categories_count + 1"
      true

  remove_category: (category) =>
    import CategoryGroupCategories from require "community.models"

    group_category = CategoryGroupCategories\find {
      category_id: category.id
      category_group_id: @id
    }

    if group_category and group_category\delete!
      @update categories_count: db.raw "categories_count - 1"
      true



