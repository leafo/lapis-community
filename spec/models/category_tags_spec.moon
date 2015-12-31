import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, CategoryTags from require "community.models"

factory = require "spec.factory"

describe "models.category_tags", ->
  use_test_env!

  before_each ->
    truncate_tables Categories, Topics, Posts, CategoryTags

  it "creates tag for category", ->
    category = factory.Categories!
    tag = CategoryTags\create {
      slug: "hello-world"
      category_id: category.id
    }

    assert.truthy tag

    tags = category\get_tags!
    assert.same 1, #tags

