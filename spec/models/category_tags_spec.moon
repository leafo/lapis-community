factory = require "spec.factory"

describe "models.category_tags", ->
  import Users from require "spec.models"
  import Categories, Topics, Posts, CategoryTags from require "spec.community_models"

  it "creates tag for category", ->
    category = factory.Categories!
    tag = CategoryTags\create {
      slug: "hello-world"
      category_id: category.id
    }

    assert.truthy tag

    tags = category\get_tags!
    assert.same 1, #tags

