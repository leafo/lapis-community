import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts, PostVotes from require "models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

class BrowsingApp extends Application
  @before_filter =>
    @current_user = @params.current_user_id and assert Users\find @params.current_user_id
    Browsing = require "community.flows.browsing"
    @flow = Browsing @

  "/topic-posts": capture_errors_json =>
    posts = @flow\topic_posts!
    json: { :posts, success: true }


describe "browsing flow", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, PostVotes
    current_user = factory.Users!

  describe "topic posts", ->
    topic_posts = (get) ->
      status, res = mock_request BrowsingApp, "/topic-posts", {
        :get
        expect: "json"
      }
      assert.same 200, status
      res

    it "should error with no topic id", ->
      res = topic_posts!
      assert.truthy res.errors
      assert.same {"topic_id must be an integer"}, res.errors

    it "should get some posts", ->
      topic = factory.Topics!
      for i=1,3
        factory.Posts topic_id: topic.id

      res = topic_posts topic_id: topic.id
      assert.truthy res.success
      assert.same 3, #res.posts

    it "should get paginated posts with after", ->
      topic = factory.Topics!
      for i=1,3
        factory.Posts topic_id: topic.id

      res = topic_posts topic_id: topic.id, after: 1
      assert.truthy res.success
      assert.same 2, #res.posts

    it "should get paginated posts with before", ->
      topic = factory.Topics!
      for i=1,3
        factory.Posts topic_id: topic.id

      res = topic_posts topic_id: topic.id, before: 2
      assert.truthy res.success
      assert.same 1, #res.posts

