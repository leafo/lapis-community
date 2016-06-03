import use_test_env from require "lapis.spec"
import request from require "lapis.spec.server"

factory = require "spec.factory"

import capture_errors_json from require "lapis.application"
import TestApp from require "spec.helpers"

BookmarksFlow = require "community.flows.bookmarks"

import filter_bans from require "spec.helpers"

class BookmarksApp extends TestApp
  @require_user!

  "/show-topics": capture_errors_json =>
    BookmarksFlow(@)\show_topic_bookmarks!
    filter_bans unpack @topics

    json: {
      success: true
      topics: @topics
    }

  "/save": capture_errors_json =>
    BookmarksFlow(@)\save_bookmark!
    json: { success: true }

  "/remove": capture_errors_json =>
    BookmarksFlow(@)\remove_bookmark!
    json: { success: true }

describe "flows.bookmarks", ->
  use_test_env!

  import Users from require "spec.models"
  import Bookmarks, Topics from require "spec.community_models"

  local current_user

  before_each ->
    current_user = factory.Users!

  describe "show #ddd", ->
    it "fetches empty topic list", ->
      res = BookmarksApp\get current_user, "/show-topics"
      assert.same {
        success: true
        topics: {}
      }, res

    it "fetches topic with bookmark", ->
      other_topic = factory.Topics!
      Bookmarks\save other_topic, factory.Users!

      topics = for i=1,2
        with topic = factory.Topics!
          Bookmarks\save topic, current_user

      res = BookmarksApp\get current_user, "/show-topics"
      assert.same {t.id, true for t in *topics},
         {t.id, true for t in *res.topics}

  it "should save a bookmark", ->
    topic = factory.Topics!
    BookmarksApp\get current_user, "/save", {
      object_type: "topic"
      object_id: topic.id
    }

    assert.same 1, Bookmarks\count!
    bookmark = unpack Bookmarks\select!
    assert.same Bookmarks.object_types.topic, bookmark.object_type
    assert.same topic.id, bookmark.object_id
    assert.same current_user.id, bookmark.user_id

  it "should not error if bookmark exists", ->
    topic = factory.Topics!
    for i=1,2
      BookmarksApp\get current_user, "/save", {
        object_type: "topic"
        object_id: topic.id
      }

    assert.same 1, Bookmarks\count!

  it "should remove bookmark", ->
    bm = factory.Bookmarks user_id: current_user.id

    BookmarksApp\get current_user, "/remove", {
      object_type: "topic"
      object_id: bm.object_id
    }

    assert.same 0, Bookmarks\count!

  it "should not fail when removing non-existant bookmark", ->
    BookmarksApp\get current_user, "/remove", {
      object_type: "topic"
      object_id: 1234
    }

    assert.same 0, Bookmarks\count!

