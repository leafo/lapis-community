import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts from require "models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

class PostingApp extends Application
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    PostingFlow = require "community.flows.posting"
    @flow = PostingFlow @

  "/new-topic": capture_errors_json =>
    @flow\new_topic!

    json: {
      topic: @flow.topic
      post: @flow.post
      success: true
    }

describe "posting flow", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Topics, Posts
    current_user = factory.Users!

  new_topic = (get={}) ->
    get.current_user_id or= current_user.id
    status, res = mock_request PostingApp, "/new-topic", {
      :get
      expect: "json"
    }

    assert.same 200, status
    res

  describe "new topic", ->
    it "should not post anything when missing all data", ->
      res = new_topic!
      assert.truthy res.errors

    it "should fail with bad category", ->
      res = new_topic {
        current_user_id: current_user.id
        category_id: 0
        "topic[title]": "hello"
        "topic[body]": "world"
      }
      assert.same { "invalid category" }, res.errors

    it "should fail with empty body", ->
      res = new_topic {
        current_user_id: current_user.id
        category_id: factory.Categories!.id
        "topic[title]": "hello"
        "topic[body]": ""
      }

      assert.same { "body must be provided" }, res.errors

    it "should post a new topic", ->
      category = factory.Categories!

      res = new_topic {
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

      assert.same current_user.id, post.user_id
      assert.same topic.id, post.topic_id
      assert.same "This is the body", post.body

      category\refresh!
      assert.same 1, category.topics_count


