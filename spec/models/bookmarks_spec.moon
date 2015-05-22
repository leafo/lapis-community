import use_test_env from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Bookmarks, Topics from require "community.models"

factory = require "spec.factory"

describe "models.bookmarks", ->
  use_test_env!

  before_each ->
    truncate_tables Topics, Users, Bookmarks

  it "create a bookmark", ->
    user = factory.Users!
    topic = factory.Topics!

    assert Bookmarks\create {
      user_id: user.id
      object_type: "topic"
      object_id: topic.id
    }

