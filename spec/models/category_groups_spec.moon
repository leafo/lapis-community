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

    it "adds a category to a group", ->
      category = factory.Categories!
      group\add_category category

      assert.same 1, group.categories_count
      category\refresh!
      assert.same 1, category.category_groups_count

      gs = group\get_category_group_categories_paginated!\get_page!

      assert.same 1, #gs
      g = unpack gs

      assert.same category.id, g.category_id
      assert.same group.id, g.category_group_id

      group\add_category category
      group\refresh!
      assert.same 1, group.categories_count

      category\refresh!
      assert.same 1, category.category_groups_count

      c_group = category\get_category_group!
      assert.same group.id, c_group.id

    it "removes a category from group", ->
      category = factory.Categories!
      group\add_category category

      assert.same 1, group.categories_count
      group\remove_category category

      group\refresh!
      assert.same 0, group.categories_count

      category\refresh!
      assert.same 0, category.category_groups_count

      gs = group\get_category_group_categories_paginated!\get_page!
      assert.same {}, gs

      group\remove_category category

    it "sets categories", ->
      category1 = factory.Categories!
      category2 = factory.Categories!

      group\add_category category1

      group\set_categories { category2 }

      cats = {cgc.category_id, true for cgc in *CategoryGroupCategories\select!}

      assert.same {
        [category2.id]: true
      }, cats


    it "gets categories", ->
      category1 = factory.Categories!
      category2 = factory.Categories!
      category3 = factory.Categories!

      group\add_category category1
      group\add_category category2

      categories = group\get_categories_paginated!\get_all!
      category_ids = {c.id, true for c in *categories}
      assert.same {
        [category1.id]: true
        [category2.id]: true
      }, category_ids


