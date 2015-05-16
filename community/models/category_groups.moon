
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

class CategoryGroups extends Model
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"category_group_categories", has_many: "CategoryGroupCategories"}
  }

  set_categories: (categories) =>
    import Categories from require "community.models"

    to_add = {}

    ids = @get_category_group_categories_paginated(fields: "category_id")\get_all!
    ids = {cgc.category_id, 1 for cgc in *ids}

    for c in *categories
      if ids[c.id]
        ids[c.id] -= 1
      else
        table.insert to_add, c

    to_remove = [id for id, count in pairs ids when count == 1]
    to_remove = Categories\find_all to_remove

    for category in *to_remove
      @remove_category category

    for category in *to_add
      @add_category category

    true

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



