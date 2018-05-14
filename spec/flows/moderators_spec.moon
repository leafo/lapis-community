import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import Application from require "lapis"
import capture_errors_json from require "lapis.application"
import in_request from require "spec.flow_helpers"

import TestApp from require "spec.helpers"

class ModeratorsApp extends TestApp
  @require_user!

  @before_filter =>
    ModeratorsFlow = require "community.flows.moderators"
    @flow = ModeratorsFlow @

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

  import Users from require "spec.models"

  import
    Categories
    Moderators
    from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  add_moderator = (post) ->
    in_request {
      :post
    }, =>
      @current_user = current_user
      @flow("moderators")\add_moderator!

  describe "add_moderator", ->
    it "should fail to do anything with missing params", ->
      assert.has_error(
        -> res = add_moderator!
        {
          message: {
            "object_id must be an integer"
            "object_type must be one of category, category_group"
          }
        }
      )

    it "should let category owner add moderator", ->
      category = factory.Categories user_id: current_user.id
      other_user = factory.Users!

      mod = assert add_moderator {
        object_type: "category"
        object_id: category.id
        user_id: other_user.id
      }

      mod = assert unpack Moderators\select!
      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.object_id
      assert.same Moderators.object_types.category, mod.object_type

    it "should not let category owner add self", ->
      category = factory.Categories user_id: current_user.id

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: current_user.id
          }

        {
          message: {
            "you can't chose yourself"
          }
        }
      )

    it "should not add owner", ->
      owner = factory.Users!
      category = factory.Categories user_id: owner.id

      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      other_user = factory.Users!

      assert.has_error(
        ->
        add_moderator {
          object_type: "category"
          object_id: category.id
          user_id: owner.id
        }

        {
          message: { "already moderator" }
        }
      )

    it "doesn't add existing moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.Moderators { object: category }

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: mod.user_id
          }
        {
          message: { "already moderator" }
        }
      )

    it "should let category admin add moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      other_user = factory.Users!
      mod = assert add_moderator {
        object_type: "category"
        object_id: category.id
        user_id: other_user.id
      }

      mod = assert unpack Moderators\select [[
        where user_id != ?
      ]], current_user.id

      assert.same false, mod.accepted
      assert.same false, mod.admin

      assert.same other_user.id, mod.user_id
      assert.same category.id, mod.object_id
      assert.same Moderators.object_types.category, mod.object_type

    it "should not let stranger add moderator", ->
      category = factory.Categories!
      other_user = factory.Users!

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: other_user.id
          }

        {
          message: {
            "invalid moderatable object"
          }
        }
      )

      assert.same {}, Moderators\select!

    it "should not let non-admin moderator add moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
      }

      other_user = factory.Users!

      assert.has_error(
        ->
          add_moderator {
            object_type: "category"
            object_id: category.id
            user_id: other_user.id
          }

        {
          message: { "invalid moderatable object" }
        }
      )


  describe "remove_moderator", ->
    it "should fail to do anything with missing params", ->
      res = ModeratorsApp\get current_user, "/remove-moderator", {}
      assert.truthy res.errors

    it "should not let stranger remove moderator", ->
      category = factory.Categories!
      mod = factory.Moderators object: category

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

    it "should let category owner remove moderator", ->
      category = factory.Categories user_id: current_user.id
      mod = factory.Moderators object: category

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.falsy res.errors
      assert.same {}, Moderators\select!

    it "should let category admin remove moderator", ->
      category = factory.Categories!
      factory.Moderators {
        object: category
        user_id: current_user.id
        admin: true
      }

      mod = factory.Moderators object: category
      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.falsy res.errors

    it "should let (non admin/owner) moderator remove self", ->
      mod = factory.Moderators user_id: current_user.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.falsy res.errors
      assert.same {}, Moderators\select!

    it "should not let non-admin moderator remove moderator", ->
      factory.Moderators user_id: current_user.id
      mod = factory.Moderators!

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id
        user_id: mod.user_id
      }

      assert.truthy res.errors

  describe "accept_moderator_position", ->
    it "should do nothing for stranger", ->
      mod = factory.Moderators accepted: false

      res = ModeratorsApp\get current_user, "/accept-mod", {
        object_type: "category"
        object_id: mod.object_id
      }

      assert.truthy res.errors

      mod\refresh!
      assert.same false, mod.accepted

    it "should accept moderator position", ->
      mod = factory.Moderators accepted: false, user_id: current_user.id

      res = ModeratorsApp\get current_user, "/accept-mod", {
        object_type: "category"
        object_id: mod.object_id
      }

      assert.falsy res.errors
      mod\refresh!
      assert.same true, mod.accepted

    it "should reject moderator position", ->
      mod = factory.Moderators accepted: false, user_id: current_user.id

      res = ModeratorsApp\get current_user, "/remove-moderator", {
        object_type: "category"
        object_id: mod.object_id

        user_id: mod.user_id
        current_user_id: current_user.id
      }

      assert.falsy res.errors
      assert.same {}, Moderators\select!


  describe "show moderators", ->
    it "should get moderators when there are none", ->
      category = factory.Categories!
      res = ModeratorsApp\get current_user, "/show-mods", {
        object_type: "category"
        object_id: category.id
      }

      assert.same {success: true, moderators: {}}, res

    it "should get moderators when there are some", ->
      category = factory.Categories!
      factory.Moderators! -- unrelated mod

      for i=1,2
        factory.Moderators object: category

      res = ModeratorsApp\get current_user, "/show-mods", {
        object_type: "category"
        object_id: category.id
      }

      assert.falsy res.errors
      assert.same 2, #res.moderators


