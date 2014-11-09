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
    @current_user = Users\find assert @params.current_user_id, "missing current user id"
    ModeratorsFlow = require "community.flows.moderators"
    @flow = ModeratorsFlow @

  "/add-moderator": capture_errors_json =>
    @flow\add_moderator!
    json: { success: true }

  "/remove-moderator": capture_errors_json =>
    @flow\remove_moderator!
    json: { success: true }

  "/accept-mod": capture_errors_json =>
    @flow\accept_moderator_position!
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

    it "should let category owner add moderator", ->
      category = factory.Categories user_id: current_user.id
      other_user = factory.Users!

      res = add_moderator {
        category_id: category.id
        user_id: other_user.id
      }

      assert.truthy res.success
      mod = assert unpack CategoryModerators\select!
      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.category_id

    it "should let category admin add moderator", ->
      category = factory.Categories!
      factory.CategoryModerators {
        category_id: category.id
        user_id: current_user.id
        admin: true
      }

      other_user = factory.Users!
      res = add_moderator {
        category_id: category.id
        user_id: other_user.id
      }

      assert.truthy res.success
      mod = assert unpack CategoryModerators\select [[
        where user_id != ?
      ]], current_user.id

      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.category_id

    it "should not let stranger add moderator", ->
      category = factory.Categories!
      other_user = factory.Users!

      res = add_moderator {
        category_id: category.id
        user_id: other_user.id
      }

      assert.truthy res.errors
      assert.same {}, CategoryModerators\select!

    it "should not let non-admin moderator add moderator", ->
      category = factory.Categories!
      factory.CategoryModerators {
        category_id: category.id
        user_id: current_user.id
      }

      other_user = factory.Users!
      res = add_moderator {
        category_id: category.id
        user_id: other_user.id
      }

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

    it "should not let stranger remove moderator", ->
      category = factory.Categories!
      mod = factory.CategoryModerators category_id: category.id

      res = remove_moderator {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

    it "should let category owner remove moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.CategoryModerators category_id: category.id

      res = remove_moderator {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.success
      assert.same {}, CategoryModerators\select!

    it "should let category admin remove moderator", ->
      category = factory.Categories!
      factory.CategoryModerators {
        category_id: category.id
        user_id: current_user.id
        admin: true
      }

      mod = factory.CategoryModerators category_id: category.id
      res = remove_moderator {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.success

    it "should let (non admin/owner) moderator remove self", ->
      mod = factory.CategoryModerators user_id: current_user.id

      res = remove_moderator {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.success
      assert.same {}, CategoryModerators\select!

    it "should not let non-admin moderator remove moderator", ->
      factory.CategoryModerators user_id: current_user.id
      mod = factory.CategoryModerators!

      res = remove_moderator {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

  describe "accept_moderator_position", ->
    accept_moderator = (get) ->
      get.current_user_id or= current_user.id
      status, res = mock_request ModeratorsApp, "/accept-mod", {
        :get
        expect: "json"
      }

      assert.same 200, status
      res

    it "should do nothing for stranger", ->
      mod = factory.CategoryModerators accepted: false
      res = accept_moderator category_id: mod.category_id
      assert.truthy res.errors

      mod\refresh!
      assert.same false, mod.accepted

    it "should accept moderator position", ->
      mod = factory.CategoryModerators accepted: false, user_id: current_user.id
      res = accept_moderator category_id: mod.category_id
      assert.truthy res.success
      mod\refresh!
      assert.same true, mod.accepted

    it "should reject moderator position", ->
      mod = factory.CategoryModerators accepted: false, user_id: current_user.id

      status, res = mock_request ModeratorsApp, "/remove-moderator", {
        get: {
          category_id: mod.category_id
          user_id: mod.user_id
          current_user_id: current_user.id
        }
        expect: "json"
      }

      assert.same 200, status
      assert.same {}, CategoryModerators\select!


