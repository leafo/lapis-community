import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

factory = require "spec.factory"

import TestApp from require "spec.helpers"
import capture_errors_json from require "lapis.application"

import Users from require "models"
import Categories, CategoryGroups, CategoryGroupCategories from require "community.models"

class CategoryGroupApp extends TestApp
  @require_user!

  @before_filter =>
    CategoryGroupsFlow = require "community.flows.category_groups"
    @flow = CategoryGroupsFlow @

  "/show-categories": capture_errors_json =>
    @flow\show_categories!
    json: {success: true, categories: @categories }

describe "category groups flow", ->
  use_test_env!

  local current_user

  before_each ->
    truncate_tables Users, Categories, CategoryGroups, CategoryGroupCategories
    current_user = factory.Users!

  it "should show categories", ->
    group = factory.CategoryGroups!
    group\add_category factory.Categories!

    res = CategoryGroupApp\get current_user, "/show-categories", {
      category_group_id: group.id
    }

    assert.falsy res.errors
    assert.same 1, #res.categories

