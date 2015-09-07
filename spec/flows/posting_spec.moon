-- TODO: move this to respetive category/topic specs
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"

import
  Categories
  Moderators
  CommunityUsers
  PostEdits
  Votes
  Posts
  TopicParticipants
  Topics
  ActivityLogs
  from require "community.models"

factory = require "spec.factory"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

TopicsFlow = require "community.flows.topics"
PostsFlow = require "community.flows.posts"

class PostingApp extends TestApp
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"

  "/new-topic": capture_errors_json =>
    TopicsFlow(@)\new_topic!

    json: {
      topic: @topic
      post: @post
      success: true
    }

  "/delete-topic": capture_errors_json =>
    res = TopicsFlow(@)\delete_topic!
    json: { success: res }

  "/new-post": capture_errors_json =>
    PostsFlow(@)\new_post!

    json: {
      post: @post
      success: true
    }

  "/edit-post": capture_errors_json =>
    PostsFlow(@)\edit_post!
    json: { success: true }

  "/delete-post": capture_errors_json =>
    res = PostsFlow(@)\delete_post!
    json: { success: res }

describe "posting flow", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, Votes, Moderators,
      PostEdits, CommunityUsers, TopicParticipants, ActivityLogs

    current_user = factory.Users!

  describe "new topic", ->
    it "should not post anything when missing all data", ->
      res = PostingApp\get current_user, "/new-topic", {}
      assert.truthy res.errors

    it "should fail with bad category", ->
      res = PostingApp\get current_user, "/new-topic", {
        current_user_id: current_user.id
        category_id: 0
        "topic[title]": "hello"
        "topic[body]": "world"
      }
      assert.same { "invalid category" }, res.errors

    it "should fail with empty body", ->
      res = PostingApp\get current_user, "/new-topic", {
        current_user_id: current_user.id
        category_id: factory.Categories!.id
        "topic[title]": "hello"
        "topic[body]": ""
      }

      assert.same { "body must be provided" }, res.errors

    it "should fail with empty html body", ->
      res = PostingApp\get current_user, "/new-topic", {
        current_user_id: current_user.id
        category_id: factory.Categories!.id
        "topic[title]": "hello"
        "topic[body]": " <ol><li>   </ol>"
      }

      assert.same { "body must be provided" }, res.errors

    it "should post a new topic", ->
      category = factory.Categories!

      res = PostingApp\get current_user, "/new-topic", {
        current_user_id: current_user.id
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      assert.truthy res.success

      topic = unpack Topics\select!
      post = unpack Posts\select!

      assert.same category.id, topic.category_id
      assert.same current_user.id, topic.user_id
      assert.same "Hello world", topic.title
      assert.same 1, topic.category_order

      assert.same current_user.id, post.user_id
      assert.same topic.id, post.topic_id
      assert.same "This is the body", post.body

      category\refresh!
      assert.same 1, category.topics_count

      cu = CommunityUsers\for_user(current_user)
      assert.same 1, cu.topics_count
      assert.same 0, cu.posts_count

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 1, #tps

      category\refresh!
      assert.same topic.id, category.last_topic_id

      assert.same post.id, topic.last_post_id

      assert.same 1, topic.root_posts_count
      assert.same 1, topic.posts_count

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same topic.id, log.object_id
      assert.same ActivityLogs.object_types.topic, log.object_type
      assert.same "create", log\action_name!


  describe "new post", ->
    local topic

    before_each ->
      -- note this isn't a full topic, it has no first post
      topic = factory.Topics!

    it "should post a new post", ->
      res = PostingApp\get current_user, "/new-post", {
        topic_id: topic.id
        "post[body]": "This is post body"
      }

      topic\refresh!
      post = unpack Posts\select!

      assert.same current_user.id, post.user_id
      assert.same topic.id, post.topic_id
      assert.same "This is post body", post.body

      assert.same topic.posts_count, 1
      assert.same topic.root_posts_count, 1

      cu = CommunityUsers\for_user(current_user)
      assert.same 0, cu.topics_count
      assert.same 1, cu.posts_count

      -- 1 less because factory didn't seed topic participants
      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 1, #tps

      -- although this is the first post, there is no circumstance where the
      -- first post would normally get posted thoruhg /new-post, so we assume
      -- last_post_id is set
      assert.same post.id, topic.last_post_id

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same post.id, log.object_id
      assert.same ActivityLogs.object_types.post, log.object_type
      assert.same "create", log\action_name!

    it "should post two posts", ->
      for i=1,2
        PostingApp\get current_user, "/new-post", {
          topic_id: topic.id
          "post[body]": "This is post body"
        }

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 1, #tps
      assert.same 2, tps[1].posts_count

    it "should post a threaded post", ->
      post = factory.Posts topic_id: topic.id

      res = PostingApp\get current_user, "/new-post", {
        topic_id: topic.id
        parent_post_id: post.id
        "post[body]": "This is a sub message"
      }

      assert.truthy res.success
      child_post = res.post

      posts = Posts\select!
      assert.same 2, #posts

      child_post = Posts\find child_post.id
      assert.same post.id, child_post.parent_post_id

  describe "edit topic", ->
    local topic

    before_each ->
      topic = factory.Topics user_id: current_user.id

    it "should delete topic", ->
      res = PostingApp\get current_user, "/delete-topic", {
        topic_id: topic.id
      }

      assert.truthy res.success
      topic\refresh!
      assert.truthy topic.deleted
      assert.truthy topic.deleted_at

      assert.same -1, CommunityUsers\for_user(current_user).topics_count

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same topic.id, log.object_id
      assert.same ActivityLogs.object_types.topic, log.object_type
      assert.same "delete", log\action_name!

    it "should not allow unrelated user to delete topic", ->
      other_user = factory.Users!

      res = PostingApp\get other_user, "/delete-topic", {
        topic_id: topic.id
      }

      assert.same {errors: {"not allowed to edit"}}, res

  describe "edit post", ->
    it "should edit post", ->
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the new body"
      }

      assert.truthy res.success
      post\refresh!
      assert.same "the new body", post.body

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same post.id, log.object_id
      assert.same ActivityLogs.object_types.post, log.object_type
      assert.same "edit", log\action_name!

    it "should edit post and title", ->
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      old_body = post.body

      assert.truthy res.success
      post\refresh!
      assert.same "the new body", post.body
      assert.same "the new title", post\get_topic!.title
      assert.same "the-new-title", post\get_topic!.slug

      edit = unpack PostEdits\select!
      assert edit, "missing edit"
      assert.same current_user.id, edit.user_id
      assert.same post.id, edit.post_id
      assert.same old_body, edit.body_before

      assert.same 1, post.edits_count
      assert.truthy post.last_edited_at

    it "should edit post with reason", ->
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the newer body"
        "post[reason]": "changed something"
      }

      old_body = post.body
      assert.truthy res.success
      post\refresh!
      assert.same "the newer body", post.body

      edit = unpack PostEdits\select!
      assert edit, "missing edit"
      assert.same current_user.id, edit.user_id
      assert.same post.id, edit.post_id
      assert.same old_body, edit.body_before
      assert.same "changed something", edit.reason

      assert.same 1, post.edits_count
      assert.truthy post.last_edited_at

    it "should not create post edit when editing with unchanged body", ->
      post = factory.Posts user_id: current_user.id
      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": post.body
        "post[reason]": "this will be ingored"
      }

      edit = unpack PostEdits\select!
      assert.falsy edit

      post\refresh!
      assert.same 0, post.edits_count
      assert.falsy post.last_edited_at

    it "should not edit invalid post", ->
      res = PostingApp\get current_user, "/edit-post", {
        post_id: 0
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.errors

    it "should not let stranger edit post", ->
      post = factory.Posts!

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.errors

    it "should let moderator edit post", ->
      post = factory.Posts!
      topic = post\get_topic!

      factory.Moderators {
        user_id: current_user.id
        object: topic\get_category!
      }

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.success

      post\refresh!
      assert.same "the new body", post.body
      assert.same "the new title", post\get_topic!.title

    it "should edit nth post in topic", ->
      topic = factory.Topics!
      post1 = factory.Posts topic_id: topic.id
      post2 = factory.Posts topic_id: topic.id, user_id: current_user.id

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post2.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.success

      post1\refresh!
      post2\refresh!
      before_title = topic.title
      topic\refresh!

      assert.same "the new body", post2.body
      assert.same before_title, topic.title

    it "should delete post", ->
      -- creates second post
      post = factory.Posts {
        user_id: current_user.id
        topic_id: factory.Posts(user_id: current_user.id).topic_id
      }

      topic = post\get_topic!
      topic\increment_participant current_user

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      assert.truthy res.success
      post\refresh!
      assert.truthy post.deleted
      assert.truthy post.deleted_at

      assert.same -1, CommunityUsers\for_user(current_user).posts_count

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 0, #tps

      topic\refresh!
      assert.same nil, topic.last_post_id

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same post.id, log.object_id
      assert.same ActivityLogs.object_types.post, log.object_type
      assert.same "delete", log\action_name!

    it "should delete primary post, deleting topic", ->
      post = factory.Posts {
        user_id: current_user.id
      }

      topic = post\get_topic!

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      topic\refresh!
      assert.truthy topic.deleted
      assert.truthy topic.deleted_at

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same topic.id, log.object_id
      assert.same ActivityLogs.object_types.topic, log.object_type
      assert.same "delete", log\action_name!


    it "should delete primary post of permanent topic, keep topic", ->
      topic = factory.Topics {
        user_id: current_user.id
        permanent: true
      }

      post = factory.Posts {
        topic_id: topic.id
        user_id: current_user.id
      }

      Topics\recount id: topic.id

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      topic\refresh!
      assert.falsy topic.deleted
      assert.same 1, topic.posts_count
    
    it "should not delete unrelated post", ->
      other_user = factory.Users!
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get other_user, "/delete-post", {
        post_id: post.id
      }

      assert.same {errors: {"not allowed to edit"}}, res

