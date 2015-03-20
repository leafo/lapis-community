import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"
import Users, Bans, Categories from require "models"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

factory = require "spec.factory"

class BansApp extends TestApp
  @require_user!

  @before_filter =>
    BansFlow = require "community.flows.bans"
    @flow = BansFlow @

  "/category-ban": capture_errors_json =>
    @flow\ban_from_category!
    json: { success: true }

  "/category-unban": capture_errors_json =>
    @flow\unban_from_category!
    json: { success: true }

describe "topic tags", ->
  use_test_env!

  local current_user

  before_each =>
    truncate_tables Users, Bans, Categories
    current_user = factory.Users!

  describe "with category", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "should ban user from category", ->
      other_user = factory.Users!
      res = BansApp\get current_user, "/category-ban", {
        category_id: category.id
        banned_user_id: other_user.id
        reason: [[this user]]
      }

      assert.truthy res.success
      bans = Bans\select!
      assert.same 1, #bans

    it "should not let unrelated user ban", ->
      other_user = factory.Users!
      res = BansApp\get other_user, "/category-ban", {
        category_id: category.id
        banned_user_id: current_user.id
        reason: [[this user]]
      }

      assert.same {errors: {"invalid permissions"}}, res


