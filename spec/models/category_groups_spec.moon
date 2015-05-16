import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

import Users from require "models"
import Categories, CategoryGroups, CategoryGroupCategories from require "community.models"

factory = require "spec.factory"

describe "categories", ->
  use_test_env!

  before_each ->
    truncate_tables Categories, CategoryGroups, CategoryGroupCategories

  it "should create category group", ->
    group = factory.CategoryGroups!
    group\refresh!
    assert.same 0, group.categories_count

  describe "with group", ->
    local group

    before_each ->
      group = factory.CategoryGroups!

    it "should add a category to a group", ->
      category = factory.Categories!
      group\add_category category

      assert.same 1, group.categories_count

      gs = group\get_category_group_categories_paginated!\get_page!

      assert.same 1, #gs
      g = unpack gs

      assert.same category.id, g.category_id
      assert.same group.id, g.category_group_id

      group\add_category category
      group\refresh!
      assert.same 1, group.categories_count

    it "should remove a category from group", ->
      category = factory.Categories!
      group\add_category category

      assert.same 1, group.categories_count
      group\remove_category category

      group\refresh!
      assert.same 0, group.categories_count

      gs = group\get_category_group_categories_paginated!\get_page!
      assert.same {}, gs

      group\remove_category category

