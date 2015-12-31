import Model from require "community.model"

class CategoryTags extends Model
  @timestamp: true

  @relations: {
    {"category", belongs_to: "Categories"}
  }


