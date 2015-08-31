import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Moderators, Posts, Topics from require "community.models"

factory = require "spec.factory"

describe "moderators", ->
  use_test_env!

  local current_user, mod

  before_each ->
    truncate_tables Users, Categories, Moderators, Posts, Topics
    current_user = factory.Users!
    mod = factory.Moderators user_id: current_user.id

  it "gets all moderators for category", ->
    category = mod\get_object!
    assert.same {current_user.id}, [m.user_id for m in *category\get_moderators!]

  it "gets moderator for category", ->
    category = mod\get_object!
    mod = category\find_moderator current_user
    assert.truthy mod

    assert.same category.id, mod.object_id
    assert.same Moderators.object_types.category, mod.object_type
    assert.same current_user.id, mod.user_id

  it "lets moderator edit post in category", ->
    topic = factory.Topics category_id: mod.object_id
    post = factory.Posts topic_id: topic.id

    assert.truthy post\allowed_to_edit current_user

  it "doesn't let moderator edit post other category", ->
    post = factory.Posts!
    assert.falsy post\allowed_to_edit current_user

