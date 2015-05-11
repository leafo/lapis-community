import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, CategoryModerators, Posts, Topics from require "community.models"

factory = require "spec.factory"

describe "posts", ->
  use_test_env!

  local current_user, mod

  before_each ->
    truncate_tables Users, Categories, CategoryModerators, Posts, Topics
    current_user = factory.Users!
    mod = factory.CategoryModerators user_id: current_user.id

  it "should get moderator for category", ->
    category = mod\get_category!
    mod = category\find_moderator current_user
    assert.truthy mod

    assert.same category.id, mod.category_id
    assert.same current_user.id, mod.user_id

  it "should let moderator edit post in category", ->
    topic = factory.Topics category_id: mod.category_id
    post = factory.Posts topic_id: topic.id

    assert.truthy post\allowed_to_edit current_user

  it "should not let moderator edit post other category", ->
    post = factory.Posts!
    assert.falsy post\allowed_to_edit current_user

