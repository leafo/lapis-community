import load_test_server, close_test_server, request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

import
  Categories
  CategoryModerators
  Users
  from require "models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

class ModeratorsApp extends Application
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    ModeratorsFlow = require "community.flows.moderators"
    @flow = ModeratorsFlow @

  "/add-moderator": capture_errors_json =>
    @flow\add_moderator!
    json: { success: true }

  "/remove-moderator": capture_errors_json =>
    @flow\remove_moderator!
    json: { success: true }

describe "moderators flow", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  local current_user

  before_each ->
    truncate_tables Users, CategoryModerators, Categories

    current_user = factory.Users!
  
  describe "add_moderator", ->
    add_moderator = (get) ->
      get.current_user_id or= current_user.id
      status, res = mock_request ModeratorsApp, "/add-moderator", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should fail to do anything with missing params", ->
      res = add_moderator { }
      assert.truthy res.errors

  describe "remove_moderator", ->
    remove_moderator = (get) ->
      get.current_user_id or= current_user.id
      status, res = mock_request ModeratorsApp, "/remove-moderator", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should fail to do anything with missing params", ->
      res = remove_moderator { }
      assert.truthy res.errors





