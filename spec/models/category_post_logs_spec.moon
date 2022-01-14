factory = require "spec.factory"

describe "models.category_tags", ->
  import Users from require "spec.models"
  import Categories, Topics, Posts, CategoryPostLogs from require "spec.community_models"

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
    CategoryPostLogs\log_post post -- logging again is noop

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
    CategoryPostLogs\log_post post -- logging again is noop

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


  it "create logs for topic with multiple categories", ->
    top_directory = factory.Categories directory: true
    bottom_directory = factory.Categories directory: true, parent_category_id: top_directory.id
    category = factory.Categories parent_category_id: bottom_directory.id

    topic = factory.Topics category_id: category.id
    posts = for i=1,2
      factory.Posts topic_id: topic.id

    CategoryPostLogs\log_topic_posts topic
    CategoryPostLogs\log_topic_posts topic

    assert.same {
      {
        category_id: top_directory.id
        post_id: posts[1].id
      }
      {
        category_id: bottom_directory.id
        post_id: posts[1].id
      }
      {
        category_id: top_directory.id
        post_id: posts[2].id
      }
      {
        category_id: bottom_directory.id
        post_id: posts[2].id
      }
    }, CategoryPostLogs\select "order by post_id, category_id"

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

  it "clears posts for topic", ->
    topic = factory.Topics!

    for i=1,3
      post = factory.Posts topic_id: topic.id
      CategoryPostLogs\create {
        post_id: post.id
        category_id: -1
      }

    other_post = factory.Posts!
    CategoryPostLogs\create {
      post_id: other_post.id
      category_id: -1
    }

    CategoryPostLogs\clear_posts_for_topic topic

    assert.same {
      {
        category_id: -1
        post_id: other_post.id
      }
    }, CategoryPostLogs\select!
