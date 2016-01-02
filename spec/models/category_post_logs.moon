import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, CategoryPostLogs from require "community.models"

factory = require "spec.factory"

describe "models.category_tags", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, CategoryPostLogs

  it "creates single log for post", ->
    post = factory.Posts!
    CategoryPostLogs\log_post post

    assert.same {
      {
        category_id: post\get_topic!.category_id
        post_id: post.id
      }
    }, CategoryPostLogs\select!

  it "clears logs for post", ->
    post = factory.Posts!
    post2 = factory.Posts!

    CategoryPostLogs\create {
      post_id: post.id
      category_id: -1
    }

    CategoryPostLogs\create {
      post_id: post.id
      category_id: -2
    }

    CategoryPostLogs\create {
      post_id: post2.id
      category_id: -1
    }

    CategoryPostLogs\clear_post post

    assert.same {
      {
        category_id: -1
        post_id: post2.id
      }
    }, CategoryPostLogs\select!
