import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, ActivityLogs from require "community.models"

factory = require "spec.factory"

describe "models.activity_logs", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, ActivityLogs

  it "should create activity log for post", ->
    post = factory.Posts!
    log = ActivityLogs\create {
      user_id: post.user_id
      object: post
      action: "create"
      data: {world: "cool"}
    }

    assert.same "create", log\action_name!

  it "should create activity log for topic", ->
    topic = factory.Topics!
    log = ActivityLogs\create {
      user_id: topic.user_id
      object: topic
      action: "delete"
    }

    assert.same "delete", log\action_name!


