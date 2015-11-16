import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import Users from require "models"
import
  Categories, Posts, Topics, CategoryMembers, Moderators, ActivityLogs,
    ModerationLogs, ModerationLogObjects, PendingPosts from require "community.models"

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

  "/pending-posts": capture_errors_json =>
    @flow\pending_posts!
    json: {
      success: true
      page: @page
      pending_posts: @pending_posts
    }

  "/pending-post": capture_errors_json =>
    status, post = @flow\edit_pending_post!
    json: {
      :status
      :post
    }

  "/set-children": capture_errors_json =>
    @flow\set_children!
    json: { "ok" }

describe "categories", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, Posts, Topics, CategoryMembers,
      Moderators, ActivityLogs, ModerationLogs, ModerationLogObjects,
      PendingPosts

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

    describe "edit", ->
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
        assert.same "okay okay", category.description
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

      it "should update partial", ->
        category\update archived: true
        res = CategoryApp\get current_user, "/edit-category", {
          category_id: category.id
          "category[update_archived]": "yes"
        }

        assert.same {success: true}, res
        category\refresh!
        assert.false category.hidden

      it "should noop edit", ->
        res = CategoryApp\get current_user, "/edit-category", {
          category_id: category.id
        }

        assert.same {success: true}, res
        assert.same 0, ActivityLogs\count!

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

  describe "pending posts", ->
    local category

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "gets empty pending posts", ->
      res = CategoryApp\get current_user, "/pending-posts", {
        category_id: category.id
      }

      assert.same {}, res.pending_posts

    describe "with pending posts", ->
      local pending_post

      before_each ->
        pending_post = factory.PendingPosts category_id: category.id

      it "gets pending posts", ->
        res = CategoryApp\get current_user, "/pending-posts", {
          category_id: category.id
        }
        assert.same 1, #res.pending_posts
        assert.same pending_post.id, res.pending_posts[1].id

      it "doesn't let stranger view pending posts", ->
        res = CategoryApp\get factory.Users!, "/pending-posts", {
          category_id: category.id
        }
        assert.truthy res.errors

      it "doesn't get incorrect satus", ->
        res = CategoryApp\get current_user, "/pending-posts", {
          category_id: category.id
          status: "deleted"
        }
        assert.same {}, res.pending_posts

      it "promotes pending post", ->
        res = CategoryApp\get current_user, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "promote"
        }

        assert.same 0, PendingPosts\count!
        assert.same 1, Posts\count!

      it "doesn't let stranger edit pending post", ->
        res = CategoryApp\get factory.Users!, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "promote"
        }

        assert.truthy res.errors

      it "deletes pending post", ->
        res = CategoryApp\get current_user, "/pending-post", {
          category_id: category.id
          pending_post_id: pending_post.id
          action: "deleted"
        }

        assert.same 1, PendingPosts\count!
        assert.same 0, Posts\count!

        pending_post\refresh!
        assert.same PendingPosts.statuses.deleted, pending_post.status

  describe "set children", =>
    local category

    simplify_children = (children) ->
      return for c in *children
        {
          title: c.title
          children: c.children and next(c.children) and simplify_children(c.children) or nil
        }

    assert_children = (tree, category) ->
      category = Categories\find category.id
      category\get_children!
      -- require("moon").p tree
      -- require("moon").p simplify_children category.children
      assert.same tree, simplify_children category.children

    before_each ->
      category = factory.Categories user_id: current_user.id

    it "should set empty cateogires", ->
      CategoryApp\get current_user, "/set-children", {
        category_id: category.id
      }

    it "creates new categories", ->
      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id
        "categories[1][title]": "alpha"
        "categories[2][title]": "beta"
      }

      assert.nil res.errors
      assert_children {
        {title: "alpha"}
        {title: "beta"}
      }, category

    it "creates new categories with nesting #ddd", ->
      res = CategoryApp\get current_user, "/set-children", {
        category_id: category.id

        "categories[1][title]": "alpha"
        "categories[1][children][1][title]": "alpha one"
        "categories[1][children][2][title]": "alpha two"
        "categories[2][title]": "beta"
        "categories[3][title]": "cow"
        "categories[3][children][1][title]": "cow moo"
      }

      assert.nil res.errors
      assert_children {
        {
          title: "alpha"
          children: {
            {title: "alpha one"}
            {title: "alpha two"}
          }
        }
        {title: "beta"}
        {
          title: "cow"
          children: {
            {title: "cow moo"}
          }
        }
      }, category
