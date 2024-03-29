factory = require "spec.factory"

describe "models.bookmarks", ->
  import Users from require "spec.models"
  import Topics, Bookmarks from require "spec.community_models"

  it "create a bookmark", ->
    user = factory.Users!
    topic = factory.Topics!

    assert Bookmarks\create {
      user_id: user.id
      object_type: "topic"
      object_id: topic.id
    }

