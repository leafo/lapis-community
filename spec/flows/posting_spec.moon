-- TODO: move this to respetive category/topic specs
import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

db = require "lapis.db"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

PostsFlow = require "community.flows.posts"

import Users from require "models"

import types from require "tableshape"

class PostingApp extends TestApp
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"

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

  import Users from require "spec.models"

  import
    Categories
    CategoryTags
    Moderators
    CommunityUsers
    PostEdits
    Votes
    Posts
    TopicParticipants
    Topics
    ActivityLogs
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  new_topic = (post) ->
    in_request { :post }, =>
      @current_user = current_user
      @flow("topics")\new_topic!

  delete_topic = (post, user=current_user) ->
    in_request { :post }, =>
      @current_user = user
      @flow("topics")\delete_topic!

  describe "new topic", ->
    it "errors with blank post request", ->
      assert.has_error ->
        new_topic { }

    it "errors with bad category", ->
      assert.has_error(
        ->
          new_topic {
            category_id: 0
            "topic[title]": "hello"
            "topic[body]": "world"
          }

        {
          message: {"invalid category"}
        }
      )

    it "errors with empty body", ->
      assert.has_error(
        ->
          new_topic {
            category_id: factory.Categories!.id
            "topic[title]": "hello"
            "topic[body]": ""
          }
        {
          message: {"body must be provided"}
        }
      )

    it "errors with empty html body", ->
      assert.has_error(
        ->
          new_topic {
            category_id: factory.Categories!.id
          "topic[title]": "hello"
          "topic[body]": " <ol><li>   </ol>"
          }
        {
          message: {"body must be provided"}
        }
      )

    it "should post a new topic", ->
      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      topic = unpack Topics\select!
      post = unpack Posts\select!

      assert (types.shape {
        category_id: category.id
        user_id: current_user.id
        title: "Hello world"
        category_order: 1

        protected: false
        locked: false
        permanent: false
        deleted: false
        sticky: false
        posts_count: 1
        root_posts_count: 1
        status: Topics.statuses.default
        last_post_id: post.id
      }, open: true) topic


      assert (types.shape {
        body_format: Posts.body_formats.html
        user_id: current_user.id
        topic_id: topic.id
        body: "This is the body"
        depth: 1
        status: Posts.statuses.default
        deleted: false
        post_number: 1
      }, open: true) post

      category\refresh!

      assert (types.shape {
        last_topic_id: topic.id
        topics_count: 1
      }, open: true) category

      cu = CommunityUsers\for_user(current_user)

      assert (types.shape {
        topics_count: 1
        posts_count: 0
      }, open: true) cu

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert (types.shape {
        types.shape {
          user_id: current_user.id
          posts_count: 1
        }, open: true
      }) tps


      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: topic.id
          object_type: ActivityLogs.object_types.topic
          action: ActivityLogs.actions.topic.create
          publishable: false
        }, open: true
      }) logs


    it "creates new topic with body format", ->
      category = factory.Categories!

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
        "topic[body_format]": "markdown"
      }

      post = unpack Posts\select!

      assert types.partial({
        body_format: Posts.body_formats.markdown
      }) post

    it "creates new topic with tags", ->
      category = factory.Categories!
      factory.CategoryTags slug: "hello", category_id: category.id

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
        "topic[tags]": "hello"
      }

      topic = unpack Topics\select!
      assert.same {"hello"}, [t.slug for t in *topic\get_tags!]

    it "posts new topic with score based category order", ->
      category = factory.Categories  category_order_type: "topic_score"

      new_topic {
        category_id: category.id
        "topic[title]": "Hello world"
        "topic[body]": "This is the body"
      }

      topic = unpack Topics\select!
      assert.not.same 1, topic.category_order

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

      assert (types.shape {
        user_id: current_user.id
        topic_id: topic.id
        body: "This is post body"
        body_format: Posts.body_formats.html

        depth: 1
        status: Posts.statuses.default
        deleted: false
        post_number: 1
      }, open: true) post

      assert (types.shape {
        posts_count: 1
        root_posts_count: 1
        status: Topics.statuses.default
        category_order: 2

        -- although this is the first post, there is no circumstance where the
        -- first post would normally get posted thoruhg /new-post, so we assume
        -- last_post_id is set
        last_post_id: post.id

      }, open: true) topic

      cu = CommunityUsers\for_user(current_user)

      assert (types.shape {
        topics_count: 0
        posts_count: 1
      }, open: true) cu

      -- 1 less because factory didn't seed topic participants
      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert (types.shape {
        types.shape {
          user_id: current_user.id
          posts_count: 1
        }, open: true
      }) tps


      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: post.id
          object_type: ActivityLogs.object_types.posts
          action: ActivityLogs.actions.post.create
          publishable: false
        }, open: true
      }) logs

    it "should post two posts", ->
      for i=1,2
        PostingApp\get current_user, "/new-post", {
          topic_id: topic.id
          "post[body]": "This is post body"
        }

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 1, #tps
      assert.same 2, tps[1].posts_count

    it "creates new post with body format", ->
      res = PostingApp\get current_user, "/new-post", {
        topic_id: topic.id
        "post[body]": "This is post body"
        "post[body_format]": "markdown"
      }

      topic\refresh!
      post = unpack Posts\select!

      assert (types.shape {
        body_format: Posts.body_formats.markdown
      })

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
      delete_topic { topic_id: topic.id }

      topic\refresh!
      assert.truthy topic.deleted
      assert.truthy topic.deleted_at

      assert.same -1, CommunityUsers\for_user(current_user).topics_count

      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: topic.id
          object_type: ActivityLogs.object_types.topic
          action: ActivityLogs.actions.topic.delete
          publishable: false
        }, open: true
      }) logs


    it "should not allow unrelated user to delete topic", ->
      other_user = factory.Users!

      assert.has_error(
        -> delete_topic { topic_id: topic.id }, other_user
        { message: {"not allowed to edit"} }
      )

  describe "edit post", ->
    it "should edit post", ->
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "the new body"
      }

      assert.truthy res.success
      post\refresh!

      assert (types.shape {
        body: "the new body"
      }, open: true) post

      assert.same 1, ActivityLogs\count!
      logs = ActivityLogs\select!

      assert (types.shape {
        types.shape {
          user_id: current_user.id
          object_id: post.id
          object_type: ActivityLogs.object_types.post
          action: ActivityLogs.actions.post.edit
          publishable: false
        }, open: true
      }) logs



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

    it "should edit tags", ->
      post = factory.Posts user_id: current_user.id
      topic = post\get_topic!
      category = topic\get_category!

      factory.CategoryTags category_id: category.id, slug: "hello"
      factory.CategoryTags category_id: category.id, slug: "zone"

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "good stuff"
        "post[tags]": "hello,zone,woop"
      }

      topic\refresh!
      assert.same {"hello", "zone"}, topic.tags
      assert.same 2, #topic\get_tags!

    it "should clear post tags", ->
      post = factory.Posts user_id: current_user.id
      topic = post\get_topic!
      category = topic\get_category!
      tag = factory.CategoryTags category_id: category.id

      topic\update tags: db.array { tag.slug }

      res = PostingApp\get current_user, "/edit-post", {
        post_id: post.id
        "post[body]": "good stuff"
        "post[tags]": ""
      }

      topic\refresh!
      assert.nil topic.tags

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

    it "softs delete post with replies", ->
      topic = factory.Topics user_id: current_user.id

      -- first post
      factory.Posts(user_id: current_user.id, topic_id: topic.id)

      -- creates second post
      post = factory.Posts {
        user_id: current_user.id
        topic_id: topic.id
      }

      factory.Posts topic_id: post.topic_id, parent_post_id: post.id

      topic\increment_participant current_user

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      assert.truthy res.success
      post\refresh!
      assert.truthy post.deleted
      assert.truthy post.deleted_at

      -- -1 because we never incremented
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


    it "should hard delete post", ->
      topic = factory.Topics user_id: current_user.id

      -- first post
      factory.Posts(user_id: current_user.id, topic_id: topic.id)

      -- creates second post
      post = factory.Posts {
        user_id: current_user.id
        topic_id: topic.id
      }

      topic\increment_participant current_user

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      assert.truthy res.success
      assert.same nil, (Posts\find post.id)

      assert.same -1, CommunityUsers\for_user(current_user).posts_count

      tps = TopicParticipants\select "where topic_id = ?", topic.id
      assert.same 0, #tps

      topic\refresh!
      assert.same nil, topic.last_post_id

      assert.same 0, ActivityLogs\count!

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
      assert.same 0, topic.posts_count
    
    it "should not delete unrelated post", ->
      other_user = factory.Users!
      post = factory.Posts user_id: current_user.id

      res = PostingApp\get other_user, "/delete-post", {
        post_id: post.id
      }

      assert.same {errors: {"not allowed to edit"}}, res

    it "should delete last post, refreshing topic on category and topic", ->
      category = factory.Categories!
      topic = factory.Topics(:category)

      p1 = factory.Posts(:topic)
      p2 = factory.Posts(:topic)

      other_topic = factory.Topics(:category)
      other_post = factory.Posts topic: other_topic

      post = factory.Posts(:topic, user_id: current_user.id)

      category\refresh!
      topic\refresh!

      assert.same topic.id, category.last_topic_id
      assert.same post.id, topic.last_post_id

      res = PostingApp\get current_user, "/delete-post", {
        post_id: post.id
      }

      category\refresh!
      topic\refresh!

      assert.same p2.id, topic.last_post_id
      assert.same topic.id, category.last_topic_id

    it "hard deletes post that has been soft deleted", ->
      moderator = factory.Users!

      category = factory.Categories user_id: moderator.id
      topic = factory.Topics(:category, permanent: true)
      post = factory.Posts :topic, deleted: true

      res = PostingApp\get moderator, "/delete-post", {
        post_id: post.id
      }

      assert.same {}, Posts\select!

