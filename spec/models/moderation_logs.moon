import use_test_env from require "lapis.spec"

factory = require "spec.factory"

describe "models.moderation_logs", ->
  use_test_env!

  import Users from require "spec.models"

  import
    Topics, ModerationLogs, Categories
    ModerationLogObjects, Posts
    from require "spec.community_models"

  describe "target action", ->
    it "gets action target", ->
      category = factory.Categories!

      log = factory.ModerationLogs {
        action: "topic.move"
        data: {
          target_category_id: category.id
        }
      }

      log\refresh! -- reload the json object
      assert.same "moved this topic to", log\get_action_text!
      target = assert log\get_action_target!
      assert.same category.id, target.id

  describe "create_backing_post", ->
    it "creates backing post", ->
      log = factory.ModerationLogs backing_post: false
      topic = log\get_object!
      category_order = topic.category_order

      log\create_backing_post!

      post = Posts\select!
      topic\refresh!

      -- doesn't count as reply, but works for pagination
      assert.same 0, topic.posts_count
      assert.same 1, topic.root_posts_count

      -- last post not updated
      assert.same nil, topic.last_post_id
      assert.same category_order, topic.category_order


    it "doesn't set last post to moderation log", ->
      log = factory.ModerationLogs backing_post: false
      topic = log\get_object!

      posts = for i=1,2
        with post = factory.Posts topic_id: topic.id
          topic\increment_from_post post

      backing_post = log\create_backing_post!
      topic\refresh!

      assert.same posts[2].id, topic.last_post_id
      topic\refresh_last_post!
      assert.same posts[2].id, topic.last_post_id

      assert.same 2, topic.posts_count
      assert.same 3, topic.root_posts_count

      Topics\recount id: topic.id

      topic\refresh!
      assert.same 2, topic.posts_count
      assert.same 3, topic.root_posts_count



