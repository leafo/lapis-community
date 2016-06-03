import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

class CategoryGroupApp extends TestApp
  @require_user!

  @before_filter =>
    CategoryGroupsFlow = require "community.flows.category_groups"
    @flow = CategoryGroupsFlow @

  "/show-categories": capture_errors_json =>
    @flow\show_categories!
    json: {success: true, categories: @categories }

  "/new": capture_errors_json =>
    @flow\new_category_group!
    json: {success: true, categories: @categories }

  "/edit": capture_errors_json =>
    @flow\edit_category_group!
    json: {success: true, categories: @categories }

describe "category groups flow", ->
  use_test_env!

  local current_user

  import Users from require "spec.models"
  import Categories, CategoryGroups,
    CategoryGroupCategories from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  it "should show categories", ->
    group = factory.CategoryGroups!
    group\add_category factory.Categories!

    res = CategoryGroupApp\get current_user, "/show-categories", {
      category_group_id: group.id
    }

    assert.falsy res.errors
    assert.same 1, #res.categories


  it "should create new category group", ->
    res = CategoryGroupApp\get current_user, "/new", {
      "category_group[title]": ""
    }

    assert.falsy res.errors
    assert.same 1, #CategoryGroups\select!

  it "should edit category group", ->
    group = factory.CategoryGroups {
      user_id: current_user.id
      description: "yeah"
    }

    res = CategoryGroupApp\get current_user, "/edit", {
      category_group_id: group.id
      "category_group[rules]": "follow the rules!"
    }

    assert.falsy res.errors
    assert.same 1, #CategoryGroups\select!

    group\refresh!

    assert.same "follow the rules!", group.rules
    assert.falsy group.description

