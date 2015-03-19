import
  load_test_server
  close_test_server
  request
  from require "lapis.spec.server"

import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import mock_request from require "lapis.spec.request"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import Users, Categories, Posts, Topics, CategoryMembers, CategoryModerators from require "models"

class PostingApp extends TestApp
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

  "/approve-member": capture_errors_json =>
    @flow\approve_member!
    json: { success: true }

describe "category_membership", ->
  local current_user
  local category

  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->
    truncate_tables Users, Categories, Posts, Topics, CategoryMembers, CategoryModerators
    current_user = factory.Users!
    category = factory.Categories user_id: current_user.id

  describe "add_member", ->
    it "should add member", ->
      other_user = factory.Users!

      res = PostingApp\get current_user, "/add-member", {
        category_id: category.id
        user_id: other_user.id
      }

      members = CategoryMembers\select!
      assert.same 1, #members

      member = unpack members
      assert.same category.id, member.category_id
      assert.same other_user.id, member.user_id
      assert.same false, member.approved

      assert.same { success: true }, res

