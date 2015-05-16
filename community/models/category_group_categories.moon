
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

class CategoryGroupCategories extends Model
  @timestamp: true
  @primary_key: {"category_group_id", "category_id"}


