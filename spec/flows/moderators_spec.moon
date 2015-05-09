import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"

import
  Categories
  CategoryModerators
  from require "community.models"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"

writer = (fn) ->
  (...) =>
    res = { fn @, ... }
    @write unpack res if next res

import TestApp from require "spec.helpers"

class ModeratorsApp extends TestApp
  @before_filter writer capture_errors_json =>
    @current_user = Users\find assert @params.current_user_id, "missing current user id"
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow(@)\moderators_flow!

  "/add-moderator": capture_errors_json =>
    @flow\add_moderator!
    json: { success: true }

  "/remove-moderator": capture_errors_json =>
    @flow\remove_moderator!
    json: { success: true }

  "/accept-mod": capture_errors_json =>
    @flow\accept_moderator_position!
    json: { success: true }

  "/show-mods": capture_errors_json =>
    moderators = @flow\show_moderators!
    json: { success: true, :moderators }

describe "moderators flow", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, CategoryModerators, Categories

    current_user = factory.Users!
  
  describe "add_moderator", ->
    it "should fail to do anything with missing params", ->
      res = ModeratorsApp\get current_user, "/add-moderator", {}
      assert.truthy res.errors

    it "should let category owner add moderator", ->
      category = factory.Categories user_id: current_user.id
      other_user = factory.Users!

      res = ModeratorsApp\get current_user, "/add-moderator", {
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
      res = ModeratorsApp\get current_user, "/add-moderator", {
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

      res = ModeratorsApp\get current_user, "/add-moderator", {
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
      res = ModeratorsApp\get current_user, "/add-moderator", {
        category_id: category.id
        user_id: other_user.id
      }

      assert.truthy res.errors

  describe "remove_moderator", ->
    it "should fail to do anything with missing params", ->
      res = ModeratorsApp\get current_user, "/remove-moderator", {}
      assert.truthy res.errors

    it "should not let stranger remove moderator", ->
      category = factory.Categories!
      mod = factory.CategoryModerators category_id: category.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

    it "should let category owner remove moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.CategoryModerators category_id: category.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
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
      res = ModeratorsApp\get current_user, "/remove-moderator", {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.success

    it "should let (non admin/owner) moderator remove self", ->
      mod = factory.CategoryModerators user_id: current_user.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.success
      assert.same {}, CategoryModerators\select!

    it "should not let non-admin moderator remove moderator", ->
      factory.CategoryModerators user_id: current_user.id
      mod = factory.CategoryModerators!

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        category_id: mod.category_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

  describe "accept_moderator_position", ->
    it "should do nothing for stranger", ->
      mod = factory.CategoryModerators accepted: false

      res = ModeratorsApp\get current_user, "/accept-mod", {
        category_id: mod.category_id
      }

      assert.truthy res.errors

      mod\refresh!
      assert.same false, mod.accepted

    it "should accept moderator position", ->
      mod = factory.CategoryModerators accepted: false, user_id: current_user.id
      res = ModeratorsApp\get current_user, "/accept-mod", {
        category_id: mod.category_id
      }

      assert.truthy res.success
      mod\refresh!
      assert.same true, mod.accepted

    it "should reject moderator position", ->
      mod = factory.CategoryModerators accepted: false, user_id: current_user.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        category_id: mod.category_id
        user_id: mod.user_id
        current_user_id: current_user.id
      }

      assert.truthy res.success
      assert.same {}, CategoryModerators\select!

  -- TODO: this is model spec not flow spec
  describe "moderator permissions", ->
    local mod
    import
      Posts
      Topics
      from require "community.models"

    before_each ->
      truncate_tables Posts, Topics
      mod = factory.CategoryModerators user_id: current_user.id

    it "should let moderator edit post in category", ->
      topic = factory.Topics category_id: mod.category_id
      post = factory.Posts topic_id: topic.id

      assert.truthy post\allowed_to_edit current_user

    it "should not let moderator edit post other category", ->
      post = factory.Posts!
      assert.falsy post\allowed_to_edit current_user


  describe "show moderators", ->
    it "should get moderators when there are none", ->
      category = factory.Categories!
      res = ModeratorsApp\get current_user, "/show-mods", {
        category_id: category.id
      }

      assert.same {success: true, moderators: {}}, res

    it "should get moderators when there are some", ->
      category = factory.Categories!
      factory.CategoryModerators! -- unrelated mod

      for i=1,2
        factory.CategoryModerators category_id: category.id

      res = ModeratorsApp\get current_user, "/show-mods", {
        category_id: category.id
      }

      assert.truthy res.success
      assert.same 2, #res.moderators

