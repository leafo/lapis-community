import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, Topics, Posts, CategoryPostLogs from require "community.models"

factory = require "spec.factory"

describe "models.category_tags", ->
  use_test_env!

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, CategoryPostLogs

  it "doesn't create post log for post with no loggable ancestors", ->
    post = factory.Posts!
    CategoryPostLogs\log_post post

    assert.same {}, CategoryPostLogs\select!

  it "creates single log for post", ->
    directory = factory.Categories directory: true
    category = factory.Categories parent_category_id: directory.id
    topic = factory.Topics category_id: category.id
    post = factory.Posts topic_id: topic.id

    CategoryPostLogs\log_post post

    assert.same {
      {
        category_id: directory.id
        post_id: post.id
      }
    }, CategoryPostLogs\select!

  it "creates multiple log for each directory", ->
    top_directory = factory.Categories directory: true
    bottom_directory = factory.Categories directory: true, parent_category_id: top_directory.id
    category = factory.Categories parent_category_id: bottom_directory.id

    topic = factory.Topics category_id: category.id
    post = factory.Posts topic_id: topic.id

    CategoryPostLogs\log_post post

    assert.same {
      {
        category_id: top_directory.id
        post_id: post.id
      }
      {
        category_id: bottom_directory.id
        post_id: post.id
      }
    }, CategoryPostLogs\select "order by category_id asc"


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
