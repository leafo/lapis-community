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

  "/new-category": capture_errors_json =>
    @flow\new_category!
    json: { success: true }

  "/edit-category": capture_errors_json =>
    @flow\edit_category!
    json: { success: true }

  "/add-member": capture_errors_json =>
    @flow\add_member!
    json: { success: true }

  "/remove-member": capture_errors_json =>
    @flow\remove_member!
    json: { success: true }

  "/accept-member": capture_errors_json =>
    @flow\accept_member!
    json: { success: true }

describe "categories", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Posts, Topics, CategoryMembers, CategoryModerators
    current_user = factory.Users!

  it "should create category", ->
    res = CategoryApp\get current_user, "/new-category", {
      "category[name]": "hello world"
      "category[membership_type]": "public"
    }

    assert.truthy res.success
    category = unpack Categories\select!
    assert.truthy category

    assert.same current_user.id, category.user_id
    assert.same "hello world", category.name
    assert.same Categories.membership_types.public, category.membership_type


  describe "with category", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "should edit category", ->
      res = CategoryApp\get current_user, "/edit-category", {
        category_id: category.id
        "category[name]": "The good category"
        "category[membership_type]": "members_only"
      }

      assert.same {success: true}, res
      category\refresh!
      assert.same "The good category", category.name
      assert.same Categories.membership_types.members_only, category.membership_type

  describe "add_member", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

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

