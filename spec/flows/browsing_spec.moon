import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Categories, Topics, Posts, PostVotes from require "models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

import TestApp from require "spec.helpers"

class BrowsingApp extends TestApp
  @before_filter =>
    @current_user = @params.current_user_id and assert Users\find @params.current_user_id
    Browsing = require "community.flows.browsing"
    @flow = Browsing @

  "/topic-posts": capture_errors_json =>
    @flow\topic_posts!
    json: { posts: @posts, success: true }

  "/category-topics": capture_errors_json =>
    @flow\category_topics!
    json: {
      success: true
      topics: @topics
      next_page: {
        after_date: @after_date
        after_id: @after_id

        before_date: @before_date
        before_id: @before_id
      }
    }

describe "browsing flow", ->
  use_test_env!


  before_each ->
    truncate_tables Users, Categories, Topics, Posts, PostVotes

  for logged_in in *{true, false}
    local current_user

    describe logged_in and "logged in" or "logged out", ->
      before_each ->
        current_user = factory.Users! if logged_in

      describe "topic posts", ->
        it "should error with no topic id", ->
          res = BrowsingApp\get current_user, "/topic-posts"
          assert.truthy res.errors
          assert.same {"topic_id must be an integer"}, res.errors

        it "should get some posts", ->
          topic = factory.Topics!
          for i=1,3
            factory.Posts topic_id: topic.id

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id
          assert.truthy res.success
          assert.same 3, #res.posts

        it "should get paginated posts with after", ->
          topic = factory.Topics!
          for i=1,3
            factory.Posts topic_id: topic.id

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id, after: 1
          assert.truthy res.success
          assert.same 2, #res.posts

        it "should get paginated posts with before", ->
          topic = factory.Topics!
          for i=1,3
            factory.Posts topic_id: topic.id

          res = BrowsingApp\get current_user, "/topic-posts", topic_id: topic.id, before: 2
          assert.truthy res.success
          assert.same 1, #res.posts

      describe "category topics", ->
        it "should get empty category", ->
          category = factory.Categories!
          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id
          assert.truthy res.success
          assert.same 0, #res.topics

        it "should get some topics", ->
          category = factory.Categories!
          for i=1,4
            factory.Topics category_id: category.id

          res = BrowsingApp\get current_user, "/category-topics", category_id: category.id

          assert.truthy res.success
          assert.same 4, #res.topics

