import use_test_env from require "lapis.spec"
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

  "/category-topics": capture_errors_json =>
    topics, after_date, after_id = @flow\category_topics!
    json: { :topics, success: true, next_page: {after_date, after_id} }

describe "browsing flow", ->
  use_test_env!

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

  describe "category topics", ->
    category_topics = (get) ->
      status, res = mock_request BrowsingApp, "/category-topics", {
        :get
        expect: "json"
      }
      assert.same 200, status
      res


    it "should get empty category", ->
      category = factory.Categories!
      res = category_topics {
        category_id: category.id
      }

      assert.truthy res.success
      assert.same 0, #res.topics


    it "should get some topics", ->
      category = factory.Categories!
      for i=1,4
        factory.Topics category_id: category.id

      res = category_topics {
        category_id: category.id
      }

      assert.truthy res.success
      assert.same 4, #res.topics

