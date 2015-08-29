import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import Users from require "models"
import
  Categories, Posts, Topics, CategoryMembers, Moderators, ActivityLogs,
    ModerationLogs, ModerationLogObjects
  from require "community.models"

class CategoryApp extends TestApp
  @require_user!

  @before_filter =>
    CategoriesFlow = require "community.flows.categories"
    @flow = CategoriesFlow @

  "/new-category": capture_errors_json =>
    @flow\new_category!
    json: { success: true }

  "/edit-category": capture_errors_json =>
    @flow\edit_category!
    json: { success: true }

  "/add-member": capture_errors_json =>
    @flow\members_flow!\add_member!
    json: { success: true }

  "/remove-member": capture_errors_json =>
    @flow\members_flow!\remove_member!
    json: { success: true }

  "/accept-member": capture_errors_json =>
    @flow\members_flow!\accept_member!
    json: { success: true }

  "/moderation-logs": capture_errors_json =>
    @flow\moderation_logs!
    json: {
      success: true
      page: @page
      moderation_logs: @moderation_logs
    }


describe "categories", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Posts, Topics, CategoryMembers,
      Moderators, ActivityLogs, ModerationLogs, ModerationLogObjects

    current_user = factory.Users!

  it "should create category", ->
    res = CategoryApp\get current_user, "/new-category", {
      "category[title]": "hello world"
      "category[membership_type]": "public"
      "category[voting_type]": "disabled"
      "category[short_description]": "This category is about something"
      "category[hidden]": "on"
    }

    assert.falsy res.errors

    assert.truthy res.success
    category = unpack Categories\select!
    assert.truthy category

    assert.same current_user.id, category.user_id
    assert.same "hello world", category.title
    assert.same "This category is about something", category.short_description
    assert.falsy category.description

    assert.falsy category.archived
    assert.truthy category.hidden

    assert.same Categories.membership_types.public, category.membership_type
    assert.same Categories.voting_types.disabled, category.voting_type

    assert.same 1, ActivityLogs\count!
    log = unpack ActivityLogs\select!
    assert.same current_user.id, log.user_id
    assert.same category.id, log.object_id
    assert.same ActivityLogs.object_types.category, log.object_type
    assert.same "create", log\action_name!


  describe "with category", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id, description: "okay okay"

    it "should edit category", ->
      res = CategoryApp\get current_user, "/edit-category", {
        category_id: category.id
        "category[title]": "The good category"
        "category[membership_type]": "members_only"
        "category[voting_type]": "up"
        "category[short_description]": "yeah yeah"
        "category[archived]": "on"
      }

      assert.same {success: true}, res
      category\refresh!

      assert.same "The good category", category.title
      assert.same "yeah yeah", category.short_description
      assert.falsy category.description
      assert.truthy category.archived
      assert.falsy category.hidden

      assert.same Categories.membership_types.members_only, category.membership_type
      assert.same Categories.voting_types.up, category.voting_type

      assert.same 1, ActivityLogs\count!
      log = unpack ActivityLogs\select!
      assert.same current_user.id, log.user_id
      assert.same category.id, log.object_id
      assert.same ActivityLogs.object_types.category, log.object_type
      assert.same "edit", log\action_name!

    it "should not let unknown user edit category", ->
      other_user = factory.Users!
      res = CategoryApp\get other_user, "/edit-category", {
        category_id: category.id
        "category[title]": "The good category"
        "category[membership_type]": "members_only"
      }

      assert.same {errors: {"invalid category"}}, res

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

      assert.same { errors: {"no pending membership"} }, res

  describe "moderation_logs", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "gets moderation log", ->
      ModerationLogs\create {
        category_id: category.id
        object: category
        user_id: current_user.id
        action: "did.something"
      }

      res = CategoryApp\get current_user, "/moderation-logs", {
        category_id: category.id
      }

      assert.truthy res.moderation_logs
      assert.same 1, #res.moderation_logs

    it "doesn't get moderation log for unrelated user", ->
      other_user = factory.Users!
      res = CategoryApp\get other_user, "/moderation-logs", {
        category_id: category.id
      }

      assert.same {errors: {"invalid category"}}, res


