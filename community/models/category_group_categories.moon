
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

import safe_insert from require "community.helpers.models"

class CategoryGroupCategories extends Model
  @timestamp: true
  @primary_key: {"category_group_id", "category_id"}

  @relations: {
    {"category_group", belongs_to: "CategoryGroups"}
    {"category", belongs_to: "Categories"}
  }

  @create: safe_insert


