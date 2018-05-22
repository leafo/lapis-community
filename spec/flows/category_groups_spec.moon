import use_test_env from require "lapis.spec"
import in_request from require "spec.flow_helpers"

factory = require "spec.factory"

describe "category groups flow", ->
  use_test_env!

  local current_user

  import Users from require "spec.models"
  import Categories, CategoryGroups,
    CategoryGroupCategories from require "spec.community_models"

  before_each ->
    current_user = factory.Users!

  show_categories = (get) ->
    in_request { :get }, =>
      @current_user = current_user
      @flow("category_groups")\show_categories!

  new_category_group = (post) ->
    in_request { :post }, =>
      @current_user = current_user
      @flow("category_groups")\new_category_group!

  edit_category_group = (post) ->
    in_request { :post }, =>
      @current_user = current_user
      @flow("category_groups")\edit_category_group!

  it "shows categories", ->
    group = factory.CategoryGroups!
    group\add_category factory.Categories!

    categories = show_categories {
      category_group_id: group.id
    }

    assert.same 1, #categories

  it "creates new category group", ->
    new_category_group {
      "category_group[title]": ""
    }

    assert.same 1, #CategoryGroups\select!

  it "edits category group", ->
    group = factory.CategoryGroups {
      user_id: current_user.id
      description: "yeah"
    }

    edit_category_group {
      category_group_id: group.id
      "category_group[rules]": "follow the rules!"
    }

    assert.same 1, #CategoryGroups\select!

    group\refresh!

    assert.same "follow the rules!", group.rules
    assert.falsy group.description

