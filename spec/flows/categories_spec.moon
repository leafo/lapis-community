import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import Users, Categories, Posts, Topics, CategoryMembers, CategoryModerators from require "models"

class CategoryApp extends TestApp
  @before_filter =>
    @current_user = Users\find assert @params.current_user_id, "missing user id"
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @

  "/add-member": capture_errors_json =>
    @flow\add_member!
    json: { success: true }

  "/remove-member": capture_errors_json =>
    @flow\remove_member!
    json: { success: true }

  "/accept-member": capture_errors_json =>
    @flow\accept_member!
    json: { success: true }

describe "category_membership", ->
  use_test_env!

  local current_user
  local category

  before_each ->
    truncate_tables Users, Categories, Posts, Topics, CategoryMembers, CategoryModerators
    current_user = factory.Users!
    category = factory.Categories user_id: current_user.id

  describe "add_member", ->
    it "should add member", ->
      other_user = factory.Users!

      res = CategoryApp\get current_user, "/add-member", {
        category_id: category.id
        user_id: other_user.id
      }

      members = CategoryMembers\select!
      assert.same 1, #members

      member = unpack members
      assert.same category.id, member.category_id
      assert.same other_user.id, member.user_id
      assert.same false, member.accepted

      assert.same { success: true }, res

    it "should accept member", ->
      other_user = factory.Users!

      factory.CategoryMembers {
        user_id: other_user.id
        category_id: category.id
        accepted: false
      }

      res = CategoryApp\get other_user, "/accept-member", {
        category_id: category.id
      }

      assert.same { success: true }, res

    it "should not accept unininvited user", ->
      other_user = factory.Users!
      res = CategoryApp\get other_user, "/accept-member", {
        category_id: category.id
      }

      assert.same { errors: {"invalid membership"} }, res

