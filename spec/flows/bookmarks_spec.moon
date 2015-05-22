import use_test_env from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Bookmarks, Topics from require "community.models"

factory = require "spec.factory"

import capture_errors_json from require "lapis.application"
import TestApp from require "spec.helpers"

BookmarksFlow = require "community.flows.bookmarks"

class BookmarksApp extends TestApp
  @require_user!

  "/save": capture_errors_json =>
    BookmarksFlow(@)\save_bookmark!
    json: { success: true }

  "/remove": capture_errors_json =>
    BookmarksFlow(@)\remove_bookmark!
    json: { success: true }

describe "flows.bookmarks", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Topics, Users, Bookmarks
    current_user = factory.Users!

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

