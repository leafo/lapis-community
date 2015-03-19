import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import
  Categories
  CategoryModerators
  PostEdits
  PostVotes
  Posts
  Topics
  Users
  from require "models"

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

  "/new-post": capture_errors_json =>
    @flow\new_post!

    json: {
      post: @flow.post
      success: true
    }

  "/edit-post": capture_errors_json =>
    @flow\edit_post!
    json: { success: true }


  "/vote-post": capture_errors_json =>
    @flow\vote_post!
    json: { success: true }


describe "posting flow", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Topics, Posts, PostVotes,
      CategoryModerators, PostEdits

    current_user = factory.Users!

  describe "new topic", ->
    new_topic = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request PostingApp, "/new-topic", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

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


  describe "new post", ->
    new_post = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request PostingApp, "/new-post", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res


    it "should post a new post", ->
      topic = factory.Topics!

      res = new_post {
        current_user_id: current_user.id
        topic_id: topic.id
        "post[body]": "This is post body"
      }

      topic\refresh!
      post = unpack Posts\select!

      assert.same current_user.id, post.user_id
      assert.same topic.id, post.topic_id
      assert.same "This is post body", post.body

      assert.same topic.posts_count, 1

  describe "vote post #votes", ->
    vote_post = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request PostingApp, "/vote-post", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should vote on a post", ->
      post = factory.Posts!
      res = vote_post {
        post_id: post.id
        direction: "up"
      }

      assert.same { success: true }, res
      vote = assert unpack PostVotes\select!
      assert.same post.id, vote.post_id
      assert.same current_user.id, vote.user_id
      assert.same true, vote.positive

      post\refresh!

      assert.same 1, post.up_votes_count
      assert.same 0, post.down_votes_count


    it "should update a vote with no changes", ->
      post = factory.Posts!
      res = vote_post {
        post_id: post.id
        direction: "up"
      }

      assert.same { success: true }, res

      res = vote_post {
        post_id: post.id
        direction: "up"
      }

      assert.same { success: true }, res

      vote = assert unpack PostVotes\select!
      assert.same post.id, vote.post_id
      assert.same current_user.id, vote.user_id
      assert.same true, vote.positive

      post\refresh!

      assert.same 1, post.up_votes_count
      assert.same 0, post.down_votes_count


    it "should update a vote", ->
      vote = factory.PostVotes user_id: current_user.id

      res = vote_post {
        post_id: vote.post_id
        direction: "down"
      }

      votes = PostVotes\select!
      assert.same 1, #votes
      new_vote = unpack votes

      assert.same false, new_vote.positive

      post = Posts\find new_vote.post_id
      assert.same 0, post.up_votes_count
      assert.same , post.down_votes_count

  describe "edit post", ->
    edit_post = (get={}) ->
      get.current_user_id or= current_user.id
      status, res = mock_request PostingApp, "/edit-post", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should edit post", ->
      post = factory.Posts user_id: current_user.id

      res = edit_post {
        post_id: post.id
        "post[body]": "the new body"
      }

      assert.truthy res.success
      post\refresh!
      assert.same "the new body", post.body

    it "should edit post and title", ->
      post = factory.Posts user_id: current_user.id

      res = edit_post {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      old_body = post.body

      assert.truthy res.success
      post\refresh!
      assert.same "the new body", post.body
      assert.same "the new title", post\get_topic!.title

      edit = unpack PostEdits\select!
      assert edit, "missing edit"
      assert.same current_user.id, edit.user_id
      assert.same post.id, edit.post_id
      assert.same old_body, edit.body_before


    it "should edit post with reason", ->
      post = factory.Posts user_id: current_user.id

      res = edit_post {
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

    it "should not edit invalid post", ->
      res = edit_post {
        post_id: 0
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.errors

    it "should not let stranger edit post", ->
      post = factory.Posts!

      res = edit_post {
        post_id: post.id
        "post[body]": "the new body"
        "post[title]": "the new title"
      }

      assert.truthy res.errors

    it "should let moderator edit post", ->
      post = factory.Posts!
      topic = post\get_topic!

      factory.CategoryModerators {
        user_id: current_user.id
        category_id: topic.category_id
      }

      res = edit_post {
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

      res = edit_post {
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
